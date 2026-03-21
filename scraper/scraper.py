"""
╔══════════════════════════════════════════════════════════╗
║       JobMitra - Sarkari Job Scraper  v9                ║
╠══════════════════════════════════════════════════════════╣
║  v7/v8 (previous):                                      ║
║  ✅ Title cleaner, fuzzy dedup, salary extraction       ║
║  ✅ Source trust score, notification/mode detection     ║
║  ✅ 86+ sources (RSS + direct), 24 parallel workers     ║
║                                                         ║
║  v9 NEW improvements:                                   ║
║  ✅ Fix: category Pass 2 — best-score match (not first) ║
║  ✅ published_at field — ISO pub date stored in job     ║
║  ✅ Freshness sort — newer pub ranks higher             ║
║  ✅ ISO date (YYYY-MM-DD) in extract_last_date          ║
║  ✅ Cleaner dept — strips year/noise from dept name     ║
║  ✅ Fuzzy dedup window 200 → 500                        ║
║  ✅ Workers: 24 → 32 RSS, 9 → 12 direct                ║
║  ✅ description field — first 500 chars stored          ║
╚══════════════════════════════════════════════════════════╝
"""

import requests, json, re, urllib3, sys, time, logging, hashlib, os
import xml.etree.ElementTree as ET
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ── Logging ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("scraper.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("jm")

# ══════════════════════════════════════════════════════════════
#  v7 TITLE CLEANER — strips garbage from RSS titles
#  e.g. "UPSC Recruitment 2026 [Apply Online] | SarkariResult"
#  → "UPSC Recruitment 2026"
# ══════════════════════════════════════════════════════════════

_TITLE_GARBAGE_SUFFIXES = re.compile(
    r"""
    \s*[\|\»\–\-]\s*(?:sarkari\s*result|sarkari\s*naukri|sarkari\s*exam|
        freejobalert|govtjobsblog|naukrinama|rojgarresult|
        sarkarijobs?|sarkarinaukri|recruitmentresult|jobmitra|
        latest\s*jobs?|sarkari\s*bharti|apply\s*online|official\s*site).*$
    |
    \s*[\[\(](?:apply\s*(?:online|now|here)|official|latest|
        new\s*vacancy|2025|2026|2027|last\s*date|closing|
        notification|advertisement|advt|pdf|download)[\]\)]\s*$
    |
    \s*(?:»|→|>>)\s*apply.*$
    |
    \s*\|\s*(?:check|read|click|download|official|direct|link)\b.*$
    |
    \s*-\s*(?:apply\s*(?:online|now)|official\s*website|last\s*date\s*extended)\s*$
    """,
    re.IGNORECASE | re.VERBOSE,
)

_TITLE_INLINE_BRACKETS = re.compile(
    r"\s*[\[\(]\s*(?:apply\s*(?:online|now|here)|official\s*notification"
    r"|direct\s*link|pdf\s*download|check\s*here)\s*[\]\)]\s*",
    re.IGNORECASE,
)

_TITLE_YEAR_BRACKET = re.compile(r"\s*[\[\(]20\d{2}[\]\)]\s*")
_TITLE_MULTI_SPACE  = re.compile(r"\s{2,}")

def clean_title(title: str) -> str:
    """v7: Clean up junk from RSS titles."""
    t = _TITLE_GARBAGE_SUFFIXES.sub("", title).strip()
    t = _TITLE_INLINE_BRACKETS.sub(" ", t).strip()
    t = _TITLE_YEAR_BRACKET.sub(" ", t).strip()
    t = _TITLE_MULTI_SPACE.sub(" ", t).strip()
    # Remove trailing punctuation
    t = t.rstrip("|-:,.")
    return t[:250] if t else title[:250]


# ══════════════════════════════════════════════════════════════
#  v7 SALARY EXTRACTION
#  Extracts pay level / grade pay / CTC from job text
# ══════════════════════════════════════════════════════════════

def extract_salary(text: str) -> dict:
    """
    v7: Extract salary info. Returns dict:
      {pay_scale: str, grade_pay: int, pay_level: int, salary_est: str}
    """
    t = text.lower()
    result = {}

    # Pay Level (7th CPC)
    m = re.search(r"pay\s*level[\s\-:]+(\d{1,2})\b", t)
    if m:
        level = int(m.group(1))
        if 1 <= level <= 18:
            result["pay_level"] = level
            # Approximate salary from level
            level_salary = {
                1: "18000-56900", 2: "19900-63200", 3: "21700-69100",
                4: "25500-81100", 5: "29200-92300", 6: "35400-112400",
                7: "44900-142400", 8: "47600-151100", 9: "53100-167800",
                10: "56100-177500", 11: "67700-208700", 12: "78800-209200",
                13: "123100-215900", 14: "144200-218200",
            }
            if level in level_salary:
                result["pay_scale"] = f"₹{level_salary[level]}"

    # Grade Pay (6th CPC legacy)
    m = re.search(r"grade\s*pay[\s\-:]+(?:rs\.?\s*|₹\s*)?([\d,]+)", t)
    if m:
        gp = int(m.group(1).replace(",", ""))
        if 1000 <= gp <= 12000:
            result["grade_pay"] = gp

    # Pay Band / Scale
    m = re.search(
        r"(?:pay\s*(?:scale|band)|salary|emoluments?|remuneration|ctc)"
        r"[\s\-:]+(?:rs\.?\s*|₹\s*)?([\d,]+)(?:\s*[-–]\s*([\d,]+))?",
        t,
    )
    if m and not result.get("pay_scale"):
        lo = int(m.group(1).replace(",", ""))
        if 5000 <= lo <= 300000:
            hi = m.group(2)
            if hi:
                hi_int = int(hi.replace(",", ""))
                result["pay_scale"] = f"₹{lo:,}-{hi_int:,}"
            else:
                result["pay_scale"] = f"₹{lo:,}+"

    # Consolidated pay
    m = re.search(
        r"consolidated\s*(?:pay|salary|amount)[\s\-:]+(?:rs\.?\s*|₹\s*)?([\d,]+)",
        t,
    )
    if m and not result.get("pay_scale"):
        amt = int(m.group(1).replace(",", ""))
        if 5000 <= amt <= 300000:
            result["pay_scale"] = f"₹{amt:,} (consolidated)"

    # Stipend
    m = re.search(r"stipend[\s\-:]+(?:rs\.?\s*|₹\s*)?([\d,]+)", t)
    if m and not result.get("pay_scale"):
        amt = int(m.group(1).replace(",", ""))
        if 3000 <= amt <= 100000:
            result["pay_scale"] = f"₹{amt:,} (stipend)"

    return result


# ══════════════════════════════════════════════════════════════
#  v7 NOTIFICATION TYPE & APPLICATION MODE
# ══════════════════════════════════════════════════════════════

def detect_notification_type(text: str) -> str:
    """v7: Detect if notification is new, re-open, or extended."""
    t = text.lower()
    if any(w in t for w in ["re-open", "reopen", "fresh application",
                             "fresh notification", "re open"]):
        return "re-open"
    if any(w in t for w in ["last date extended", "date extended",
                             "extended till", "extension of date"]):
        return "extended"
    return "new"


def detect_application_mode(text: str) -> str:
    """v7: Detect online / offline / walk-in application."""
    t = text.lower()
    if any(w in t for w in ["walk-in", "walk in", "walkin", "walk in interview"]):
        return "walk-in"
    if any(w in t for w in ["offline", "postal", "send application",
                              "send your application", "by post", "by hand",
                              "speed post", "registered post"]):
        return "offline"
    # Default: online
    return "online"


# ══════════════════════════════════════════════════════════════
#  v7 SOURCE TRUST SCORES
#  Higher score = more reliable/accurate source
# ══════════════════════════════════════════════════════════════

SOURCE_TRUST = {
    # Top tier
    "freejobalert":     10,
    "govtjobsblog":     9,
    "sarkariexam":      9,
    "SarkariResult":    9,
    "sarkariresultcom": 9,
    "employment_news":  9,
    "rojgarsamachar":   9,
    "RecruitmentResult":8,
    "MySarkariNaukri":  8,
    "FreeJobAlert":     8,
    "careerpower":      8,
    "adda247":          8,
    # FJA category feeds
    "fja_railway":9, "fja_bank":9, "fja_ssc":9, "fja_upsc":9,
    "fja_police":9,  "fja_defence":9,
    "fja_teaching":8, "fja_medical":8, "fja_anganwadi":8, "fja_psu":8,
    "fja_10th":8, "fja_12th":8, "fja_graduate":8, "fja_engineering":8,
    "fja_iti":8, "fja_it":8, "fja_forest":8, "fja_postal":8,
    "fja_judicial":8, "fja_research":8,
    # Good tier
    "applyfornaukri":7, "sarkarijobs_com":7, "haryanajobs":7,
    "sarkarijobfind":7, "freshersworld":7, "freshersworld_dir":7,
    "govtjobsguide":7, "sarkariprep":7, "jobsarkari":7,
    "recruitmentindia":7, "ndtv_jobs":7, "jagran_jobs":7,
    # Medium tier
    "naukrinama":6, "thesarkarinaukri":6, "sarkarinaukriblog":6,
    "LinkingSky":6, "govtjobpedia":6, "sarkarinaukrified":6,
    "sarkariwalah":6, "govtjob247":6, "naukrimission":6,
    "currentgk":6, "governmentjobsinfo":6, "jobsarkariresult":6,
    "freejobalert2":6,
    # Default tier
    "JobAlertsHub":5, "privatejobshub":5, "jobsalertguru":5,
    "sarkarijobsearcher":5, "sarkariresultnet":5,
}
_DEFAULT_TRUST = 5

# ════════════════════════════════════════════════════════
#  SIMPLE FILE CACHE  (saves HTTP calls between runs)
#  Cache directory: .cache/  |  TTL: 6 hours
# ════════════════════════════════════════════════════════

CACHE_DIR = Path(".cache")
CACHE_TTL  = 6 * 3600  # seconds

def _cache_path(url: str) -> Path:
    h = hashlib.md5(url.encode()).hexdigest()
    return CACHE_DIR / h

def _cache_get(url: str) -> str | None:
    p = _cache_path(url)
    if p.exists() and (time.time() - p.stat().st_mtime) < CACHE_TTL:
        try:
            return p.read_text(encoding="utf-8")
        except Exception:
            pass
    return None

def _cache_set(url: str, text: str):
    CACHE_DIR.mkdir(exist_ok=True)
    try:
        _cache_path(url).write_text(text, encoding="utf-8")
    except Exception:
        pass

# ════════════════════════════════════════════════════════
#  SOURCE LIST — v8: massive expansion, FJA URLs fixed, 30+ new sources
# ════════════════════════════════════════════════════════

RSS_SOURCES = {
    # ══ TIER 1: High-yield confirmed (working in v6 run) ══
    "freejobalert":      "https://www.freejobalert.com/feed/",
    "govtjobsblog":      "https://www.govtjobsblog.in/feed/",
    "sarkariexam":       "https://www.sarkariexam.com/feed/",
    "applyfornaukri":    "https://applyfornaukri.com/feed/",
    "thesarkarinaukri":  "https://thesarkarinaukri.com/feed/",
    "sarkarijobs_com":   "https://www.sarkarijobs.com/feed/",
    "sarkarijobfind":    "https://sarkarijobfind.com/feed/",
    "haryanajobs":       "https://haryanajobs.in/feed/",
    "sarkarinetwork":    "https://sarkarinetwork.com/feed/",
    "rojgarresult":      "https://rojgarresult.com/feed/",
    "sarkariresultapp":  "https://www.sarkariresult.app/feed/",
    "sarkarinaukriblog": "https://www.sarkarinaukriblog.com/feeds/posts/default?alt=rss",
    "jobapply24":        "https://jobapply24.in/feed/",
    "rojgar_result2":    "https://www.rojgar-result.com/feed/",
    "naukrinama":        "https://naukrinama.com/feed/",
    "indiajoblive":      "https://www.indiajoblive.com/feed/",
    "governmentjobsindia":"https://governmentjobsindia.net/feed/",

    # ══ TIER 2: New high-quality RSS sources ══
    "sarkariresultcom":  "https://www.sarkariresult.com/feed/",
    "freshersworld":     "https://www.freshersworld.com/feed/",
    "govtjobsguide":     "https://govtjobsguide.com/feed/",
    "rojgarsamachar":    "https://rojgarsamachar.gov.in/feed/",
    "employment_news":   "https://www.employmentnews.gov.in/feed/",
    "careerpower":       "https://www.careerpower.in/blog/feed/",
    "adda247":           "https://currentaffairs.adda247.com/feed/",
    "sarkariprep":       "https://sarkariprep.in/feed/",
    "jobsarkari":        "https://jobsarkari.com/feed/",
    "govtjobpedia":      "https://govtjobpedia.com/feed/",
    "sarkarinaukrified": "https://sarkarinaukrified.com/feed/",
    "sarkariwalah":      "https://www.sarkariwalah.com/feed/",
    "govtjob247":        "https://govtjob247.com/feed/",
    "naukrimission":     "https://naukrimission.com/feed/",
    "privatejobshub":    "https://www.privatejobshub.in/feeds/posts/default?alt=rss",
    "jobsalertguru":     "https://www.jobsalertguru.com/feed/",
    "currentgk":         "https://www.currentgk.com/feed/",
    "governmentjobsinfo":"https://www.governmentjobsinfo.com/feed/",
    "jobsarkariresult":  "https://jobsarkariresult.com/feed/",
    "recruitmentindia":  "https://www.recruitmentindia.in/feed/",
    "freejobalert2":     "https://freejobalert2.com/feed/",
    "sarkarijobsearcher":"https://sarkarijobsearcher.com/feed/",
    "sarkariresultnet":  "https://sarkariresult.net/feed/",

    # ══ TIER 3: FreeJobAlert category feeds ══
    # v8: Correct URL pattern is /category/X-jobs/feed/ (not /X-jobs/feed/)
    "fja_10th":         "https://www.freejobalert.com/category/10th-pass-govt-jobs/feed/",
    "fja_12th":         "https://www.freejobalert.com/category/12th-pass-govt-jobs/feed/",
    "fja_graduate":     "https://www.freejobalert.com/category/graduate-pass-govt-jobs/feed/",
    "fja_engineering":  "https://www.freejobalert.com/category/engineering-govt-jobs/feed/",
    "fja_medical":      "https://www.freejobalert.com/category/medical-paramedical-govt-jobs/feed/",
    "fja_anganwadi":    "https://www.freejobalert.com/category/anganwadi-jobs/feed/",
    "fja_railway":      "https://www.freejobalert.com/category/railway-jobs/feed/",
    "fja_bank":         "https://www.freejobalert.com/category/bank-jobs/feed/",
    "fja_ssc":          "https://www.freejobalert.com/category/ssc-jobs/feed/",
    "fja_police":       "https://www.freejobalert.com/category/police-jobs/feed/",
    "fja_defence":      "https://www.freejobalert.com/category/defence-jobs/feed/",
    "fja_teaching":     "https://www.freejobalert.com/category/teaching-jobs/feed/",
    "fja_psu":          "https://www.freejobalert.com/category/psu-govt-jobs/feed/",
    "fja_upsc":         "https://www.freejobalert.com/category/upsc-jobs/feed/",
    "fja_iti":          "https://www.freejobalert.com/category/iti-jobs/feed/",
    "fja_it":           "https://www.freejobalert.com/category/it-computer-jobs/feed/",
    "fja_forest":       "https://www.freejobalert.com/category/forest-department-jobs/feed/",
    "fja_postal":       "https://www.freejobalert.com/category/postal-jobs/feed/",
    "fja_judicial":     "https://www.freejobalert.com/category/judicial-court-jobs/feed/",
    "fja_research":     "https://www.freejobalert.com/category/research-jobs/feed/",

    # ══ TIER 4: State-specific feeds (new active URLs) ══
    "up_rojgar":         "https://www.uprojgar.com/feed/",
    "up_bhartimela":     "https://upbhartimela.com/feed/",
    "mp_rojgar":         "https://mprojgar.com/feed/",
    "mp_vyapam":         "https://mpvyapam.com/feed/",
    "bihar_sarkar":      "https://biharjobs.net/feed/",
    "rajasthan_jobs":    "https://rajasthanrpsc.com/feed/",
    "gujarat_jobs":      "https://gujaratjobs.net/feed/",
    "maharashtra_jobs":  "https://maharashtrajobs.net/feed/",
    "karnataka_jobs":    "https://karnatakajobs.in/feed/",
    "tamilnadu_jobs":    "https://tamilnadujobs.in/feed/",
    "haryana_sarkari":   "https://haryanagovtjobs.in/feed/",
    "punjab_sarkar":     "https://punjabsarkarijobs.com/feed/",
    "delhi_jobs":        "https://delhigovtjobs.in/feed/",
    "odisha_jobs":       "https://odishagovtjobs.com/feed/",
    "assam_jobs":        "https://assamjobs.net/feed/",
    "jharkhand_jobs":    "https://jharkhandjobs.net/feed/",

    # ══ TIER 5: Previously dead — keep trying ══
    "sarkariresult_news":"https://sarkariresultsnews.com/feed/",
    "naukridaily":       "https://naukridaily.in/feed/",
    "sarkarinokri":      "https://sarkarinokri.com/feed/",
    "sarkariresultup":   "https://sarkariresultup.com/feed/",
    "jobnotification":   "https://www.jobnotification.in/feed/",
    "govtjobguru":       "https://www.govtjobguru.in/feed/",
    "recruitmentcare":   "https://www.recruitmentcare.com/feed/",
    "govtjobstop":       "https://govtjobstop.com/feed/",
    "sarkarinaukri_in":  "https://sarkarinaukri.in/feed/",
    "freejobsalert":     "https://freejobsalert.in/feed/",

    # ══ TIER 6: New sources added ══
    "bharatnaukri":      "https://bharatnaukri.com/feed/",
    "govtjobsdiary":     "https://govtjobsdiary.com/feed/",
    "sharmajobs":        "https://www.sharmajobs.com/feed/",
    "sarkarinaukri2025": "https://sarkarinaukri2025.com/feed/",
}

DIRECT_SOURCES = {
    "sarkariresult":    "https://www.sarkariresult.com/latestjob/",
    "recruitresult":    "https://recruitmentresult.com/jobs/",
    "linkingsky":       "https://linkingsky.com/",
    "mysarkarinaukri":  "https://www.mysarkarinaukri.com/",
    "freejobalert_dir": "https://www.freejobalert.com/latest-notifications/",
    "jobalertshub_dir": "https://jobalertshub.com/",
    # v8 new direct scrapers
    "freshersworld_dir":"https://www.freshersworld.com/jobs/government-jobs/",
    "ndtv_jobs":        "https://www.ndtv.com/jobs/government-jobs",
    "jagran_jobs":      "https://jobs.jagran.com/government-jobs/",
}

# ════════════════════════════════════════════════════════
#  CATEGORY MAP — v6: improved + new categories
# ════════════════════════════════════════════════════════

CATEGORY_MAP = {
    "railway": [
        "railway", "rrb ", "rrb-", "rrc ", "irctc", "ircon", "rvnl", "irfc",
        "cris ", "railtel", "rites ", "rail wheel", "konkan railway",
        "western railway", "central railway", "northern railway",
        "eastern railway", "southern railway", "south western railway",
        "south central railway", "north western railway", "northeast frontier",
        "north east frontier", "nfr ", "ecr ", "ncr ", "scr ", "ser ",
        "loco pilot", "group d", "group-d", "rrb ntpc", "tte post",
        "ticket examiner", "station master", "guard post", "railway apprentice",
        "rail coach", "track maintainer", "metro rail", "dmrc", "bmrc",
        "railway recruitment", "train controller",
    ],
    "banking": [
        "bank", "ibps", "sbi ", "rbi ", "nabard", "idbi", "niacl", "uiic",
        "lic ", "gic ", "iffco", "sidbi", "exim bank", "canara bank",
        "bank of baroda", "pnb ", "punjab national", "union bank",
        "bank of india", "central bank", "indian bank", "uco bank",
        "bandhan bank", "federal bank", "cooperative bank", "gramin bank",
        "apgb ", "ksccb", "dccb ", "tgb ", "andhra bank", "bob ",
        " po ", "probationary officer", "bank po", "bank clerk", "clerk post",
        "jam post", "specialist officer", "assistant manager", "deputy manager",
        "field officer", "it officer", "credit officer", "forex officer",
        "credit analyst", "treasury officer", "financial analyst bank",
        "business correspondent", "branch manager bank", "banking",
        "financial inclusion", "bancassurance", "wealth manager",
    ],
    "ssc": [
        "ssc ", "staff selection commission", "hssc ", "uppsc", "bpsc",
        "mpsc ", "rpsc ", "wbpsc", "kpsc ", "opsc ", "jpsc ", "apsc ",
        "upsssc", "cgpsc", "ukpsc", "hppsc", "tnpsc", "appsc", "tspsc",
        "gsssb", "gpsc ", "psssb", "ppsc ", "mppsc", "bihar ssc",
        "cgl", "chsl", "chsl exam", "mts exam", "steno", "stenographer", "combined graduate",
        "combined higher", "junior assistant", "upper division clerk",
        "lower division clerk", "udc post", "ldc post", "combined exam",
        "pharmacist post", "junior clerk",
    ],
    "teaching": [
        "kvs ", "nvs ", "navodaya", "kendriya vidyalaya", "sainik school",
        "army school", "dsssb teacher", "reet ", "stet ", "super tet", "ctet",
        "ncert", "niepa",
        "teacher", " tgt", " pgt", " prt", "b.ed", "bed ", "tet ",
        "lecturer", "professor", "principal", "headmaster", "headmistress",
        "guest faculty", "guest teacher", "junior basic teacher", " jbt",
        "assistant professor", "associate professor", "school teacher",
        "primary teacher", "secondary teacher", "college lecturer",
        "education officer", "academic associate", "teaching associate",
        "physical education teacher", "pet post", "art teacher",
        "music teacher", "shikshak", "adhyapak", "pradhyapak",
        "teaching staff", "coaching staff", "training officer",
    ],
    "police": [
        "police", "cisf ", "crpf ", "bsf ", "itbp ", "ssb ", "paramilitary",
        "armed police", "home guard", "nsg ", "spr post", "jail",
        "constable", "sub inspector", " si ", " asi ", "inspector",
        "traffic police", "jail prahari", "prison officer", "warder",
        "jail warden", "excise inspector", "special police officer",
        "spo post", "civil defence", "fire brigade", "fireman",
        "fire station", "operator post fire", "driver constable",
    ],
    "defence": [
        "army", "navy", "airforce", "air force", "agniveer", "nda ",
        "cds ", "military", "coast guard", "territorial army",
        "drdo", "drdl", "defence research", "ordnance", "ofb ",
        "oem post", "ammunition", "armament",
        "soldier", "ssr post", "mr post", "nausena", "vayu sena",
        "havildar", "naib subedar", "sepoy", "rifleman",
        "technical entry scheme", "tes post", "10+2 cadet",
        "indian army", "indian navy", "indian air force",
        "military nursing", "army nursing", "army medical corps",
    ],
    "upsc": [
        "upsc", " ias", " ips", "civil services", " ifs", " irs",
        "iras", "capf ", "ese ", "combined defence", "cms exam",
        "nda exam", "cds exam", "scra", "ies ", "iss ", "ifos",
        "geologist exam", "upsc interview", "upsc prelim", "upsc main",
        "civil service", "indian forest service", "indian revenue service",
    ],
    "anganwadi": [
        "anganwadi", "icds ", "sahayika", "asha worker", "asha post",
        "anganwadi supervisor", "cdpo ", "mini anganwadi", "bal sevika",
        "anganwadi helper", "anganwadi worker", "wcd ", "wcdc ",
        "mahila bal vikas", "aanganwadi", "aanganwadi worker",
        "nutrition worker", "mukhya sevika",
    ],
    "medical": [
        "aiims", "norcet", "esic ", "pgimer", "nimhans", "jipmer",
        "cghs ", "esi hospital", "nims ", "svims", "rims ", "gmch",
        "nhm ", "nrhm ", "health dept", "health department",
        "public health", "chc ", "phc ", "community health",
        "nurse", "nursing officer", "staff nurse", "doctor", "mbbs",
        "pharmacist", "lab technician", "laboratory", "medical officer",
        "health worker", "dental", "dentist", "radiographer", "paramedic",
        "surgical", "ortho", "pathologist", "veterinary", "pashu",
        "animal husbandry", "ayush", "homeopathy", "ayurvedic",
        "junior resident", "senior resident", "junior medical officer",
        "general duty medical", "gdmo", "medical superintendent",
        "health inspector", "sanitary inspector", "radiology",
        "physiotherapy", "occupational therapy", "speech therapy",
        "ophthalmic", "ent post", "physician", "gynaecologist",
        "paediatrician", "psychiatrist", "dermatologist",
        "anaesthesia", "blood bank", "medical college", "nursing college",
        "ward attendant", "hospital attendant", "health assistant",
        "multipurpose health worker", "mphw", "flu",
    ],
    "psu": [
        "ongc", "bhel ", "sail ", "hal ", "hpcl", "iocl", "bpcl", "npcil",
        "gail", "bsnl", "nalco", "mecl ", "moil ", "beml ", "midhani",
        "powergrid", "pgcil", "bhavini", "wapcos", "hscl", "hocl",
        "balmer lawrie", "nbcc ", "mmrda", "nmdc", "mangalore refinery",
        "mrpl ", "gspc ", "gsecl", "kochi refinery", "numaligarh",
        "hindustan copper", "national fertilizers", "nfl post",
        "rashtriya chemicals", "rcf ", "fact post", "hurl ", "bfcl",
        "eil post", "pdil", "tcil ", "mtnl ", "itpo ", "nsic ",
        "public sector undertaking", "psu post", "central psu",
        "navratna", "maharatna", "miniratna",
    ],
    "engineering": [
        "engineer", " je ", "junior engineer", " ae ", "assistant engineer",
        "technical assistant", "apprentice", "iti apprentice", "trade apprentice",
        "technician", "junior technical", "technical officer", "project engineer",
        "site engineer", "civil engineer", "electrical engineer",
        "mechanical engineer", "electronics engineer", "instrumentation",
        "chemical engineer", "mining engineer", "metallurgical",
        "structural engineer", "quality engineer", "safety officer",
        "fire officer", "environment officer", "graduate trainee",
        "engineer trainee", "management trainee engineer",
        "diploma trainee", "iti trainee", "field engineer",
        "maintenance engineer", "production engineer",
        "supervisor post", "foreman post", "overman post", "sirdar",
        "electrician apprentice", "fitter apprentice",
        # v9: skilled trades / utility workers
        "electrician post", "lineman post", "wireman post",
        "pump operator", "helper electrician", "cable jointer",
        "fitter post", "welder post", "rigger post", "machinist",
        "turner post", "plumber post", "carpenter post",
        "draftsman", "surveyor post", "estimator post",
        "works assistant", "works supervisor",
        "pwo ", "pwd ", "cpwd", "irrigation dept",
    ],
    "postal": [
        "postal", "gramin dak", "gds ", "post office", "india post",
        "india post gds", "branch postmaster", "bpm post", "abpm",
        "dak sevak", "postman", "mail guard", "sorting assistant",
        "postal assistant", "pa/sa", "postmaster",
        "department of post", "dop post",
    ],
    "revenue": [
        "patwari", "lekhpal", "revenue", "kanungo", "naib tehsildar",
        "tehsildar", "gram sachiv", "panchayat secretary",
        "village development officer", "vdo post", "gram vikas",
        "gram panchayat", "gram sevak", "revenue inspector",
        "sub registrar", "stamp inspector",
    ],
    "forest": [
        "forest guard", "van rakshak", "van vibhag", "wildlife",
        "forest dept", "aranya vibhag", "forest ranger", "van aarakshak",
        "forest officer", "deputy ranger", "forester", "beat guard",
        "wildlife inspector", "zoo keeper",
    ],
    "skill": [
        "kaushal", "rozgar nigam", "rojgar nigam", "hkrn",
        "skill development", "msme ", "nsdc ", "skill india",
        "pradhan mantri kaushal", "pmkvy", "rpl post",
    ],
    "accounts": [
        "accountant", "auditor", "finance officer", "accounts officer",
        "chartered accountant", "junior accountant", "financial advisor",
        "taxation officer", "income tax", "customs officer",
        "excise officer", "ca post", "cma post", "cost accountant",
        "internal audit", "comptroller", "tax assistant",
        "income tax inspector", "customs inspector",
    ],
    "legal": [
        "legal", "law officer", "advocate", "judicial", "district court",
        "high court", "supreme court", "law assistant", "notary",
        "legal aid", "public prosecutor", "government pleader",
        "district judge", "civil judge", "munsif", "amicus curiae",
        "court attendant", "process server", "typist cum assistant",
    ],
    "it_tech": [
        "software", "developer", "programmer", "data scientist",
        "data analyst", "machine learning", "artificial intelligence",
        "cyber security", "network engineer", "system administrator",
        "database administrator", "dba post", "web developer",
        "mobile developer", "devops", "cloud engineer",
        "nic ", "nics ", "national informatics", "cdac ", "nielit",
        "it officer", "computer operator", "data entry",
        "programmer analyst", "system analyst", "it manager",
        "information technology", "digital india", "e-governance",
        "it assistant", "computer assistant", "technical support",
        "geo-informatics", "gis officer",
    ],
    "research": [
        "scientist", "research fellow", "junior research fellow",
        "jrf post", "srf post", "senior research fellow",
        "project associate", "project assistant", "research associate",
        "research officer", "iit ", "iim ", "nit ", "iisc ", "csir",
        "isro", "barc ", "icar ", "icmr", "dbt post",
        "dst post", "dst fellow", "research scientist",
        "research engineer", "lab assistant", "field investigator",
        "iiser", "iipe", "niper", "nabi ", "nipgr", "bits pilani",
        "research analyst", "subject matter expert",
        "project research", "research cum teaching",
    ],
    "admin": [
        "office assistant", "office attendant", "office superintendent",
        "multi tasking staff", " mts post", "peon post", "attender post",
        "group c post", "group d post",
        "data entry operator", " deo post",
        "personal assistant", " pa post", "private secretary",
        "section officer", " so post", "assistant section officer", " aso",
        "assistant director", "deputy director", "joint director",
        "driver post", "despatch rider", "despatch assistant",
        "record keeper", "store keeper", "cashier post",
        "receptionist", "security guard", "watchman post",
        "chowkidar", "sweeper post", "sanitation worker",
        "mali post", "cook post", "helper post",
        # v9: broader admin/clerical terms
        " clerk ", "steno post", "stenotypist", "typist post",
        "lower division", "upper division", "junior assistant",
        "computer operator", "orderly post", "sahayak post",
        "peon cum", "attender cum", "multi purpose", "casual worker",
        "daily wage", "contract basis", "outsoursing post",
        "group b post", "grade iv", "grade iii",
    ],
    "misc_govt": [
        "central government", "state government", "govt of india",
        "ministry of", "department of", "directorate of",
        "municipal corporation", "nagar palika", "nagar nigam",
        "gram panchayat", "zila panchayat", "district collectorate",
        "collectorate", "tehsil", "block office", "taluka",
        "young professional", "management trainee", "yp post",
        "hll lifecare", "wamul", "nedfl", "ntpc hospital",
        "recruitment of young", "recruitment of hospital",
        "ap outsourcing", "apcos",
        # v9: water / electricity / urban bodies
        "jal nigam", "jal board", "jal sansthan", "jal aapur",
        "bijli vibhag", "electricity board", "discom ", "transco ",
        "vidyut nigam", "vidyut vitran", "power corporation",
        "sewerage board", "sewage treatment", "urban body",
        "vikas pradhikaran", "development authority", "housing board",
        "transport corporation", "roadways", "bus depot",
        "social welfare", "samaj kalyan", "tribal welfare",
        "minority welfare", "backward class", "mahila vikas",
        "bal vikas", "child development", "women empowerment",
        "cooperative department", "sahkari vibhag",
        "district collector", "sub divisional", "block development officer",
    ],
    "sports": [
        "sports quota", "sports officer", "sport", "athletic",
        "coach post", "head coach", "physical instructor",
        "stadium manager", "sports authority",
    ],
    "culture_arts": [
        "kalakshetra", "cultural officer", "ksssci", "cultural",
        "sangeet natak", "lalit kala", "bass kalakshetra",
        "museum officer", "ncsm", "exhibition officer",
        "botanical survey", "zoological survey",
        "library", "librarian", "archivist",
    ],
    "others": [],  # catch-all — expanded keywords reduce this bucket
}

# v8: Extra category hints — keywords that didn't fit above categories
# These patch common misclassifications seen in v6 run
_EXTRA_CATEGORY_HINTS = {
    "postal": ["india post", "postman", "gramin dak", "gds ", "dak sevak",
               "postal circle", "post office", "branch postmaster"],
    "revenue": ["patwari", "lekhpal", "gram sachiv", "revenue inspector",
                "kanungo", "naib tehsildar", "village officer", "panchayat sahayak"],
    "forest": ["forest guard", "van rakshak", "forest ranger", "wildlife guard",
               "van aarakshak", "beat guard", "forester post"],
    "accounts": ["accountant", "auditor", "ca post", "finance officer",
                 "income tax inspector", "customs inspector", "tax assistant",
                 "taxation", "treasury", "pay accounts"],
    "admin": ["mts post", "multi tasking", "peon post", "deo post",
              "data entry operator", "office attendant", "group d",
              "chowkidar", "watchman", "driver post", "sweeper",
              "steno", "typist", "stenographer", "lower division clerk",
              "upper division clerk", "junior clerk", "senior clerk",
              "sahayak", "class iv", "class iii", "support staff"],
    "engineering": ["apprentice", "trade apprentice", "iti apprentice",
                    "junior engineer", "graduate trainee", "foreman",
                    "electrician", "lineman", "wireman", "fitter",
                    "pump operator", "welder", "technician"],
    "misc_govt": ["municipal corporation", "nagar palika", "nagar nigam",
                  "gram panchayat", "block development", "taluka",
                  "management trainee", "young professional",
                  "jal nigam", "jal board", "bijli vibhag", "discom",
                  "vidyut", "roadways", "transport corporation",
                  "housing board", "development authority",
                  "cooperative", "sahkari", "social welfare", "mahila"],
    "banking": ["cooperative bank", "sahkari bank", "credit society",
                "sakh samiti", "gramin bank", "urban cooperative",
                "district cooperative", "land development bank"],
    "medical": ["nhm ", "national health mission", "ayushman",
                "jan aushadhi", "health and wellness", "sub health centre",
                "primary health", "community health officer",
                "multipurpose worker", "health supervisor"],
    "upsc": ["state psc", "combined state", "civil service exam",
             "administrative service", "ias pre", "ias main"],
}

QUAL_MAP = {
    "8th":          ["8th pass", "class 8", "viii pass", "class viii"],
    "10th":         ["10th", "matric", "sslc", "class x", "x pass",
                     "high school pass", "secondary pass", "10+0",
                     "10 th", "tenth pass"],
    "12th":         ["12th", "intermediate", "class xii", "xii pass",
                     "higher secondary", "10+2", "hs pass", "sr. secondary",
                     "plus two", "+2 pass", "12 th", "twelfth pass"],
    "diploma":      ["diploma", "iti ", "polytechnic", "vocational",
                     "trade certificate", "itc ", "iti pass",
                     "diploma holder", "3 year diploma"],
    "graduate":     ["graduate", "graduation", "any degree", "b.a.", "b.sc",
                     "b.com", "btech", "b.e.", "b.ed", "bachelor", "b.pharma",
                     "llb", "bca ", "b.ca", "b.arch", "b.plan",
                     "b.vsc", "bams", "bhms", "bds", "mbbs",
                     "b.tech", "be degree", "degree holder"],
    "postgraduate": ["post graduate", "postgraduate", "master", "mba",
                     "mca ", "m.sc", "m.com", "pg degree", "m.pharma",
                     "mtech", "m.e.", "m.tech", "m.arch", "md post",
                     "ms degree", "phd", "doctorate", "m.a.", "m.ed"],
}

# ── Job signal / noise filters ───────────────────────────
JOB_SIGNAL_WORDS = {
    "recruitment", "vacancy", "vacancies", "notification", "posts",
    "naukri", "bharti", "apply", "application", "hiring", "advt",
    "advertisement", "job", "jobs", "opening", "walk-in", "walk in",
    "selection", "online form", "online apply", "post",
}

NON_JOB_WORDS = {
    "result out", "merit list", "answer key", "admit card", "final result",
    "cut off", "cutoff", "scorecard", "score card", "interview schedule",
    "document verification", "dv schedule", "hall ticket",
    "exam date out", "exam city", "city intimation",
    # v8: blog/about post noise filter
    "what makes us special", "welcome to ", "about us", "privacy policy",
    "terms and conditions", "contact us", "your daily dose",
    "how to apply", "tips for", "best ways to", "top 10 ways",
    "why you should", "importance of", "career guidance",
}

PRIVATE_JOB_BLOCKLIST = {
    "gulf job", "gulf vacancy", "gulf walkin", "saudi aramco", "saudi arabia",
    "dubai job", "uae job", "qatar job", "kuwait job", "bahrain job",
    "abroad job", "overseas job", "foreign job", "international job",
    "gulf career", "middle east job",
    "ibm recruitment", "ibm hiring", "motorola", "infosys limited",
    "wipro recruitment", "tcs recruitment", "accenture recruitment",
    "cognizant recruitment", "capgemini", "hexaware", "mphasis",
    "cgs off campus", "off campus drive", "off campus recruitment",
    "campus placement", "freshers drive", "batch freshers",
    "infor off campus", "royal jet", "burjeel holdings",
    "25 hours hotel", "shutdown jobs uae",
}

GARBAGE_TITLE_PATTERNS = [
    r"^top\s+jobs\s*\(",
    r"^bank\s+jobs\s*\(",
    r"^railway\s+jobs\s*$",
    r"^aiims\s+jobs\s*$",
    r"^state\s+jobs\s*$",
    r"^police\s+vacancy\s*$",
    r"^jobs\s+for\s+women",
    r"^\[gulf",
    r"^apply\s+for\s+ssc\s+cgl",
    r"^apply\s+for\s+ssc\s+10",
    r"^apply\s+for\s+rrb",
    r"^final\s+call\s+for\s+neet",
    r"^neet\s+ug\s+\d{4}",
    r"^(page\s+\d|home|about|contact|privacy|menu|search|tag|category)",
]
_GARBAGE_RES = [re.compile(p, re.IGNORECASE) for p in GARBAGE_TITLE_PATTERNS]

PRIVATE_SOURCE_DOMAINS = {
    "freshersnow.com",
    "govtjobsdiary.com",
}

def _is_private_job(title: str, url: str) -> bool:
    t = title.lower()
    for phrase in PRIVATE_JOB_BLOCKLIST:
        if phrase in t:
            return True
    for pattern in _GARBAGE_RES:
        if pattern.search(title):
            return True
    domain = url.lower()
    if any(d in domain for d in PRIVATE_SOURCE_DOMAINS):
        private_signals = [
            "off campus", "batch freshers", "drive for 202",
            "ibm ", "motorola", "infosys limited", "wipro ",
            "gulf", "saudi", "uae ", "dubai", "qatar",
        ]
        if any(s in t for s in private_signals):
            return True
    return False

# ════════════════════════════════════════════════════════
#  EXTRACTION HELPERS
# ════════════════════════════════════════════════════════

def detect_category(text: str) -> str:
    t = text.lower()
    best_cat, best_score = "others", 0
    # Pass 1: main CATEGORY_MAP
    for cat, kws in CATEGORY_MAP.items():
        score = sum(1 for kw in kws if kw in t)
        if score > best_score:
            best_score = score
            best_cat = cat
    # Pass 2: if still "others", try extra hints — pick BEST score, not first
    if best_cat == "others":
        p2_best_cat, p2_best_score = "others", 0
        for cat, kws in _EXTRA_CATEGORY_HINTS.items():
            score = sum(1 for kw in kws if kw in t)
            if score > p2_best_score:
                p2_best_score = score
                p2_best_cat = cat
        if p2_best_cat != "others":
            best_cat = p2_best_cat
    return best_cat

def detect_qualification(text: str) -> list:
    t = text.lower()
    found = [q for q, kws in QUAL_MAP.items() if any(k in t for k in kws)]
    order = ["8th", "10th", "12th", "diploma", "graduate", "postgraduate"]
    found = sorted(found, key=lambda x: order.index(x) if x in order else 99)
    return found or ["graduate"]

def extract_vacancies(text: str) -> int:
    """
    v6: More aggressive vacancy extraction.
    Patterns ordered from most → least specific.
    """
    PATTERNS = [
        # "22195 Posts" / "22,195 posts"
        r"(\d[\d,]+)\s*(?:posts?|vacancies|vacancy|seats?|positions?|openings?)",
        # "for 22195 Posts"
        r"for\s+(\d[\d,]+)\s+(?:posts?|vacancies|various|vacancy)",
        # "Recruitment of 500"
        r"recruitment\s+(?:for|of)\s+(\d[\d,]+)",
        # "apply for 5000"
        r"apply\s+(?:online\s+)?for\s+(\d[\d,]+)",
        # Hindi
        r"(\d[\d,]+)\s*(?:नियुक्तियां|पद|रिक्तियां|भर्ती)",
        # "500 job openings"
        r"(\d[\d,]+)\s*(?:jobs?|openings?|positions?)",
        # "(22195 Posts)" in title parentheses
        r"\((\d[\d,]+)\s*(?:posts?|vacancies)\)",
        # "1440 Medical Officer" — number + role
        r"\b(\d{2,6})\b\s+(?:group|constable|engineer|teacher|clerk|officer|nurse|doctor|assistant|inspector|worker|helper|apprentice|trainee)",
        # "Total: 500" or "No. of posts: 500"
        r"(?:total|no\.?\s*of)\s*(?:posts?|vacancies)\s*[:\-–]?\s*(\d[\d,]+)",
    ]
    for pat in PATTERNS:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            v = int(m.group(1).replace(",", ""))
            if 0 < v < 1000000:
                return v
    return 0

def _parse_date_str(raw: str) -> str | None:
    raw = raw.strip()
    # v9: Handle ISO format YYYY-MM-DD before normalizing separators
    m_iso = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", raw)
    if m_iso:
        y, mo, d = int(m_iso.group(1)), int(m_iso.group(2)), int(m_iso.group(3))
        if 2024 <= y <= 2028:
            return f"{d:02d}/{mo:02d}/{y}"
    # Normalize separators
    raw = re.sub(r"[\s]+", "/", raw)
    raw = re.sub(r"[.\-]", "/", raw)
    for fmt in [
        "%d/%m/%Y", "%d/%m/%y",
        "%d/%b/%Y", "%d/%b/%y",
        "%d/%B/%Y", "%d/%B/%y",
        "%B/%d/%Y", "%b/%d/%Y",
        "%Y/%m/%d",
    ]:
        try:
            dt = datetime.strptime(raw, fmt)
            if dt.year < 100:
                dt = dt.replace(year=2000 + dt.year)
            if 2024 <= dt.year <= 2028:
                return dt.strftime("%d/%m/%Y")
        except ValueError:
            continue
    return None

def extract_last_date(text: str) -> str | None:
    """
    v6: Try harder to find the actual last_date from content.
    Priority: explicit last-date labels > apply-by > walk-in > bare dates.
    """
    PATTERNS = [
        # Explicit last date
        r"last\s*date\s*(?:of\s*(?:application|apply|online\s*form|receipt))?\s*[:\-–]\s*(\d{1,2}[\s\/\-\.]\d{1,2}[\s\/\-\.]\d{2,4})",
        r"closing\s*date\s*[:\-–]\s*(\d{1,2}[\s\/\-\.]\d{1,2}[\s\/\-\.]\d{2,4})",
        r"(?:last|closing)\s*date\s*[:\-–]\s*(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+20\d{2})",
        # Apply by / till
        r"apply\s*(?:online\s*)?(?:by|before|till|upto|up\s*to)\s*[:\-–]?\s*(\d{1,2}[\s\/\-\.]\d{1,2}[\s\/\-\.]\d{2,4})",
        r"application\s*(?:end|close)s?\s*(?:on|:)\s*(\d{1,2}[\s\/\-\.]\d{1,2}[\s\/\-\.]\d{2,4})",
        # Walk-in date
        r"walk\s*-?\s*in\s*(?:date|interview|on)\s*[:\-–]?\s*(\d{1,2}[\s\/\-\.]\d{1,2}[\s\/\-\.]\d{2,4})",
        # "on DD/MM/YYYY" or "on DD-MM-YYYY"
        r"\bon\s+(\d{1,2}[\-\/]\d{1,2}[\-\/]20(?:2[4-8]))\b",
        # Bare date with year 2025-2028
        r"\b(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]20(?:2[5-8]))\b",
        r"\b(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+20(?:2[5-8]))\b",
        # ISO format YYYY-MM-DD (from structured sources)
        r"\b(20(?:2[5-8])-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01]))\b",
    ]
    candidates = []
    for pat in PATTERNS:
        for m in re.finditer(pat, text, re.IGNORECASE):
            parsed = _parse_date_str(m.group(1))
            if parsed:
                try:
                    dt = datetime.strptime(parsed, "%d/%m/%Y")
                    # Only future dates (allow up to 1 day past)
                    if dt >= datetime.now() - timedelta(days=1):
                        candidates.append(dt)
                except ValueError:
                    pass
    if candidates:
        # Return the nearest upcoming date (most urgent)
        return min(candidates).strftime("%d/%m/%Y")
    return None

def _parse_pubdate_to_lastdate(pub_date: str) -> str | None:
    """
    v6: Parse RSS pubDate → estimate last_date as pub + 30 days.
    Only used as FALLBACK when no date found in content.
    """
    if not pub_date:
        return None
    pub_date = pub_date.strip()
    for fmt in [
        "%a, %d %b %Y %H:%M:%S %z",
        "%a, %d %b %Y %H:%M:%S %Z",
        "%a, %d %b %Y %H:%M:%S",
        "%d %b %Y %H:%M:%S %z",
        "%d %b %Y",
    ]:
        try:
            dt = datetime.strptime(pub_date[:31], fmt)
            if 2024 <= dt.year <= 2028:
                est = dt + timedelta(days=30)
                return est.strftime("%d/%m/%Y")
        except (ValueError, TypeError):
            continue
    # ISO 8601
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", pub_date)
    if m:
        y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if 2024 <= y <= 2028:
            est = datetime(y, mo, d) + timedelta(days=30)
            return est.strftime("%d/%m/%Y")
    return None

_DEPT_NOISE = re.compile(
    r"\b20\d{2}\b"                    # year numbers
    r"|\b(?:apply\s*(?:online|now|here)|official|latest|new|direct|link)\b"
    r"|[\[\(][^\]\)]{0,40}[\]\)]",    # bracketed content
    re.IGNORECASE,
)

def _extract_dept(title: str) -> str:
    m = re.match(
        r"^([A-Z][^–\-|:]{4,70}?)\s+"
        r"(?:Recruitment|Vacancy|Vacancies|Notification|Jobs?|Bharti)\b",
        title, re.IGNORECASE
    )
    dept = m.group(1).strip() if m else title[:70]
    # v9: strip year and noise words from department name
    dept = _DEPT_NOISE.sub(" ", dept).strip().rstrip(",-:")
    dept = re.sub(r"\s{2,}", " ", dept).strip()
    return dept[:80] if dept else title[:70]

# ── v6: Expanded STATE_MAP with abbreviations ────────────
STATE_MAP = {
    # Full names
    "uttar pradesh": "Uttar Pradesh",
    "madhya pradesh": "Madhya Pradesh",
    "himachal pradesh": "Himachal Pradesh",
    "arunachal pradesh": "Arunachal Pradesh",
    "andhra pradesh": "Andhra Pradesh",
    "west bengal": "West Bengal",
    "tamil nadu": "Tamil Nadu",
    "jammu and kashmir": "Jammu & Kashmir",
    "jammu & kashmir": "Jammu & Kashmir",
    "andaman and nicobar": "Andaman & Nicobar",
    "andaman & nicobar": "Andaman & Nicobar",
    # Common abbreviations (v6 new)
    " up ": "Uttar Pradesh",   "up govt": "Uttar Pradesh",
    " mp ": "Madhya Pradesh",  "mp govt": "Madhya Pradesh",
    " hp ": "Himachal Pradesh","hp govt": "Himachal Pradesh",
    " ap ": "Andhra Pradesh",  "ap govt": "Andhra Pradesh",
    " wb ": "West Bengal",     "wb govt": "West Bengal",
    " tn ": "Tamil Nadu",      "tn govt": "Tamil Nadu",
    " jk ": "Jammu & Kashmir", "j&k ": "Jammu & Kashmir",
    " cg ": "Chhattisgarh",   "cg govt": "Chhattisgarh",
    " uk ": "Uttarakhand",    "uk govt": "Uttarakhand",
    # Orgs / Commissions
    "uppsc": "Uttar Pradesh",  "upsssc": "Uttar Pradesh",
    "up police": "Uttar Pradesh", "lucknow": "Uttar Pradesh",
    "bpsc": "Bihar",           "bssc": "Bihar",
    "patna": "Bihar",
    "mpesb": "Madhya Pradesh", "vyapam": "Madhya Pradesh",
    "bhopal": "Madhya Pradesh",
    "rpsc": "Rajasthan",       "rssb": "Rajasthan",
    "jaipur": "Rajasthan",     "rajasthan": "Rajasthan",
    "gpsc": "Gujarat",         "ahmedabad": "Gujarat",
    "gujarat": "Gujarat",
    "mpsc": "Maharashtra",     "mahapariksha": "Maharashtra",
    "mumbai": "Maharashtra",   "pune": "Maharashtra",
    "nagpur": "Maharashtra",   "maharashtra": "Maharashtra",
    "kpsc": "Karnataka",       "kea": "Karnataka",
    "bangalore": "Karnataka",  "bengaluru": "Karnataka",
    "karnataka": "Karnataka",
    "psc kerala": "Kerala",    "trivandrum": "Kerala",
    "thiruvananthapuram": "Kerala", "kerala": "Kerala",
    "tnpsc": "Tamil Nadu",     "chennai": "Tamil Nadu",
    "tspsc": "Telangana",      "hyderabad": "Telangana",
    "telangana": "Telangana",
    "appsc": "Andhra Pradesh", "visakhapatnam": "Andhra Pradesh",
    "wbpsc": "West Bengal",    "wbssc": "West Bengal",
    "kolkata": "West Bengal",
    "ppsc": "Punjab",          "psssb": "Punjab",
    "chandigarh": "Punjab",    "punjab": "Punjab",
    "hpsc": "Haryana",         "hssc": "Haryana",
    "haryana": "Haryana",      "rohtak": "Haryana",
    "delhi": "Delhi",          "dsssb": "Delhi",
    "new delhi": "Delhi",
    "jpsc": "Jharkhand",       "jssc": "Jharkhand",
    "ranchi": "Jharkhand",     "jharkhand": "Jharkhand",
    "opsc": "Odisha",          "bhubaneswar": "Odisha",
    "odisha": "Odisha",
    "apsc assam": "Assam",     "slrc": "Assam",
    "guwahati": "Assam",       "assam": "Assam",
    "ukpsc": "Uttarakhand",    "dehradun": "Uttarakhand",
    "uttarakhand": "Uttarakhand",
    "hppsc": "Himachal Pradesh","shimla": "Himachal Pradesh",
    "cgpsc": "Chhattisgarh",   "raipur": "Chhattisgarh",
    "chhattisgarh": "Chhattisgarh",
    "goa": "Goa",
    "manipur": "Manipur",
    "meghalaya": "Meghalaya",  "shillong": "Meghalaya",
    "mizoram": "Mizoram",
    "nagaland": "Nagaland",    "kohima": "Nagaland",
    "sikkim": "Sikkim",        "gangtok": "Sikkim",
    "tripura": "Tripura",      "agartala": "Tripura",
    "jammu": "Jammu & Kashmir","kashmir": "Jammu & Kashmir",
    "ladakh": "Ladakh",
    "andaman": "Andaman & Nicobar",
    "lakshadweep": "Lakshadweep",
    "puducherry": "Puducherry","pondicherry": "Puducherry",
    "bihar": "Bihar",
}

def _extract_states(text: str) -> list:
    t = text.lower()
    found = list({v for k, v in STATE_MAP.items() if k in t})
    return found if found else ["all"]

def _extract_age(text: str) -> tuple:
    # Pattern 1: "18 to 35 years" / "18-40 years"
    m = re.search(r"(\d{2})\s*(?:to|–|-)\s*(\d{2})\s*(?:years?|yrs?)", text, re.IGNORECASE)
    if m:
        a, b = int(m.group(1)), int(m.group(2))
        if 14 <= a <= 35 and a < b <= 65:
            return a, b
    # Pattern 2: "Age limit: 35" / "Maximum age: 45"
    m = re.search(r"(?:max(?:imum)?\s*age|age\s*limit|upper\s*age)\s*[:\-–]?\s*(?:up\s*to\s*)?(\d{2})", text, re.IGNORECASE)
    if m:
        age = int(m.group(1))
        if 20 <= age <= 65:
            return 18, age
    # Pattern 3: "Below 35" / "not exceeding 40"
    m = re.search(r"(?:below|not\s+exceeding|under)\s+(\d{2})\s*(?:years?|yrs?)?", text, re.IGNORECASE)
    if m:
        age = int(m.group(1))
        if 20 <= age <= 65:
            return 18, age
    return 18, 40

def _extract_fee(text: str) -> tuple:
    t = text.lower()
    if re.search(r"no\s*(?:application\s*)?fee|fee[:\s]*nil|zero\s*fee|fee[:\s]*0\b|fee\s*-\s*nil|application\s*fee\s*:\s*free", t):
        return 0, 0, 0
    sc_free = bool(re.search(
        r"sc[/\s]?st[^\d]{0,40}(?:free|nil|exempt|no\s*fee|₹\s*0|rs\.?\s*0\b|waived)",
        t, re.IGNORECASE
    ))
    amounts = []
    for m in re.finditer(r"(?:rs\.?\s*|₹\s*)(\d{2,4})\b", text, re.IGNORECASE):
        v = int(m.group(1))
        if 50 <= v <= 2500:
            amounts.append(v)
    if not amounts:
        # Try "application fee: 500"
        m2 = re.search(r"application\s+fee[:\s]+(\d{2,4})", text, re.IGNORECASE)
        if m2:
            v = int(m2.group(1))
            if 50 <= v <= 2500:
                amounts = [v]
    if not amounts:
        return 0, 0, 0  # unknown fee — treat as free rather than assuming ₹100
    gen = amounts[0]
    obc = amounts[1] if len(amounts) > 1 else gen
    sc  = 0 if sc_free else (amounts[2] if len(amounts) > 2 else 0)
    return gen, obc, sc

# ════════════════════════════════════════════════════════
#  HTTP SESSION — v6: retry logic added
# ════════════════════════════════════════════════════════

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
    "Accept-Encoding": "gzip, deflate",
    "Cache-Control": "no-cache",
})
# v8: Fix connection pool warning from FreeJobAlert's many category feeds
from requests.adapters import HTTPAdapter
_adapter = HTTPAdapter(pool_connections=30, pool_maxsize=30)
SESSION.mount("https://", _adapter)
SESSION.mount("http://", _adapter)

