#!/usr/bin/env python3
"""
quiz_scraper.py — Auto-fetches MCQ questions from free sources and
pushes them to the JobMitra questions DB via the /admin/questions API.

Sources:
  1. GKToday  — daily current-affairs quiz (RSS → HTML parse)
  2. AffairsCloud — daily quiz (RSS → HTML parse)
  3. Open Trivia DB — GK / History / Geography / Politics (free JSON API)
  4. backend/pyq_data/*.json — local PYQ / practice-pack JSON files

Run standalone:  python backend/quiz_scraper.py
Called by:       POST /admin/scrape-quiz  (in main.py)
"""

import feedparser
import requests
from bs4 import BeautifulSoup
import re
import json
import time
import os
import random
import glob
import hashlib

# ── Config ──────────────────────────────────────────────────────────────────
API_BASE = os.getenv("API_BASE", "https://jobmitra-api.onrender.com")
SECRET   = os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024")
HEADERS  = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36"
}
QS_PER_SET = 5   # questions per daily-quiz set

# ── Helpers ──────────────────────────────────────────────────────────────────

def _clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"&nbsp;", " ", text)
    text = re.sub(r"&amp;", "&", text)
    text = re.sub(r"&lt;", "<", text)
    text = re.sub(r"&gt;", ">", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _hash(text: str) -> str:
    return hashlib.md5(text.lower().strip().encode()).hexdigest()


def _push(questions: list, next_set_index: int = 0) -> int:
    """POST a batch of questions to the API. Returns inserted count."""
    if not questions:
        return 0
    try:
        r = requests.post(
            f"{API_BASE}/admin/questions",
            params={"secret": SECRET},
            json={"questions": questions, "next_set_index": next_set_index},
            timeout=90,
        )
        if r.status_code == 200:
            data = r.json()
            n = data.get("inserted", 0)
            print(f"  ✓ pushed {len(questions)}, inserted {n}")
            return n
        print(f"  ✗ push failed {r.status_code}: {r.text[:120]}")
    except Exception as e:
        print(f"  ✗ push error: {e}")
    return 0


def _get_next_set_index() -> int:
    """Ask the API what the current max set_index is, return max+1."""
    try:
        r = requests.get(
            f"{API_BASE}/admin/quiz-stats",
            params={"secret": SECRET},
            timeout=20,
        )
        if r.status_code == 200:
            m = r.json().get("max_set_index", -1)
            return (m or -1) + 1
    except Exception:
        pass
    return 0


# ── Parse helpers ────────────────────────────────────────────────────────────

def _parse_text_quiz(text: str, topic: str) -> list:
    """
    Parse numbered MCQ blocks from raw article text.
    Handles formats:
      1. Question?\n[A] opt\n[B] opt\n[C] opt\n[D] opt\nAnswer: A
      Q1. Question?\n(A) opt ...
    """
    questions = []
    # Split on "1." / "Q1." / "Q.1 " style numbering at start of a line
    blocks = re.split(r"(?:^|\n)\s*(?:Q\.?\s*)?\d+[\.\)]\s+", text)

    for block in blocks[1:]:
        lines = [l.strip() for l in block.split("\n") if l.strip()]
        if len(lines) < 5:
            continue

        q_lines, opts, ans_line = [], [], None
        for line in lines:
            if re.match(r"^[\(\[{]?[A-Da-d][\)\]}.]\s+\S", line):
                opts.append(re.sub(r"^[\(\[{]?[A-Da-d][\)\]}.]\s+", "", line).strip())
            elif re.search(r"\b(?:answer|ans|correct)\s*[:=]\s*[\(\[]?[A-Da-d]", line, re.I):
                ans_line = line
            elif not opts:
                q_lines.append(line)

        if len(opts) < 4 or not q_lines:
            continue

        q_text = _clean(" ".join(q_lines))
        if len(q_text) < 12:
            continue

        correct = 0
        if ans_line:
            m = re.search(r"[\(\[]?([A-Da-d])[\)\]]?", ans_line, re.I)
            if m:
                correct = max(0, min(3, ord(m.group(1).upper()) - ord("A")))

        questions.append({
            "type":     "quiz",
            "question": q_text,
            "option_a": _clean(opts[0]),
            "option_b": _clean(opts[1]),
            "option_c": _clean(opts[2]),
            "option_d": _clean(opts[3]),
            "correct":  correct,
            "topic":    topic,
        })
    return questions


# ── Source 1: GKToday ────────────────────────────────────────────────────────

GKTODAY_FEEDS = [
    "https://www.gktoday.in/gk-current-affairs-quiz/feed/",
    "https://www.gktoday.in/category/general-knowledge/feed/",
]


def _parse_gktoday_page(url: str, topic: str) -> list:
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        soup = BeautifulSoup(resp.text, "html.parser")
        content = (soup.find("div", class_="entry-content")
                   or soup.find("article"))
        if not content:
            return []
        return _parse_text_quiz(content.get_text(separator="\n"), topic)
    except Exception as e:
        print(f"    GKToday page error: {e}")
        return []


def scrape_gktoday(max_per_feed: int = 3) -> list:
    all_qs = []
    for feed_url in GKTODAY_FEEDS:
        try:
            feed = feedparser.parse(feed_url)
            print(f"  GKToday: {len(feed.entries)} entries in {feed_url}")
            for entry in feed.entries[:max_per_feed]:
                topic = entry.get("title", "GK Quiz")[:60]
                qs = _parse_gktoday_page(entry.link, topic)
                print(f"    '{topic[:40]}': {len(qs)} Qs")
                all_qs.extend(qs)
                time.sleep(1.5)
        except Exception as e:
            print(f"  GKToday feed error: {e}")
    return all_qs


# ── Source 2: AffairsCloud ───────────────────────────────────────────────────

AC_FEED = "https://affairscloud.com/category/current-affairs-quiz/feed/"


def scrape_affairscloud(max_articles: int = 3) -> list:
    all_qs = []
    try:
        feed = feedparser.parse(AC_FEED)
        print(f"  AffairsCloud: {len(feed.entries)} entries")
        for entry in feed.entries[:max_articles]:
            topic = entry.get("title", "Daily Quiz")[:60]
            try:
                resp = requests.get(entry.link, headers=HEADERS, timeout=15)
                soup = BeautifulSoup(resp.text, "html.parser")
                content = (soup.find("div", class_="entry-content")
                           or soup.find("article"))
                if content:
                    qs = _parse_text_quiz(content.get_text(separator="\n"), topic)
                    print(f"    '{topic[:40]}': {len(qs)} Qs")
                    all_qs.extend(qs)
                time.sleep(1.5)
            except Exception as e:
                print(f"    AC article error: {e}")
    except Exception as e:
        print(f"  AffairsCloud feed error: {e}")
    return all_qs


# ── Source 3: Open Trivia DB ─────────────────────────────────────────────────

OT_CATEGORIES = [
    (9,  "General Knowledge"),
    (22, "Geography"),
    (23, "History"),
    (24, "Politics"),
]


def scrape_opentrivia(amount: int = 50) -> list:
    from urllib.parse import unquote
    all_qs = []
    for cat_id, cat_name in OT_CATEGORIES:
        try:
            r = requests.get(
                "https://opentdb.com/api.php",
                params={"amount": amount, "category": cat_id,
                        "type": "multiple", "encode": "url3986"},
                timeout=20,
            )
            data = r.json()
            if data.get("response_code") != 0:
                print(f"  OpenTrivia {cat_name}: code={data.get('response_code')}")
                time.sleep(6)   # rate-limit backoff
                continue

            for item in data.get("results", []):
                q      = unquote(item["question"])
                correct = unquote(item["correct_answer"])
                wrong  = [unquote(w) for w in item["incorrect_answers"]]

                # Ensure exactly 4 options, shuffled
                opts = (wrong[:3] + [correct])
                while len(opts) < 4:
                    opts.append("None of these")
                random.shuffle(opts)
                cidx = opts.index(correct)

                all_qs.append({
                    "type":     "quiz",
                    "question": q,
                    "option_a": opts[0],
                    "option_b": opts[1],
                    "option_c": opts[2],
                    "option_d": opts[3],
                    "correct":  cidx,
                    "topic":    cat_name,
                })
            print(f"  OpenTrivia {cat_name}: {len(data.get('results', []))} Qs")
            time.sleep(6)   # opentdb rate-limit: 1 req/5s
        except Exception as e:
            print(f"  OpenTrivia error ({cat_name}): {e}")
    return all_qs


# ── Source 4: Local PYQ / Practice JSON files ────────────────────────────────

def _pyq_dir() -> str:
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "pyq_data")


