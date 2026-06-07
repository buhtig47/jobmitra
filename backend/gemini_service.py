"""
gemini_service.py — Gemini AI integration for JobMitra.

Uses direct REST API calls (not the google-generativeai SDK) to avoid
Application Default Credentials conflicts on Cloud Run — the SDK tries
to authenticate via the metadata server, which fails unless the service
account has explicit Gemini permissions. REST with an explicit API key
in the query param works reliably from any environment.
"""

import json
import logging
import os
import re
import requests

log = logging.getLogger("jobmitra")

_GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
_MODEL_FLASH = "gemini-2.5-flash"


def _api_key() -> str | None:
    key = (os.getenv("GEMINI_API_KEY") or "").strip()
    if not key:
        log.error("GEMINI_API_KEY not set — AI features disabled")
        return None
    return key


def _generate(model: str, prompt: str, max_tokens: int = 2048,
              temperature: float = 0.7, timeout: int = 60) -> str | None:
    """Call Gemini REST API. Returns raw text or None on failure."""
    key = _api_key()
    if not key:
        return None
    url = f"{_GEMINI_BASE}/{model}:generateContent?key={key}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_tokens,
        },
        # Disable internal reasoning — not needed for structured JSON output,
        # and it consumes token budget that would otherwise go to the response.
        "thinkingConfig": {"thinkingBudget": 0},
    }
    try:
        resp = requests.post(url, json=payload, timeout=timeout)
        resp.raise_for_status()
        data = resp.json()
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except requests.exceptions.Timeout:
        log.error("Gemini request timed out after %ds (model=%s)", timeout, model)
        return None
    except Exception:
        log.exception("Gemini REST call failed (model=%s)", model)
        return None


def _parse_json(raw: str) -> dict | list | None:
    """Strip markdown code fences and extract the outermost JSON object/array."""
    if raw is None:
        return None
    raw = raw.strip()
    # Strip markdown code fences
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    raw = raw.strip()
    # Try direct parse first
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        pass
    # Extract outermost { ... } or [ ... ] block (handles extra preamble/suffix)
    for start_ch, end_ch in [('{', '}'), ('[', ']')]:
        start = raw.find(start_ch)
        end   = raw.rfind(end_ch)
        if start != -1 and end > start:
            try:
                return json.loads(raw[start:end + 1])
            except (ValueError, TypeError):
                pass
    log.error("Gemini returned invalid JSON: %s", raw[:300])
    return None


# ── Quiz generation ──────────────────────────────────────────────────────────

_EXAM_TOPICS = {
    "SSC CGL":   "Quantitative Aptitude, English Language, General Intelligence, General Awareness",
    "SSC CHSL":  "Quantitative Aptitude, English Language, General Intelligence, General Awareness",
    "SSC MTS":   "General Intelligence, English Language, Numerical Aptitude, General Awareness",
    "UPSC CSE":  "Indian Polity, History, Geography, Economy, Science & Technology, Environment, Current Affairs",
    "RRB NTPC":  "Mathematics, General Intelligence, General Awareness, English",
    "IBPS PO":   "Quantitative Aptitude, English, Reasoning, Computer Aptitude, Banking Awareness",
    "SBI PO":    "Data Analysis, Reasoning, English, General/Economy/Banking Awareness",
    "RBI Grade B": "Economics, Finance, Management, English",
    "UPPSC":     "Indian History, Geography, Polity, Economy, Science, UP-specific GK",
    "BPSC":      "Indian History, Bihar GK, Geography, Polity, Economy",
    "General GK": "Indian History, Geography, Polity, Economy, Science, Current Affairs",
}

_QUIZ_PROMPT = """You are an expert Indian government exam coach. Generate {count} multiple-choice questions (MCQs) for the exam: {exam}.

Requirements:
- Questions must be relevant to the {exam} exam syllabus
- Each question must have exactly 4 options (A, B, C, D)
- Difficulty: {difficulty}
- Topics: {topics}
- Include a clear, educational explanation (2-3 sentences) for the correct answer
- Questions should test conceptual understanding, not just rote memory

Return ONLY a valid JSON array (no markdown, no extra text):
[
  {{
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct": 0,
    "topic": "Topic name",
    "explanation": "Why this is the correct answer..."
  }}
]

correct is the 0-based index of the right answer."""