def _fetch(url: str, timeout: int = 15, retries: int = 3) -> str | None:
    """v6: Retry with exponential backoff (1s, 2s, 4s)."""
    cached = _cache_get(url)
    if cached:
        log.debug(f"cache hit: {url[:60]}")
        return cached

    for attempt in range(retries):
        try:
            r = SESSION.get(url, timeout=timeout, verify=False, allow_redirects=True)
            r.raise_for_status()
            r.encoding = r.apparent_encoding or "utf-8"
            text = r.text
            _cache_set(url, text)
            return text
        except requests.exceptions.HTTPError as e:
            # 404/403 → don't retry
            if e.response is not None and e.response.status_code in (404, 403, 410):
                log.debug(f"HTTP {e.response.status_code}: {url[:60]}")
                return None
        except Exception as e:
            if attempt < retries - 1:
                wait = 2 ** attempt
                log.debug(f"retry {attempt+1}/{retries} after {wait}s: {url[:60]}")
                time.sleep(wait)
            else:
                log.debug(f"fetch fail: {url[:60]} | {e}")
    return None

def _soup(url: str, timeout: int = 15) -> BeautifulSoup | None:
    raw = _fetch(url, timeout)
    return BeautifulSoup(raw, "lxml") if raw else None

# ════════════════════════════════════════════════════════
#  JOB BUILDER
# ════════════════════════════════════════════════════════