def _upsert_pack(pack: dict):
    try:
        requests.post(
            f"{API_BASE}/admin/mock-pack",
            params={"secret": SECRET},
            json=pack,
            timeout=30,
        )
    except Exception as e:
        print(f"    Pack upsert error: {e}")


def load_pyq_files() -> list:
    """Load all *.json files from backend/pyq_data/ and format as mock questions."""
    all_qs = []
    d = _pyq_dir()
    if not os.path.isdir(d):
        print(f"  pyq_data dir not found: {d}")
        return []

    for fpath in sorted(glob.glob(os.path.join(d, "*.json"))):
        try:
            with open(fpath, encoding="utf-8") as f:
                data = json.load(f)

            pack_id = data.get("pack_id", os.path.splitext(os.path.basename(fpath))[0])
            qs_raw  = data.get("questions", [])

            _upsert_pack({
                "pack_id":    pack_id,
                "title":      data.get("title", pack_id),
                "subtitle":   data.get("subtitle", ""),
                "emoji":      data.get("emoji", "📋"),
                "color_hex":  data.get("color_hex", "#1565C0"),
                "is_pyq":     data.get("is_pyq", True),
                "sort_order": data.get("sort_order", 0),
            })

            for i, q in enumerate(qs_raw):
                opts = q.get("options", [])
                while len(opts) < 4:
                    opts.append("N/A")
                all_qs.append({
                    "type":        "mock",
                    "pack_id":     pack_id,
                    "question":    q.get("question", ""),
                    "option_a":    opts[0],
                    "option_b":    opts[1],
                    "option_c":    opts[2],
                    "option_d":    opts[3],
                    "correct":     q.get("correct", 0),
                    "topic":       q.get("topic", ""),
                    "explanation": q.get("explanation", ""),
                    "sort_order":  i,
                })
            print(f"  PYQ '{data.get('title', pack_id)}': {len(qs_raw)} Qs from {os.path.basename(fpath)}")
        except Exception as e:
            print(f"  PYQ load error ({fpath}): {e}")
    return all_qs