def generate_quiz_questions(exam: str = "General GK", count: int = 10,
                             difficulty: str = "medium") -> list[dict]:
    """Generate MCQ questions. Returns [] on failure."""
    topics = _EXAM_TOPICS.get(exam, _EXAM_TOPICS["General GK"])
    prompt = _QUIZ_PROMPT.format(
        count=count, exam=exam, difficulty=difficulty, topics=topics
    )
    raw = _generate(_MODEL_FLASH, prompt, max_tokens=4096, temperature=0.7, timeout=60)
    questions = _parse_json(raw)
    if not isinstance(questions, list):
        return []
    valid = []
    for q in questions:
        if (isinstance(q.get("question"), str) and
                isinstance(q.get("options"), list) and
                len(q["options"]) == 4 and
                isinstance(q.get("correct"), int) and
                0 <= q["correct"] <= 3):
            valid.append({
                "question":    q["question"],
                "option_a":    q["options"][0],
                "option_b":    q["options"][1],
                "option_c":    q["options"][2],
                "option_d":    q["options"][3],
                "correct":     q["correct"],
                "topic":       q.get("topic", exam),
                "explanation": q.get("explanation", ""),
                "type":        "quiz",
            })
    log.info("Gemini generated %d valid quiz questions for %s", len(valid), exam)
    return valid


# ── Career roadmap ────────────────────────────────────────────────────────────

_ROADMAP_PROMPT = """You are India's top Sarkari Naukri career counselor. Create a personalized exam preparation roadmap.

Profile:
- Age: {age} years
- Education: {education}
- State: {state}
- Category: {category}
- Preferred exam type: {exam_type}
- Current preparation level: {prep_level}

Return ONLY valid JSON (no markdown):
{{
  "summary": "2-3 sentence overview of the candidate's best opportunities",
  "top_exams": [
    {{
      "name": "Exam name",
      "body": "Conducting organization",
      "why_fit": "Why this exam suits this specific profile",
      "eligibility": "Age/education requirement match",
      "competition_level": "Low / Medium / High / Very High",
      "salary": "Starting salary range",
      "timeline": "How long to prepare",
      "phase": "short / medium / long"
    }}
  ],
  "study_plan": {{
    "daily_hours": 4,
    "weekly_schedule": {{
      "monday": "Topic",
      "tuesday": "Topic",
      "wednesday": "Topic",
      "thursday": "Topic",
      "friday": "Topic",
      "saturday": "Topic",
      "sunday": "Revision and mock tests"
    }},
    "key_topics": ["Topic 1", "Topic 2", "Topic 3", "Topic 4", "Topic 5"],
    "books": ["Book 1 by Author", "Book 2 by Author"],
    "free_resources": ["Resource 1", "Resource 2"]
  }},
  "motivational_tip": "One powerful, personalized motivational message",
  "common_mistakes": ["Mistake 1", "Mistake 2", "Mistake 3"]
}}

Give exactly 3-4 top_exams best suited for this profile. Use real 2025-26 Indian exam names and salary figures."""


def generate_career_roadmap(profile: dict) -> dict | None:
    """Generate a personalized career roadmap. Returns None on failure."""
    prompt = _ROADMAP_PROMPT.format(
        age=profile.get("age", "22"),
        education=profile.get("education", "Graduate"),
        state=profile.get("state", "Any"),
        category=profile.get("category", "General"),
        exam_type=profile.get("exam_type", "Any"),
        prep_level=profile.get("prep_level", "Beginner"),
    )
    raw = _generate(_MODEL_FLASH, prompt, max_tokens=8192, temperature=0.6, timeout=45)
    roadmap = _parse_json(raw)
    if not isinstance(roadmap, dict):
        return None
    log.info("Gemini career roadmap generated for profile age=%s edu=%s",
             profile.get("age"), profile.get("education"))
    return roadmap