def _is_job(text: str) -> bool:
    t = text.lower()
    has_job = any(w in t for w in JOB_SIGNAL_WORDS)
    is_non_job = any(w in t for w in NON_JOB_WORDS)
    return has_job and not is_non_job

def _parse_pub_date_iso(pub_date: str) -> str:
    """v9: Parse RSS pubDate to ISO 8601 string for freshness ranking."""
    if not pub_date:
        return ""
    for fmt in [
        "%a, %d %b %Y %H:%M:%S %z", "%a, %d %b %Y %H:%M:%S %Z",
        "%a, %d %b %Y %H:%M:%S", "%d %b %Y %H:%M:%S %z", "%d %b %Y",
    ]:
        try:
            dt = datetime.strptime(pub_date[:31].strip(), fmt)
            return dt.strftime("%Y-%m-%dT%H:%M:%S")
        except (ValueError, TypeError):
            continue
    m = re.match(r"(\d{4}-\d{2}-\d{2})", pub_date)
    return m.group(1) + "T00:00:00" if m else ""


def build_job(title: str, url: str, source: str, extra: str = "",
              pub_date: str = "") -> dict | None:
    if "<" in title:
        title = BeautifulSoup(f"<span>{title}</span>", "html.parser").get_text().strip()
    title = title.strip()
    title = re.sub(r"\s+", " ", title)

    # v7: Clean title before anything else
    title = clean_title(title)

    if len(title) < 8:
        return None

    if _is_private_job(title, url):
        return None

    combined = title + " " + extra

    if not _is_job(combined):
        return None

    # ── v6: date extraction priority: content > pubDate > default ──
    # 1. Try to extract from content text (most accurate)
    last_date = extract_last_date(combined)

    # 2. If not found, estimate from RSS pubDate
    if not last_date and pub_date:
        last_date = _parse_pubdate_to_lastdate(pub_date)

    # 3. Validate: skip past jobs (more than 2 days ago)
    if last_date:
        try:
            ld = datetime.strptime(last_date, "%d/%m/%Y")
            if ld < datetime.now() - timedelta(days=2):
                return None
        except ValueError:
            pass
    else:
        # Default: 30 days from now
        last_date = (datetime.now() + timedelta(days=30)).strftime("%d/%m/%Y")

    age_min, age_max = _extract_age(combined)
    fee_gen, fee_obc, fee_sc = _extract_fee(combined)

    # v7: salary, notification type, application mode
    salary_info = extract_salary(combined)
    notif_type  = detect_notification_type(combined)
    app_mode    = detect_application_mode(combined)

    return {
        "title":             title[:250],
        "department":        _extract_dept(title),
        "source":            source,
        "source_url":        url,
        "category":          detect_category(combined),
        "qualifications":    detect_qualification(combined),
        "vacancies":         extract_vacancies(combined),
        "last_date":         last_date,
        "states":            _extract_states(combined),
        "age_min":           age_min,
        "age_max":           age_max,
        "fee_general":       fee_gen,
        "fee_obc":           fee_obc,
        "fee_sc_st":         fee_sc,
        "pay_scale":         salary_info.get("pay_scale", ""),
        "pay_level":         salary_info.get("pay_level", 0),
        "grade_pay":         salary_info.get("grade_pay", 0),
        "notification_type": notif_type,
        "application_mode":  app_mode,
        "trust_score":       SOURCE_TRUST.get(source, _DEFAULT_TRUST),
        # v9: freshness tracking + description snippet
        "published_at":      _parse_pub_date_iso(pub_date),
        "description":       extra[:500].strip() if extra else "",
        "scraped_at":        datetime.now().isoformat(),
    }