# ── Main ─────────────────────────────────────────────────────────────────────

def run_quiz_scraper() -> dict:
    print("\n=== Quiz Scraper Start ===")

    # Know where to continue set numbering from
    next_set = _get_next_set_index()
    print(f"  Starting at set_index={next_set}")

    total_inserted = 0

    # 1. GKToday
    print("\n[1] GKToday")
    gk_qs = scrape_gktoday(max_per_feed=3)
    print(f"  → {len(gk_qs)} scraped")

    # 2. AffairsCloud
    print("\n[2] AffairsCloud")
    ac_qs = scrape_affairscloud(max_articles=3)
    print(f"  → {len(ac_qs)} scraped")

    # 3. OpenTrivia
    print("\n[3] Open Trivia DB")
    ot_qs = scrape_opentrivia(amount=50)
    print(f"  → {len(ot_qs)} fetched")

    # Push all quiz questions in one batch (backend assigns set_index)
    quiz_qs = gk_qs + ac_qs + ot_qs
    if quiz_qs:
        print(f"\n  Pushing {len(quiz_qs)} quiz Qs (next_set_index={next_set})")
        n = _push(quiz_qs, next_set_index=next_set)
        total_inserted += n

    # 4. PYQ files (mock type, separate push)
    print("\n[4] PYQ / Practice packs")
    pyq_qs = load_pyq_files()
    print(f"  → {len(pyq_qs)} loaded")
    if pyq_qs:
        for i in range(0, len(pyq_qs), 100):
            total_inserted += _push(pyq_qs[i:i + 100])

    print(f"\n=== Done: {total_inserted} new questions inserted ===\n")
    return {
        "quiz_scraped":  len(quiz_qs),
        "pyq_loaded":    len(pyq_qs),
        "total_inserted": total_inserted,
    }


if __name__ == "__main__":
    run_quiz_scraper()