# ════════════════════════════════════════════════════════
#  RSS SCRAPER
# ════════════════════════════════════════════════════════

def scrape_rss(name: str, url: str) -> list:
    raw = _fetch(url, timeout=12)
    if not raw:
        return []

    root = None
    for attempt in range(2):
        try:
            txt = raw if attempt == 0 else re.sub(
                r"&(?!(amp|lt|gt|apos|quot|#\d+);)", "&amp;", raw
            )
            root = ET.fromstring(txt.encode("utf-8"))
            break
        except ET.ParseError:
            if attempt == 1:
                log.warning(f"  ⚠ {name}: XML parse failed")
                return []

    NS_ATOM = {"a": "http://www.w3.org/2005/Atom"}
    items = root.findall(".//item") or root.findall(".//a:entry", NS_ATOM)

    jobs = []
    for item in items:
        t_el  = item.find("title")
        title = (t_el.text or "").strip() if t_el is not None else ""

        l_el  = item.find("link")
        link  = ""
        if l_el is not None:
            link = (l_el.text or l_el.get("href") or "").strip()

        d_el = (item.find("description")
                or item.find("{http://www.w3.org/2005/Atom}summary")
                or item.find("{http://www.w3.org/2005/Atom}content"))
        desc = ""
        if d_el is not None and d_el.text:
            desc = BeautifulSoup(d_el.text, "html.parser").get_text(" ", strip=True)

        pub_el = (item.find("pubDate") or item.find("published")
                  or item.find("{http://www.w3.org/2005/Atom}published")
                  or item.find("{http://www.w3.org/2005/Atom}updated"))
        pub_date = (pub_el.text or "").strip() if pub_el is not None else ""

        job = build_job(title, link, name, desc, pub_date)
        if job:
            jobs.append(job)

    return jobs

# ════════════════════════════════════════════════════════
#  DIRECT HTML SCRAPERS
# ════════════════════════════════════════════════════════

def _scrape_generic(url: str, source: str, base_url: str, css_list: list,
                    limit: int = 80) -> list:
    soup = _soup(url)
    if not soup:
        return []

    jobs = []
    seen_hrefs = set()

    for css in css_list:
        tags = soup.select(css)
        if not tags:
            continue
        for a in tags[:limit]:
            href  = a.get("href", "").strip()
            title = a.get_text(strip=True)

            if not href or href in seen_hrefs or len(title) < 8:
                continue
            seen_hrefs.add(href)

            if href.startswith("/"):
                href = base_url.rstrip("/") + href
            elif not href.startswith("http"):
                continue

            parent = a.find_parent(["tr", "li", "article", "div", "td"])
            extra  = parent.get_text(" ", strip=True) if parent else ""

            job = build_job(title, href, source, extra)
            if job:
                jobs.append(job)
        if jobs:
            break

    return jobs


def scrape_sarkariresult() -> list:
    soup = _soup(DIRECT_SOURCES["sarkariresult"])
    if not soup:
        return []
    jobs = []
    seen = set()
    for a in soup.find_all("a", href=True)[:200]:
        href  = a.get("href", "").strip()
        title = a.get_text(strip=True)
        if not href or href in seen or len(title) < 8:
            continue
        if not _is_job(title):
            continue
        if any(skip in href for skip in ["facebook","twitter","youtube",
                                          "whatsapp","telegram","#","javascript"]):
            continue
        seen.add(href)
        if not href.startswith("http"):
            href = "https://www.sarkariresult.com" + href
        row = a.find_parent("tr")
        extra = row.get_text(" ") if row else ""
        job = build_job(title, href, "SarkariResult", extra)
        if job:
            jobs.append(job)
    return jobs


def scrape_recruitmentresult() -> list:
    return _scrape_generic(
        DIRECT_SOURCES["recruitresult"], "RecruitmentResult",
        "https://recruitmentresult.com",
        ["article h2 a", "h2.entry-title a", "h3.entry-title a",
         ".post-title a", ".entry-title a"],
    )


def scrape_linkingsky() -> list:
    return _scrape_generic(
        DIRECT_SOURCES["linkingsky"], "LinkingSky",
        "https://linkingsky.com",
        ["h3 a[href]", "h2 a[href]", "td a[href]",
         ".job-title a", ".post-title a", "li a[href]"],
    )


def scrape_mysarkarinaukri() -> list:
    soup = _soup(DIRECT_SOURCES["mysarkarinaukri"])
    if not soup:
        return []
    jobs = []
    seen = set()
    for a in soup.find_all("a", href=True)[:200]:
        href  = a.get("href", "").strip()
        title = a.get_text(strip=True)
        if not href or href in seen or len(title) < 8:
            continue
        if not _is_job(title):
            continue
        if any(skip in href for skip in ["facebook","twitter","youtube","whatsapp",
                                          "telegram","#","javascript","mailto",
                                          "category","tag","page"]):
            continue
        if not any(kw in href.lower() for kw in ["recruitment","vacancy","job",
                                                   "2026","2025","notification"]):
            continue
        seen.add(href)
        if not href.startswith("http"):
            href = "https://www.mysarkarinaukri.com" + href
        parent = a.find_parent(["article","li","div","tr"])
        extra  = parent.get_text(" ") if parent else ""
        job = build_job(title, href, "MySarkariNaukri", extra)
        if job:
            jobs.append(job)
    return jobs


def scrape_freejobalert_direct() -> list:
    return _scrape_generic(
        DIRECT_SOURCES["freejobalert_dir"], "FreeJobAlert",
        "https://www.freejobalert.com",
        # v6: Added more CSS selectors for FreeJobAlert's actual layout
        ["table.maintable a[href]",
         "table a[href*='/articles/']",
         "table a[href*='freejobalert']",
         "td a[href*='freejobalert']",
         "h2 a[href]", "h3 a[href]",
         ".entry-title a",
         "a[href*='/articles/']"],
        limit=100
    )


def scrape_jobalertshub() -> list:
    return _scrape_generic(
        DIRECT_SOURCES["jobalertshub_dir"], "JobAlertsHub",
        "https://jobalertshub.com",
        ["h2.entry-title a", "h3.entry-title a", ".post-title a",
         "article h2 a", "article h3 a"],
        limit=60
    )


def scrape_freshersworld() -> list:
    """v8: Freshersworld government jobs page"""
    return _scrape_generic(
        DIRECT_SOURCES["freshersworld_dir"], "freshersworld_dir",
        "https://www.freshersworld.com",
        ["h2.job-title a", "h3.job-title a", ".job-listing h2 a",
         ".job-listing h3 a", "article h2 a", "article h3 a",
         "h2 a[href*='government']", "a[href*='/jobs/']"],
        limit=80
    )


def scrape_ndtv_jobs() -> list:
    """v8: NDTV Jobs government section"""
    return _scrape_generic(
        DIRECT_SOURCES["ndtv_jobs"], "ndtv_jobs",
        "https://www.ndtv.com",
        ["h2.story__headline a", "h3.story__headline a",
         ".story-card__headline a", ".story__headline a",
         "a.story__link", "h2 a[href*='jobs']"],
        limit=60
    )


def scrape_jagran_jobs() -> list:
    """v8: Jagran Jobs government section"""
    return _scrape_generic(
        DIRECT_SOURCES["jagran_jobs"], "jagran_jobs",
        "https://jobs.jagran.com",
        ["h2 a", "h3 a", ".article-title a", ".story-title a",
         "a[href*='government']", "a[href*='sarkari']"],
        limit=60
    )

# ════════════════════════════════════════════════════════
#  DEDUPLICATION — v6: same as v5 (already good)
# ════════════════════════════════════════════════════════

_NOISE_RE = re.compile(
    r"\b(recruitment|vacancy|vacancies|notification|advt|advertisement|"
    r"apply|online|form|latest|2025|2026|2027|posts?|jobs?|sarkari|naukri|"
    r"result|admit|card|answer|key|syllabus|exam|out|update|new|"
    r"direct|link|official|check|details?|here|now|active|open)\b",
    re.IGNORECASE,
)

def _fp(title: str) -> str:
    t = _NOISE_RE.sub("", title).lower()
    t = re.sub(r"[^a-z0-9\s]", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t[:60]

def _url_fp(url: str) -> str:
    try:
        from urllib.parse import urlparse
        p = urlparse(url)
        parts = [x for x in p.path.split("/") if x][:2]
        return p.netloc + "/" + "/".join(parts)
    except Exception:
        return url[:80]

def _edit_distance_approx(a: str, b: str) -> float:
    """
    v7: Very fast approximate similarity using token overlap.
    Returns 0.0 (completely different) to 1.0 (identical).
    """
    if not a or not b:
        return 0.0
    sa = set(a.split())
    sb = set(b.split())
    if not sa or not sb:
        return 0.0
    intersection = len(sa & sb)
    union        = len(sa | sb)
    return intersection / union  # Jaccard similarity

def deduplicate(jobs: list) -> list:
    """
    v7: Two-pass dedup:
      Pass 1 — exact fingerprint (fast, same as v6)
      Pass 2 — fuzzy Jaccard similarity >= 0.75 (catches near-dupes)
    """
    seen_title: set   = set()
    seen_url:   set   = set()
    fp_list:    list  = []   # for fuzzy pass
    unique:     list  = []

    for j in jobs:
        tfp = _fp(j["title"])
        ufp = _url_fp(j["source_url"])

        if len(tfp) <= 4 or tfp in seen_title or ufp in seen_url:
            continue

        # v7 fuzzy pass — skip if very similar to existing title
        is_near_dupe = False
        if len(tfp) > 10:
            for existing_fp in fp_list[-500:]:   # v9: check recent 500 (was 200)
                sim = _edit_distance_approx(tfp, existing_fp)
                if sim >= 0.75:
                    is_near_dupe = True
                    break
        if is_near_dupe:
            continue

        seen_title.add(tfp)
        seen_url.add(ufp)
        fp_list.append(tfp)
        unique.append(j)

    return unique

# ════════════════════════════════════════════════════════
#  MAIN RUNNER — v6: 16 workers, dead-source tracking
# ════════════════════════════════════════════════════════

def run_all() -> list:
    t0 = time.time()

    log.info("╔══════════════════════════════════════════╗")
    log.info("║   JobMitra Scraper v9  Starting          ║")
    log.info(f"║   {len(RSS_SOURCES)} RSS + {len(DIRECT_SOURCES)} Direct sources          ║")
    log.info("╚══════════════════════════════════════════╝")

    all_jobs: list = []

    # ── Phase 1: RSS in parallel (16 workers) ───────────
    log.info("\n📡 Phase 1 — RSS Feeds (parallel, 16 workers)")

    rss_results: dict = {}
    dead_sources: list = []

    def _rss_task(item):
        name, url = item
        try:
            jobs = scrape_rss(name, url)
            return name, jobs
        except Exception as e:
            log.warning(f"  ❌ {name:<22} failed: {e}")
            return name, []

    with ThreadPoolExecutor(max_workers=32) as pool:  # v9: 24 → 32
        futures = {pool.submit(_rss_task, item): item[0]
                   for item in RSS_SOURCES.items()}
        for f in as_completed(futures):
            name, jobs = f.result()
            rss_results[name] = jobs

    for name in RSS_SOURCES:
        jobs = rss_results.get(name, [])
        status = "✅" if jobs else "⚪"
        log.info(f"  {status} {name:<24} {len(jobs):>3} jobs")
        all_jobs.extend(jobs)
        if not jobs:
            dead_sources.append(name)

    # ── Phase 2: Direct scrapers in parallel ────────────
    log.info("\n🌐 Phase 2 — Direct Scrapers (parallel)")

    direct_scrapers = [
        ("SarkariResult",    scrape_sarkariresult),
        ("RecruitmentResult",scrape_recruitmentresult),
        ("LinkingSky",       scrape_linkingsky),
        ("MySarkariNaukri",  scrape_mysarkarinaukri),
        ("FreeJobAlert",     scrape_freejobalert_direct),
        ("JobAlertsHub",     scrape_jobalertshub),
        ("FreshersWorld",    scrape_freshersworld),
        ("NDTVJobs",         scrape_ndtv_jobs),
        ("JagranJobs",       scrape_jagran_jobs),
    ]

    def _direct_task(item):
        name, fn = item
        try:
            return name, fn()
        except Exception as e:
            log.warning(f"  ❌ {name:<22} failed: {e}")
            return name, []

    with ThreadPoolExecutor(max_workers=12) as pool:  # v9: 9 → 12
        futures = {pool.submit(_direct_task, item): item[0]
                   for item in direct_scrapers}
        for f in as_completed(futures):
            name, jobs = f.result()
            status = "✅" if jobs else "⚪"
            log.info(f"  {status} {name:<24} {len(jobs):>3} jobs")
            all_jobs.extend(jobs)

    # ── Phase 3: Dedup + sort ────────────────────────────
    raw_count = len(all_jobs)
    unique    = deduplicate(all_jobs)

    def _sort_key(j):
        try:
            days = (datetime.strptime(j["last_date"], "%d/%m/%Y") - datetime.now()).days
        except Exception:
            days = 30
        vac_score = -(j.get("vacancies") or 0)
        trust     = -(j.get("trust_score") or _DEFAULT_TRUST)
        # v9: freshness — how many days ago was this published (lower = newer)
        pub_str = j.get("published_at", "")
        if pub_str:
            try:
                pub_dt = datetime.strptime(pub_str[:19], "%Y-%m-%dT%H:%M:%S")
                freshness = (datetime.now() - pub_dt).days
            except Exception:
                freshness = 30
        else:
            freshness = 30
        # Sort: urgent deadline → newer publication → high vacancy → trusted source
        return (max(days, 0), freshness, vac_score, trust)

    unique.sort(key=_sort_key)

    # ── Phase 4: Stats ────────────────────────────────────
    elapsed = round(time.time() - t0, 1)
    cats: dict = {}
    for j in unique:
        cats[j["category"]] = cats.get(j["category"], 0) + 1

    # v7: extra stats
    online_count   = sum(1 for j in unique if j.get("application_mode") == "online")
    offline_count  = sum(1 for j in unique if j.get("application_mode") == "offline")
    walkin_count   = sum(1 for j in unique if j.get("application_mode") == "walk-in")
    extended_count = sum(1 for j in unique if j.get("notification_type") == "extended")
    reopen_count   = sum(1 for j in unique if j.get("notification_type") == "re-open")
    salary_count   = sum(1 for j in unique if j.get("pay_scale"))

    log.info("\n" + "═" * 58)
    log.info(f"  ✅  {raw_count} raw → {len(unique)} unique jobs  ({elapsed}s)")
    log.info("─" * 58)
    log.info("  Category breakdown:")
    for cat, n in sorted(cats.items(), key=lambda x: -x[1]):
        bar = "█" * min(n // 2, 25)
        pct = round(n * 100 / len(unique)) if unique else 0
        log.info(f"    {cat:<18} {bar:<26} {n:>4} ({pct}%)")
    log.info("─" * 58)
    log.info(f"  Apply mode:  🌐 online={online_count}  📮 offline={offline_count}  🚶 walk-in={walkin_count}")
    log.info(f"  Notif type:  📅 extended={extended_count}  🔄 re-open={reopen_count}")
    log.info(f"  Salary info: 💰 {salary_count} jobs have pay scale extracted")
    log.info("═" * 58)

    # ── v6: Dead source report ────────────────────────────
    if dead_sources:
        log.info(f"\n⚠  Dead/empty RSS sources ({len(dead_sources)}):")
        for ds in dead_sources:
            log.info(f"    — {ds}  [{RSS_SOURCES[ds]}]")

    others_pct = round(cats.get("others", 0) * 100 / len(unique)) if unique else 0
    if others_pct > 15:
        log.warning(f"\n  ⚠ 'others' is {others_pct}% — add more category keywords")

    return unique


# ════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════

if __name__ == "__main__":
    jobs = run_all()

    out = "scraped_jobs.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(jobs, f, ensure_ascii=False, indent=2)

    print(f"\n✅ {len(jobs)} jobs saved → {out}")

    if jobs:
        print("\n📋 Top 10 most urgent jobs:")
        print("─" * 85)
        for j in jobs[:10]:
            vac   = f"{j['vacancies']:,}" if j["vacancies"] else "?"
            qual  = ", ".join(j["qualifications"][:2])
            pay   = f"  💰 {j['pay_scale']}" if j.get("pay_scale") else ""
            mode  = {"online": "🌐", "offline": "📮", "walk-in": "🚶"}.get(j.get("application_mode",""), "")
            ntype = {"extended": " [EXTENDED]", "re-open": " [RE-OPEN]"}.get(j.get("notification_type",""), "")
            print(f"[{j['category'].upper():<14}] {j['title'][:52]}{ntype}")
            print(f"{'':>17} 📅 {j['last_date']}  |  👥 {vac} posts  |  🎓 {qual}{pay}  {mode}")
            print(f"{'':>17} 🔗 {j['source_url'][:60]}")
            print()