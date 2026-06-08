"""
JobMitra - FastAPI Backend
Deploy on Cloud Run (asia-south1)
DB: Turso (libsql cloud) — persistent across deploys
"""

from fastapi import FastAPI, HTTPException, Query, Body, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from pydantic import BaseModel, Field
from typing import Optional
import hmac
import json
import os
import base64
import hashlib
import logging
import requests as _requests
from datetime import datetime, timedelta

# Lazy import — AI features disabled gracefully if gemini_service isn't available
try:
    import gemini_service as _gemini
    _gemini_available = True
except ImportError:
    _gemini = None  # type: ignore
    _gemini_available = False

# Cloud Run auto-detects single-line JSON written to stdout/stderr and parses
# severity/labels/trace fields. Plain text logs all show up as severity=DEFAULT
# in Cloud Logging, which makes filtering and error alerts impossible. The
# formatter below outputs the minimal Cloud-Logging-compatible envelope.
class _CloudJsonFormatter(logging.Formatter):
    _LEVEL_TO_SEVERITY = {
        "DEBUG": "DEBUG", "INFO": "INFO", "WARNING": "WARNING",
        "ERROR": "ERROR", "CRITICAL": "CRITICAL",
    }

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "severity": self._LEVEL_TO_SEVERITY.get(record.levelname, "DEFAULT"),
            "message": record.getMessage(),
            "logger": record.name,
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        # Allow callers to attach structured fields via `extra={"key": ...}`.
        for k, v in record.__dict__.items():
            if k in ("args", "msg", "exc_info", "exc_text", "name", "levelname",
                    "levelno", "pathname", "filename", "module", "lineno",
                    "funcName", "created", "msecs", "relativeCreated", "thread",
                    "threadName", "processName", "process", "stack_info",
                    "asctime", "message"):
                continue
            try:
                json.dumps(v)
                payload[k] = v
            except (TypeError, ValueError):
                payload[k] = str(v)
        return json.dumps(payload, ensure_ascii=False)


_handler = logging.StreamHandler()
_handler.setFormatter(_CloudJsonFormatter())
logging.basicConfig(level=logging.INFO, handlers=[_handler], force=True)
log = logging.getLogger("jobmitra")


def _safe_json_loads(raw, fallback):
    """Decode a JSON column safely. Old/corrupt rows return the fallback rather
    than crash the request handler."""
    if not raw:
        return fallback
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        return fallback

app = FastAPI(title="JobMitra API", version="1.0.0")

# CORS: the Android app uses native http client (no preflight needed), so the
# only browser-origin that needs allowance is the legacy Render host during
# transition. Local dev origins removed for prod — a malicious local web app
# on localhost:3000 could otherwise piggy-back on user creds.
_ALLOWED_ORIGINS = [
    "https://jobmitra-api.onrender.com",
]
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


# Admin auth: fail-closed. If SCRAPER_SECRET env is missing or matches the
# leaked legacy value, every admin endpoint rejects — instead of silently
# accepting requests with the well-known fallback.
_LEGACY_LEAKED_SECRET = "jobmitra_secret_2024"

def require_admin(secret: str) -> None:
    expected = os.getenv("SCRAPER_SECRET")
    if not expected:
        # SCRAPER_SECRET must be supplied via env (Secret Manager on Cloud Run).
        # Return the same 403 as a wrong-secret reject so an attacker can't
        # distinguish "secret missing in this environment" from "wrong secret",
        # which would otherwise leak deployment state.
        log.error("SCRAPER_SECRET env not configured on this instance")
        raise HTTPException(status_code=403, detail="Unauthorized")
    # compare_digest avoids leaking the secret length / shared-prefix via the
    # response timing of a naive `==`. Equal-length compare is safe on bytes.
    if not secret or not hmac.compare_digest(secret.encode("utf-8"), expected.encode("utf-8")):
        raise HTTPException(status_code=403, detail="Unauthorized")

# ─────────────────────────────────────────
# TURSO ADAPTER  (drop-in sqlite3 replacement)
# ─────────────────────────────────────────

class _Row(dict):
    """sqlite3.Row-compatible dict — supports both name and int-index access"""
    def __getitem__(self, key):
        if isinstance(key, int):
            return list(self.values())[key]
        return super().__getitem__(key)


def _parse_val(v):
    """Convert Turso typed value → Python native type"""
    if v is None or v.get("type") == "null":
        return None
    t, val = v.get("type"), v.get("value")
    if t == "integer":
        return int(val) if val is not None else None
    if t == "float":
        return float(val) if val is not None else None
    return val  # text / blob


def _arg(v):
    """Convert Python value → Turso typed arg"""
    if v is None:
        return {"type": "null", "value": None}
    if isinstance(v, bool):
        return {"type": "integer", "value": str(int(v))}
    if isinstance(v, int):
        return {"type": "integer", "value": str(v)}
    if isinstance(v, float):
        return {"type": "float", "value": str(v)}
    return {"type": "text", "value": str(v)}


# Module-level requests.Session backed by an HTTPAdapter that keeps a pool of
# TCP+TLS connections to Turso. Before this, every TursoAdapter() instance
# called the bare `requests.post()` which builds a fresh socket + TLS handshake
# per query — ~30-80ms wasted per RT on top of Turso's own latency. The Session
# is thread-safe for send/recv; uvicorn's sync handlers can share it freely.
_TURSO_SESSION = _requests.Session()
_TURSO_SESSION.mount(
    "https://",
    _requests.adapters.HTTPAdapter(
        pool_connections=20,  # distinct hostnames cached — we only hit one
        pool_maxsize=50,      # concurrent sockets per host — Cloud Run cap is well below this
        max_retries=0,        # retries are app's job, not transport's
    ),
)


class TursoAdapter:
    """
    Thin HTTP wrapper around Turso's /v2/pipeline API.
    Mimics sqlite3 connection interface used in this codebase.
    """
    def __init__(self):
        url = os.getenv("TURSO_URL", "").rstrip("/")
        # Accept both libsql:// and https://
        self._base = url.replace("libsql://", "https://")
        self._token = os.getenv("TURSO_TOKEN", "")
        self._last_result = None

    def _run(self, statements: list) -> list:
        pipeline = [{"type": "execute", "stmt": s} for s in statements]
        pipeline.append({"type": "close"})
        r = _TURSO_SESSION.post(
            f"{self._base}/v2/pipeline",
            headers={
                "Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json",
            },
            json={"requests": pipeline},
            timeout=15,
        )
        r.raise_for_status()
        return r.json()["results"]

    def execute(self, sql: str, params=()):
        stmt = {"sql": sql, "args": [_arg(p) for p in params]}
        results = self._run([stmt])
        self._last_result = results[0]["response"]["result"]
        return self

    def executescript(self, sql: str):
        stmts = [
            {"sql": s.strip()}
            for s in sql.split(";")
            if s.strip() and not s.strip().startswith("--")
        ]
        if stmts:
            self._run(stmts)
        return self

    def fetchone(self):
        if not self._last_result or not self._last_result.get("rows"):
            return None
        cols = [c["name"] for c in self._last_result["cols"]]
        vals = [_parse_val(v) for v in self._last_result["rows"][0]]
        return _Row(zip(cols, vals))

    def fetchall(self):
        if not self._last_result or not self._last_result.get("rows"):
            return []
        cols = [c["name"] for c in self._last_result["cols"]]
        return [
            _Row(zip(cols, [_parse_val(v) for v in row]))
            for row in self._last_result["rows"]
        ]

    @property
    def lastrowid(self):
        if self._last_result:
            lid = self._last_result.get("last_insert_rowid")
            return int(lid) if lid is not None else None
        return None

    def commit(self): pass   # Turso auto-commits each statement
    def close(self):  pass   # HTTP is stateless
    def __enter__(self): return self
    def __exit__(self, *a): pass


def get_db() -> TursoAdapter:
    return TursoAdapter()


# ─────────────────────────────────────────
# DATABASE SETUP
# ─────────────────────────────────────────
def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS jobs (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            title            TEXT NOT NULL,
            department       TEXT,
            source           TEXT,
            source_url       TEXT,
            category         TEXT,
            qualifications   TEXT,
            vacancies        INTEGER DEFAULT 0,
            last_date        TEXT,
            states           TEXT,
            age_min          INTEGER DEFAULT 18,
            age_max          INTEGER DEFAULT 40,
            fee_general      INTEGER DEFAULT 0,
            fee_obc          INTEGER DEFAULT 0,
            fee_sc_st        INTEGER DEFAULT 0,
            pay_scale        TEXT    DEFAULT '',
            pay_level        INTEGER DEFAULT 0,
            grade_pay        INTEGER DEFAULT 0,
            notification_type TEXT   DEFAULT 'new',
            application_mode TEXT    DEFAULT 'online',
            trust_score      INTEGER DEFAULT 5,
            published_at     TEXT    DEFAULT '',
            description      TEXT    DEFAULT '',
            documents_needed TEXT    DEFAULT NULL,
            scraped_at       TEXT,
            is_active        INTEGER DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS users (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            fcm_token       TEXT UNIQUE,
            state           TEXT,
            education       TEXT,
            category        TEXT,
            age             INTEGER,
            job_types       TEXT,
            language        TEXT DEFAULT 'hinglish',
            created_at      TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS saved_jobs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER,
            job_id      INTEGER,
            status      TEXT DEFAULT 'saved',
            saved_at    TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id),
            FOREIGN KEY(job_id)  REFERENCES jobs(id)
        );

        CREATE TABLE IF NOT EXISTS current_affairs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            summary     TEXT DEFAULT '',
            category    TEXT DEFAULT 'national',
            pub_date    TEXT DEFAULT '',
            source_name TEXT DEFAULT '',
            source_url  TEXT UNIQUE,
            scraped_at  TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS mock_packs (
            pack_id      TEXT PRIMARY KEY,
            title        TEXT NOT NULL,
            subtitle     TEXT DEFAULT '',
            emoji        TEXT DEFAULT '📝',
            color_hex    TEXT DEFAULT '#1565C0',
            is_pyq       INTEGER DEFAULT 0,
            sort_order   INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS questions (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            type          TEXT NOT NULL DEFAULT 'quiz',
            pack_id       TEXT DEFAULT NULL,
            set_index     INTEGER DEFAULT NULL,
            question      TEXT NOT NULL,
            option_a      TEXT NOT NULL,
            option_b      TEXT NOT NULL,
            option_c      TEXT NOT NULL,
            option_d      TEXT NOT NULL,
            correct       INTEGER NOT NULL,
            topic         TEXT DEFAULT '',
            explanation   TEXT DEFAULT '',
            sort_order    INTEGER DEFAULT 0,
            question_hash TEXT DEFAULT NULL
        );

        CREATE TABLE IF NOT EXISTS announcements (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            type          TEXT NOT NULL,       -- admit_card | result | answer_key | cutoff | syllabus | exam_date
            title         TEXT NOT NULL,
            exam_name     TEXT DEFAULT '',
            organisation  TEXT DEFAULT '',
            release_date  TEXT DEFAULT '',
            source        TEXT DEFAULT '',
            source_url    TEXT UNIQUE,
            description   TEXT DEFAULT '',
            scraped_at    TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS exam_calendar (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id       TEXT UNIQUE NOT NULL,
            name          TEXT NOT NULL,
            category      TEXT DEFAULT 'other',   -- upsc/ssc/banking/railway/state/defence/other
            emoji         TEXT DEFAULT '📅',
            notif_date    TEXT DEFAULT '',
            last_date     TEXT DEFAULT '',
            exam_date     TEXT DEFAULT '',
            is_tentative  INTEGER DEFAULT 0,
            official_site TEXT DEFAULT '',
            updated_at    TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS dept_profiles (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            dept_id       TEXT UNIQUE NOT NULL,
            name          TEXT NOT NULL,
            full_name     TEXT DEFAULT '',
            emoji         TEXT DEFAULT '🏛️',
            category      TEXT DEFAULT 'central',  -- central/defence/banking/railway/research/state
            color_hex     TEXT DEFAULT '#1565C0',
            ministry      TEXT DEFAULT '',
            hq            TEXT DEFAULT '',
            about         TEXT DEFAULT '',
            roles         TEXT DEFAULT '[]',        -- JSON array
            salary        TEXT DEFAULT '',
            work_life     TEXT DEFAULT '',
            perks         TEXT DEFAULT '[]',        -- JSON array
            promotion_path TEXT DEFAULT '',
            best_for      TEXT DEFAULT '',
            rating        INTEGER DEFAULT 3,
            updated_at    TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_jobs_category  ON jobs(category);
        CREATE INDEX IF NOT EXISTS idx_jobs_active    ON jobs(is_active);
        CREATE INDEX IF NOT EXISTS idx_saved_user     ON saved_jobs(user_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_jobs_url ON jobs(source_url);
        CREATE INDEX IF NOT EXISTS idx_ca_date        ON current_affairs(pub_date);
        CREATE INDEX IF NOT EXISTS idx_ca_category    ON current_affairs(category);
        CREATE INDEX IF NOT EXISTS idx_q_type         ON questions(type);
        CREATE INDEX IF NOT EXISTS idx_q_pack         ON questions(pack_id);
        CREATE INDEX IF NOT EXISTS idx_q_set          ON questions(set_index);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_q_hash  ON questions(question_hash);
        CREATE INDEX IF NOT EXISTS idx_ann_type       ON announcements(type);
        CREATE INDEX IF NOT EXISTS idx_ann_scraped    ON announcements(scraped_at)
    """)

init_db()

# ── Schema migration ──────────────────────────────────────
# Persistent marker so we don't re-run ALTERs on every cold start.
# Bump SCHEMA_VERSION whenever new ALTERs are added.
SCHEMA_VERSION = 5
_MIGRATIONS = [
    "ALTER TABLE jobs ADD COLUMN pay_scale TEXT DEFAULT ''",
    "ALTER TABLE jobs ADD COLUMN pay_level INTEGER DEFAULT 0",
    "ALTER TABLE jobs ADD COLUMN grade_pay INTEGER DEFAULT 0",
    "ALTER TABLE jobs ADD COLUMN notification_type TEXT DEFAULT 'new'",
    "ALTER TABLE jobs ADD COLUMN application_mode TEXT DEFAULT 'online'",
    "ALTER TABLE jobs ADD COLUMN trust_score INTEGER DEFAULT 5",
    "ALTER TABLE jobs ADD COLUMN published_at TEXT DEFAULT ''",
    "ALTER TABLE jobs ADD COLUMN description TEXT DEFAULT ''",
    "ALTER TABLE jobs ADD COLUMN documents_needed TEXT DEFAULT NULL",
    "ALTER TABLE questions ADD COLUMN question_hash TEXT DEFAULT NULL",
    "ALTER TABLE questions ADD COLUMN explanation TEXT DEFAULT ''",
    # v2: stable client-generated UUID — primary identity, decoupled from FCM token
    "ALTER TABLE users ADD COLUMN install_id TEXT DEFAULT NULL",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_install_id ON users(install_id)",
    # v3: server-side alert rules so push fires on scrape, not on app open
    """CREATE TABLE IF NOT EXISTS user_alert_rules (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        rule_id     TEXT NOT NULL,
        keyword     TEXT DEFAULT '',
        state       TEXT DEFAULT '',
        category    TEXT DEFAULT '',
        free_only   INTEGER DEFAULT 0,
        is_active   INTEGER DEFAULT 1,
        created_at  TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, rule_id)
    )""",
    "CREATE INDEX IF NOT EXISTS idx_alert_rules_user ON user_alert_rules(user_id)",
    "CREATE INDEX IF NOT EXISTS idx_alert_rules_active ON user_alert_rules(is_active)",
    # v4: deduplicate saved_jobs and enforce one row per (user, job).
    # Manual upsert logic remained correct, but a concurrent double-tap on
    # Save could insert two rows before either UPDATE landed.
    """DELETE FROM saved_jobs WHERE id NOT IN (
        SELECT MAX(id) FROM saved_jobs GROUP BY user_id, job_id
    )""",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_saved_uniq ON saved_jobs(user_id, job_id)",
    # v5: feed and admin endpoints all do `ORDER BY scraped_at DESC LIMIT N`,
    # which was a full-table scan + filesort because no index covered it.
    "CREATE INDEX IF NOT EXISTS idx_jobs_scraped_at ON jobs(scraped_at DESC)",
]

def _maybe_run_migrations():
    """Skip ALTER TABLEs after first successful run. Saves ~11 RTs per cold start."""
    conn = get_db()
    try:
        conn.execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY)")
        conn.execute("SELECT version FROM schema_version ORDER BY version DESC LIMIT 1")
        row = conn.fetchone()
        current = row["version"] if row else 0
        if current >= SCHEMA_VERSION:
            return
    except Exception:
        pass  # fall through and try migrations
    for _sql in _MIGRATIONS:
        try:
            get_db().execute(_sql)
        except Exception:
            pass
    try:
        get_db().execute("INSERT OR REPLACE INTO schema_version (version) VALUES (?)", (SCHEMA_VERSION,))
    except Exception:
        pass

_maybe_run_migrations()

# ─────────────────────────────────────────
# MODELS
# ─────────────────────────────────────────
class UserProfile(BaseModel):
    # Length caps are defensive: a malicious client (or a buggy build) could
    # otherwise POST megabyte-sized strings, bloating Turso rows and slowing
    # every subsequent feed query that joins this table.
    fcm_token:  str = Field("",  max_length=512)
    state:      str = Field(...,  max_length=64)
    education:  str = Field(...,  max_length=32)
    category:   str = Field(...,  max_length=16)
    age:        int = Field(...,  ge=13, le=80)
    job_types:  list[str] = Field(default_factory=list, max_length=40)
    language:   str = Field("hinglish", max_length=16)
    install_id: Optional[str] = Field(None, max_length=64)

class SaveJobRequest(BaseModel):
    user_id: int
    job_id:  int
    status:  str = "saved"

class QuestionIn(BaseModel):
    type:      str = "quiz"        # "quiz" or "mock"
    pack_id:   Optional[str] = None
    set_index: Optional[int] = None
    question:  str
    option_a:  str
    option_b:  str
    option_c:  str
    option_d:  str
    correct:   int                 # 0-3
    topic:     str = ""
    sort_order: int = 0

class MockPackIn(BaseModel):
    pack_id:    str
    title:      str
    subtitle:   str = ""
    emoji:      str = "📝"
    color_hex:  str = "#1565C0"
    is_pyq:     bool = False
    sort_order: int = 0

# ─────────────────────────────────────────
# EDUCATION HIERARCHY
# ─────────────────────────────────────────
EDUCATION_LEVELS = {
    "8th": 1, "10th": 2, "12th": 3,
    "diploma": 3, "graduate": 4, "postgraduate": 5
}

def user_qualifies(user_education: str, job_qualifications: list) -> bool:
    if not job_qualifications or "all" in job_qualifications:
        return True
    user_level = EDUCATION_LEVELS.get(user_education, 4)
    for qual in job_qualifications:
        required_level = EDUCATION_LEVELS.get(qual, 4)
        if user_level >= required_level:
            return True
    return False

# ─────────────────────────────────────────
# FIREBASE PUSH NOTIFICATIONS
# ─────────────────────────────────────────

def _get_fcm_access_token() -> Optional[str]:
    """
    Get OAuth2 access token for FCM v1 API. Two strategies:

      1) FIREBASE_CREDENTIALS_B64 env var (base64 service account JSON) — legacy
      2) Application Default Credentials (Cloud Run compute SA with role
         roles/firebasecloudmessaging.admin) — preferred on Google infra

    Returns None when neither strategy works.
    """
    import google.auth.transport.requests as ga_requests
    scopes = ["https://www.googleapis.com/auth/firebase.messaging"]

    creds_b64 = os.getenv("FIREBASE_CREDENTIALS_B64", "")
    if creds_b64:
        try:
            creds_json = json.loads(base64.b64decode(creds_b64).decode())
            import google.oauth2.service_account as sa
            credentials = sa.Credentials.from_service_account_info(creds_json, scopes=scopes)
            credentials.refresh(ga_requests.Request())
            return credentials.token
        except Exception as e:
            log.warning(f"FCM (B64) token error: {e}")

    # ADC fallback — works on Cloud Run when the SA has Firebase Messaging access.
    try:
        import google.auth
        credentials, _ = google.auth.default(scopes=scopes)
        credentials.refresh(ga_requests.Request())
        return credentials.token
    except Exception as e:
        log.warning(f"FCM (ADC) token error: {e}")
        return None


def send_fcm_to_topic(topic: str, title: str, body: str, data: dict = None) -> bool:
    """Send one FCM v1 message to a topic. Returns True on HTTP 200."""
    access_token = _get_fcm_access_token()
    if not access_token:
        return False
    project_id = os.getenv("FIREBASE_PROJECT_ID", "jobmitra-17db0")
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    payload = {
        "message": {
            "topic": topic,
            "notification": {"title": title, "body": body},
            "android": {
                "notification": {
                    "channel_id": "new_jobs_channel",
                    "sound": "default",
                }
            },
            "data": {k: str(v) for k, v in (data or {}).items()},
        }
    }
    try:
        r = _requests.post(
            url,
            headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
            json=payload,
            timeout=10,
        )
        if r.status_code != 200:
            log.warning(f"FCM topic send {r.status_code}: {r.text[:200]}")
        return r.status_code == 200
    except Exception as e:
        log.warning(f"FCM topic error: {e}")
        return False


def send_fcm_to_tokens(tokens: list[str], title: str, body: str, data: dict = None) -> int:
    """
    Send FCM notification to a list of FCM tokens via HTTP v1 API.
    Returns number of successful sends.

    Uses a ThreadPoolExecutor so 600 tokens take ~6 seconds instead of 60.
    Serial sends would blow past Cloud Run's 60s request timeout on
    /admin/scrape once we cross ~500 users.
    """
    if not tokens:
        return 0
    access_token = _get_fcm_access_token()
    if not access_token:
        return 0

    project_id = os.getenv("FIREBASE_PROJECT_ID", "jobmitra-17db0")
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    data_payload = {k: str(v) for k, v in (data or {}).items()}

    # FCM returns these when token is permanently dead — we strip such tokens
    # from the DB so the next scrape doesn't keep fanning out to phantoms.
    DEAD_TOKEN_ERRORS = {
        "UNREGISTERED",
        "INVALID_ARGUMENT",
        "SENDER_ID_MISMATCH",
        "NOT_FOUND",
    }
    dead_tokens: list[str] = []

    def _send(token: str) -> bool:
        if not token or token == "test":
            return False
        payload = {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "android": {
                    "notification": {
                        "channel_id": "new_jobs_channel",
                        "sound": "default",
                    }
                },
                "data": data_payload,
            }
        }
        try:
            r = _requests.post(url, headers=headers, json=payload, timeout=10)
            if r.status_code == 200:
                return True
            # Inspect FCM v1 error payload for dead-token signals (404/400 + error code)
            if r.status_code in (400, 404):
                try:
                    err = r.json().get("error", {})
                    details = err.get("details", []) or []
                    for d in details:
                        if d.get("errorCode") in DEAD_TOKEN_ERRORS:
                            dead_tokens.append(token)
                            break
                    else:
                        if err.get("status") in DEAD_TOKEN_ERRORS:
                            dead_tokens.append(token)
                except (ValueError, AttributeError):
                    pass
            return False
        except Exception as e:
            log.warning(f"FCM send error: {e}")
            return False

    # 20 workers keeps us under FCM's recommended QPS while still finishing
    # 1000 tokens in under 10s. Bump if push volume scales further.
    from concurrent.futures import ThreadPoolExecutor
    workers = min(20, max(1, len(tokens)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(_send, tokens))

    # Detach dead tokens so saved_jobs / users rows aren't deleted, but future
    # pushes skip these phantoms entirely.
    if dead_tokens:
        try:
            conn = get_db()
            for t in set(dead_tokens):
                conn.execute("UPDATE users SET fcm_token = NULL WHERE fcm_token = ?", (t,))
            log.info(f"cleaned {len(set(dead_tokens))} dead FCM tokens")
        except Exception as e:
            log.warning(f"dead-token cleanup failed: {e}")

    return sum(1 for r in results if r)


def notify_users_new_jobs(conn, new_count: int, categories: list[str]):
    """Legacy wrapper — kept for backward compat."""
    return notify_users_personalized(conn, {c: 1 for c in categories})


_CAT_LABELS = {
    "railway": "Railway", "banking": "Banking", "ssc": "SSC",
    "teaching": "Teaching", "police": "Police", "defence": "Defence",
    "upsc": "UPSC/IAS", "anganwadi": "Anganwadi", "psu": "PSU",
    "medical": "Medical", "research": "Research", "engineering": "Engineering",
    "legal": "Legal", "postal": "Postal", "admin": "Admin",
    "it_tech": "IT/Tech", "accounts": "Accounts", "forest": "Forest",
}


def notify_users_personalized(conn, cats_inserted: dict) -> int:
    """
    Send personalized push notifications based on user job_types preference.

    Strategy:
    - User has job_types → only notify if any of their preferred categories got new jobs
    - User has no job_types → notify about all new jobs (generic)
    - Group users by message content to minimise FCM calls
    - Cap at 500 tokens to prevent timeouts on free tier
    """
    if not cats_inserted:
        return 0

    users = conn.execute(
        "SELECT fcm_token, job_types FROM users "
        "WHERE fcm_token IS NOT NULL AND fcm_token != 'test' AND fcm_token != ''"
    ).fetchall()
    if not users:
        return 0

    # Build message_content → [tokens] map to batch identical messages
    msg_map: dict[tuple, list[str]] = {}

    for user in users:
        token = user["fcm_token"]
        if not token:
            continue
        try:
            job_types = json.loads(user["job_types"] or "[]")
        except Exception:
            job_types = []

        if job_types:
            # Personalised: only categories the user cares about
            matched = {c: n for c, n in cats_inserted.items() if c in job_types}
        else:
            # Generic: all new categories
            matched = cats_inserted

        if not matched:
            continue

        total = sum(matched.values())
        top_cats = sorted(matched.items(), key=lambda x: -x[1])[:3]
        cat_str = ", ".join(_CAT_LABELS.get(c, c.title()) for c, _ in top_cats)
        if len(matched) > 3:
            cat_str += f" +{len(matched)-3} more"
        body = f"{total} naye {'job' if total == 1 else 'jobs'}: {cat_str}"

        key = (body,)
        msg_map.setdefault(key, []).append(token)

    sent = 0
    # Cap total push fan-out per scrape — Cloud Run request times out at 60s
    # and 20-worker threadpool tops out around ~2k tokens within budget.
    # We cap at 2000 total tokens, splitting fairly across message groups.
    MAX_TOTAL_TOKENS = 2000
    total_tokens = sum(len(v) for v in msg_map.values())
    if total_tokens > MAX_TOTAL_TOKENS:
        scale = MAX_TOTAL_TOKENS / total_tokens
        msg_map = {k: v[: max(1, int(len(v) * scale))] for k, v in msg_map.items()}

    for (body,), tokens in msg_map.items():
        sent += send_fcm_to_tokens(
            tokens,
            title="🇮🇳 JobMitra — Nai Jobs Aayi!",
            body=body,
            data={"screen": "home"},
        )
    return sent


# ─────────────────────────────────────────
# ROUTES
# ─────────────────────────────────────────

@app.get("/")
def root():
    return {"message": "JobMitra API v1.0 🇮🇳", "status": "running"}


@app.get("/health")
def health():
    """Cheap liveness probe for Cloud Run / uptime checks. No DB touch — must
    return 200 even if Turso is briefly unreachable, so we don't get
    auto-rolled-back on a transient hiccup."""
    return {"status": "ok"}


@app.post("/users/register")
def register_user(profile: UserProfile):
    conn = get_db()

    # Normalize fcm_token: '' / 'test' violate the fcm_token UNIQUE column when
    # more than one user lands without a real token. Store NULL instead — SQLite
    # treats multiple NULLs as distinct so UNIQUE no longer collides.
    raw_token = (profile.fcm_token or "").strip()
    fcm_token: Optional[str] = raw_token if raw_token and raw_token != "test" else None

    # Identity resolution: prefer install_id (stable across FCM token rotations
    # and Firebase reinstalls). Fall back to fcm_token only when present.
    existing = None
    if profile.install_id:
        existing = conn.execute(
            "SELECT id FROM users WHERE install_id = ?", (profile.install_id,)
        ).fetchone()
    if not existing and fcm_token:
        existing = conn.execute(
            "SELECT id FROM users WHERE fcm_token = ?", (fcm_token,)
        ).fetchone()

    # If another user already owns this fcm_token (Firebase reused token
    # after a reinstall on a different install_id), null out theirs so the
    # UNIQUE constraint doesn't blow up the upsert.
    if fcm_token:
        conn.execute("""
            UPDATE users SET fcm_token = NULL
            WHERE fcm_token = ? AND (install_id IS NULL OR install_id != ?)
        """, (fcm_token, profile.install_id or ""))

    if existing:
        conn.execute("""
            UPDATE users SET fcm_token=?, install_id=COALESCE(?, install_id),
                state=?, education=?, category=?, age=?, job_types=?, language=?
            WHERE id=?
        """, (
            fcm_token, profile.install_id,
            profile.state, profile.education, profile.category,
            profile.age, json.dumps(profile.job_types), profile.language,
            existing["id"],
        ))
        user_id = existing["id"]
    else:
        # Two parallel registrations with the same install_id/fcm_token can
        # both fall through the existing=None branch and race INSERT. Catch
        # the UNIQUE violation and retry the UPDATE path on the winner row.
        try:
            conn.execute("""
                INSERT INTO users (fcm_token, install_id, state, education, category, age, job_types, language)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                fcm_token, profile.install_id, profile.state, profile.education,
                profile.category, profile.age,
                json.dumps(profile.job_types), profile.language
            ))
            user_id = conn.lastrowid
        except Exception as e:
            log.info(f"register INSERT race resolving via update: {e}")
            row = None
            if profile.install_id:
                row = conn.execute(
                    "SELECT id FROM users WHERE install_id = ?", (profile.install_id,)
                ).fetchone()
            if not row and fcm_token:
                row = conn.execute(
                    "SELECT id FROM users WHERE fcm_token = ?", (fcm_token,)
                ).fetchone()
            if not row:
                raise HTTPException(status_code=500, detail="Register failed") from e
            conn.execute("""
                UPDATE users SET fcm_token=?, install_id=COALESCE(?, install_id),
                    state=?, education=?, category=?, age=?, job_types=?, language=?
                WHERE id=?
            """, (
                fcm_token, profile.install_id,
                profile.state, profile.education, profile.category,
                profile.age, json.dumps(profile.job_types), profile.language,
                row["id"],
            ))
            user_id = row["id"]

    return {"success": True, "user_id": user_id}


@app.get("/jobs/feed")
def get_job_feed(
    user_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    state: Optional[str] = None,
    response: Response = None,
):
    """
    state=<code>     → override profile state filter for this call
    state=all_india  → drop state filter entirely
    state=None       → use the user's saved profile state (default)
    """
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user_state     = state if state else user["state"]
    skip_state     = (state or "").lower() == "all_india"
    user_education = user["education"]
    user_category  = user["category"]
    user_age       = user["age"]
    user_job_types = json.loads(user["job_types"] or "[]")

    # Build SQL filters — push as much work as possible to the DB layer.
    # Education qualification uses a hierarchy (8th<10th<12th<diploma<grad<pg)
    # that can't be expressed as a simple SQL predicate, so it stays in Python.
    sql_params: list = [user_age, user_age]

    # Expired-job filter: last_date stored as DD/MM/YYYY; convert inline with
    # SQLite substr so we never fetch rows the user can't apply to.
    date_filter = (
        "AND last_date IS NOT NULL AND last_date != ''"
        " AND DATE(SUBSTR(last_date,7,4)||'-'||SUBSTR(last_date,4,2)||'-'||SUBSTR(last_date,1,2))"
        "     >= DATE('now')"
    )

    # State filter: states column is a JSON array e.g. '["all"]' or '["up","hr"]'.
    # LIKE-based containment is fast enough at current DB sizes; json_each()
    # would be cleaner but adds per-row function overhead in libsql.
    state_clause = ""
    if not skip_state and user_state and user_state.lower() not in ("", "all_india"):
        state_clause = "AND (LOWER(states) LIKE '%\"all\"%' OR LOWER(states) LIKE ?)"
        sql_params.append(f'%"{user_state.lower()}"%')

    cat_filter = ""
    if user_job_types:
        placeholders = ",".join("?" * len(user_job_types))
        cat_filter = f"AND category IN ({placeholders})"
        sql_params += user_job_types

    # Sort pushed to SQL: closing-soonest first, then most vacancies.
    # DATE() conversion makes the sort correct for DD/MM/YYYY strings.
    jobs_raw = conn.execute(f"""
        SELECT * FROM jobs
        WHERE is_active = 1
          AND age_min <= ? AND age_max >= ?
          {date_filter}
          {state_clause}
          {cat_filter}
        ORDER BY DATE(SUBSTR(last_date,7,4)||'-'||SUBSTR(last_date,4,2)||'-'||SUBSTR(last_date,1,2)) ASC,
                 vacancies DESC
        LIMIT 500
    """, sql_params).fetchall()

    today = datetime.now()
    eligible_jobs = []
    for job in jobs_raw:
        job_quals = json.loads(job["qualifications"] or '["graduate"]')
        if not user_qualifies(user_education, job_quals):
            continue

        last_date_dt = datetime.strptime(job["last_date"], "%d/%m/%Y")
        days_left = (last_date_dt - today).days

        if user_category == "obc":
            fee = job["fee_obc"]
        elif user_category in ("sc", "st"):
            fee = job["fee_sc_st"]
        else:
            fee = job["fee_general"]

        docs_raw = job["documents_needed"] if "documents_needed" in dict(job) else None
        eligible_jobs.append({
            "id":               job["id"],
            "title":            job["title"],
            "department":       job["department"],
            "source":           job["source"],
            "source_url":       job["source_url"],
            "category":         job["category"],
            "vacancies":        job["vacancies"],
            "last_date":        job["last_date"],
            "days_left":        days_left,
            "urgency":          "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
            "fee":              fee,
            "is_free":          fee == 0,
            "qualifications":   job_quals,
            "states":           json.loads(job["states"] or '["all"]'),
            "age_min":          job["age_min"],
            "age_max":          job["age_max"],
            "pay_scale":        job["pay_scale"] or "",
            "documents_needed": json.loads(docs_raw) if docs_raw else None,
            "scraped_at":       job["scraped_at"] or "",
        })

    total = len(eligible_jobs)
    start = (page - 1) * page_size
    end   = start + page_size

    if response is not None:
        response.headers["Cache-Control"] = "private, max-age=60"

    return {
        "total":    total,
        "page":     page,
        "jobs":     eligible_jobs[start:end],
        "has_more": end < total,
    }


@app.get("/jobs/search")
def search_jobs(
    q:         str = Query(..., min_length=2, max_length=128),
    page:      int = Query(1,   ge=1,   le=500),
    page_size: int = Query(20,  ge=1,   le=100),
    user_category: str = Query("general", max_length=16),
):
    conn = get_db()
    jobs_raw = conn.execute("""
        SELECT * FROM jobs
        WHERE is_active = 1
        AND (title LIKE ? OR department LIKE ? OR category LIKE ?)
        ORDER BY scraped_at DESC
        LIMIT ? OFFSET ?
    """, (f"%{q}%", f"%{q}%", f"%{q}%", page_size, (page - 1) * page_size)).fetchall()

    results = []
    for job in jobs_raw:
        try:
            last_date = datetime.strptime(job["last_date"], "%d/%m/%Y")
            days_left = (last_date - datetime.now()).days
        except (ValueError, TypeError):
            continue

        if days_left < 0:
            continue

        if user_category == "obc":
            fee = job["fee_obc"]
        elif user_category in ("sc", "st"):
            fee = job["fee_sc_st"]
        else:
            fee = job["fee_general"]

        docs_raw = job["documents_needed"] if "documents_needed" in dict(job) else None
        results.append({
            "id":               job["id"],
            "title":            job["title"],
            "department":       job["department"],
            "source":           job["source"],
            "source_url":       job["source_url"],
            "category":         job["category"],
            "vacancies":        job["vacancies"],
            "last_date":        job["last_date"],
            "days_left":        days_left,
            "urgency":          "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
            "fee":              fee,
            "is_free":          fee == 0,
            "qualifications":   _safe_json_loads(job["qualifications"], []),
            "states":           _safe_json_loads(job["states"], ["all"]),
            "age_min":          job["age_min"],
            "age_max":          job["age_max"],
            "pay_scale":        job["pay_scale"] or "",
            "documents_needed": _safe_json_loads(docs_raw, None),
            "scraped_at":       job["scraped_at"] or "",
        })

    return {"jobs": results, "query": q, "total": len(results)}


@app.get("/jobs/{job_id}")
def get_job_detail(job_id: int, user_category: str = "general"):
    conn = get_db()
    job = conn.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    try:
        last_date = datetime.strptime(job["last_date"], "%d/%m/%Y")
        days_left = (last_date - datetime.now()).days
    except (ValueError, TypeError):
        days_left = 0

    fee = job["fee_general"]
    if user_category == "obc":             fee = job["fee_obc"]
    elif user_category in ("sc", "st"):    fee = job["fee_sc_st"]

    return {
        "id":             job["id"],
        "title":          job["title"],
        "department":     job["department"],
        "source":         job["source"],
        "source_url":     job["source_url"],
        "category":       job["category"],
        "qualifications": _safe_json_loads(job["qualifications"], []),
        "vacancies":      job["vacancies"],
        "last_date":      job["last_date"],
        "days_left":      days_left,
        "urgency":        "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
        "age_min":        job["age_min"],
        "age_max":        job["age_max"],
        "fee":            fee,
        "is_free":        fee == 0,
        "states":         _safe_json_loads(job["states"], ["all"]),
        "pay_scale":      job["pay_scale"] or "",
        "scraped_at":       job["scraped_at"],
        "documents_needed": _safe_json_loads(job["documents_needed"], None),
    }


@app.post("/jobs/save")
def save_job(req: SaveJobRequest):
    conn = get_db()
    # Relies on UNIQUE INDEX idx_saved_uniq(user_id, job_id) from migration v4.
    # ON CONFLICT collapses the concurrent-double-tap race that the old
    # SELECT-then-UPDATE pattern still allowed.
    conn.execute("""
        INSERT INTO saved_jobs (user_id, job_id, status) VALUES (?, ?, ?)
        ON CONFLICT(user_id, job_id) DO UPDATE
            SET status = excluded.status,
                saved_at = CURRENT_TIMESTAMP
    """, (req.user_id, req.job_id, req.status))
    return {"success": True}


@app.get("/users/{user_id}/saved")
def get_saved_jobs(user_id: int, user_category: str = "general"):
    conn = get_db()
    user = conn.execute("SELECT category FROM users WHERE id=?", (user_id,)).fetchone()
    cat = (user["category"] if user else None) or user_category

    # v4 migration enforces UNIQUE(user_id, job_id) on saved_jobs, so the old
    # `s.id = (SELECT MAX(id) ...)` correlated subquery is now dead weight —
    # there's only one row per (user, job) by construction. Dropping it
    # eliminates N+1 (was: 1 subquery per saved-job row, now: 1 single JOIN).
    rows = conn.execute("""
        SELECT j.*, s.status, s.saved_at
        FROM saved_jobs s
        JOIN jobs j ON s.job_id = j.id
        WHERE s.user_id = ?
          AND s.status != 'unsaved'
        ORDER BY s.saved_at DESC
    """, (user_id,)).fetchall()

    results = []
    for row in rows:
        try:
            ld = datetime.strptime(row["last_date"], "%d/%m/%Y")
            days_left = (ld - datetime.now()).days
        except (ValueError, TypeError):
            days_left = 0

        if cat == "obc":
            fee = row["fee_obc"]
        elif cat in ("sc", "st"):
            fee = row["fee_sc_st"]
        else:
            fee = row["fee_general"]

        results.append({
            "id":             row["id"],
            "title":          row["title"],
            "department":     row["department"],
            "source":         row["source"],
            "source_url":     row["source_url"],
            "category":       row["category"],
            "vacancies":      row["vacancies"],
            "last_date":      row["last_date"],
            "days_left":      days_left,
            "urgency":        "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
            "fee":            fee,
            "is_free":        fee == 0,
            "qualifications": json.loads(row["qualifications"] or "[]"),
            "states":         json.loads(row["states"] or '["all"]'),
            "age_min":        row["age_min"],
            "age_max":        row["age_max"],
            "job_status":     row["status"],   # 'saved' or 'applied'
        })

    return {"saved_jobs": results}


# ─────────────────────────────────────────
# ALERT RULES (server-side push for matched new jobs)
# ─────────────────────────────────────────

class AlertRuleIn(BaseModel):
    id:        str
    keyword:   str = ""
    state:     str = ""
    category:  str = ""
    free_only: bool = False
    is_active: bool = True


@app.get("/users/{user_id}/alert-rules")
def list_alert_rules(user_id: int):
    conn = get_db()
    rows = conn.execute(
        "SELECT rule_id, keyword, state, category, free_only, is_active "
        "FROM user_alert_rules WHERE user_id = ? ORDER BY id",
        (user_id,),
    ).fetchall()
    return {"rules": [{
        "id":        r["rule_id"],
        "keyword":   r["keyword"],
        "state":     r["state"],
        "category":  r["category"],
        "free_only": bool(r["free_only"]),
        "is_active": bool(r["is_active"]),
    } for r in rows]}


@app.put("/users/{user_id}/alert-rules")
def replace_alert_rules(user_id: int, rules: list[AlertRuleIn] = Body(...)):
    """Bulk replace — clears existing rules then inserts the supplied list.
    Flutter persists rules locally and pushes the full snapshot here on every
    save, so the server is always the authoritative copy for scrape-time
    evaluation."""
    conn = get_db()
    # Validate user exists; quietly create-or-skip is heavier than worth here
    user = conn.execute("SELECT id FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    conn.execute("DELETE FROM user_alert_rules WHERE user_id = ?", (user_id,))
    inserted = 0
    for rule in rules:
        try:
            conn.execute("""
                INSERT INTO user_alert_rules
                    (user_id, rule_id, keyword, state, category, free_only, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                user_id, rule.id, rule.keyword.strip(), rule.state.strip(),
                rule.category.strip(), 1 if rule.free_only else 0,
                1 if rule.is_active else 0,
            ))
            inserted += 1
        except Exception:
            pass
    return {"success": True, "stored": inserted}


def _rule_matches_job(rule: dict, job: dict) -> bool:
    """Port of Flutter AlertRule.matches — keep semantics aligned."""
    if not rule["is_active"]:
        return False
    if rule["free_only"] and (job.get("fee_general", 0) or 0) > 0:
        return False
    kw = (rule["keyword"] or "").strip().lower()
    if kw:
        hay = f"{job.get('title', '')} {job.get('department', '')}".lower()
        if kw not in hay:
            return False
    st = (rule["state"] or "").strip().lower()
    if st:
        try:
            job_states = [s.lower() for s in json.loads(job.get("states") or "[]")]
        except Exception:
            job_states = []
        if "all" not in job_states and st not in job_states:
            return False
    cat = (rule["category"] or "").strip()
    if cat and job.get("category") != cat:
        return False
    return True


def notify_users_alert_rule_matches(conn, new_job_ids: list[int]) -> int:
    """For every newly inserted job id, find active alert rules that match
    and send one FCM push per (user, rule) group. Called from /admin/scrape
    after the insert phase. Returns count of pushes sent."""
    if not new_job_ids:
        return 0
    # Pull all active rules joined with token, plus the new jobs
    placeholders = ",".join("?" * len(new_job_ids))
    jobs = conn.execute(
        f"SELECT id, title, department, category, states, fee_general "
        f"FROM jobs WHERE id IN ({placeholders})",
        new_job_ids,
    ).fetchall()
    rules = conn.execute("""
        SELECT r.id, r.user_id, r.rule_id, r.keyword, r.state, r.category,
               r.free_only, r.is_active, u.fcm_token
        FROM user_alert_rules r
        JOIN users u ON u.id = r.user_id
        WHERE r.is_active = 1
          AND u.fcm_token IS NOT NULL
          AND u.fcm_token NOT IN ('', 'test')
    """).fetchall()
    if not rules or not jobs:
        return 0

    sent = 0
    for rule in rules:
        rdict = {
            "is_active": bool(rule["is_active"]),
            "free_only": bool(rule["free_only"]),
            "keyword":   rule["keyword"],
            "state":     rule["state"],
            "category":  rule["category"],
        }
        matches = [j for j in jobs if _rule_matches_job(rdict, dict(j))]
        if not matches:
            continue
        first = matches[0]["title"]
        label_bits = []
        if rdict["keyword"]:  label_bits.append(f'"{rdict["keyword"]}"')
        if rdict["state"]:    label_bits.append(rdict["state"])
        if rdict["category"]: label_bits.append(rdict["category"])
        label = " + ".join(label_bits) if label_bits else "Saved alert"
        if len(matches) == 1:
            body = f"{first[:90]} — matched {label}"
        else:
            body = f"{first[:60]}… +{len(matches) - 1} aur jobs matched {label}"
        ok = send_fcm_to_tokens(
            [rule["fcm_token"]],
            title="🔔 JobMitra Alert",
            body=body[:240],
            data={"deeplink": "alerts", "rule_id": rule["rule_id"]},
        )
        if ok:
            sent += 1
    return sent


@app.put("/users/{user_id}/profile")
def update_profile(user_id: int, profile: UserProfile):
    conn = get_db()
    conn.execute("""
        UPDATE users
        SET state=?, education=?, category=?, age=?, job_types=?, language=?
        WHERE id=?
    """, (profile.state, profile.education, profile.category,
          profile.age, json.dumps(profile.job_types), profile.language, user_id))
    return {"success": True, "user_id": user_id}


@app.get("/users/{user_id}/job/{job_id}/status")
def get_job_status(user_id: int, job_id: int):
    conn = get_db()
    # Get LATEST status (multiple rows possible due to legacy inserts)
    row = conn.execute("""
        SELECT status FROM saved_jobs
        WHERE user_id = ? AND job_id = ?
        ORDER BY id DESC LIMIT 1
    """, (user_id, job_id)).fetchone()
    return {"status": row["status"] if row else None}


@app.get("/stats")
def get_stats(response: Response):
    conn = get_db()
    total_jobs  = conn.execute("SELECT COUNT(*) as c FROM jobs WHERE is_active=1").fetchone()["c"]
    total_users = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()["c"]
    by_category = conn.execute("""
        SELECT category, COUNT(*) as count
        FROM jobs WHERE is_active=1
        GROUP BY category ORDER BY count DESC
    """).fetchall()
    response.headers["Cache-Control"] = "public, max-age=300"
    return {
        "total_jobs":   total_jobs,
        "total_users":  total_users,
        "by_category":  [dict(r) for r in by_category],
        "last_updated": datetime.now().isoformat(),
    }


# ─────────────────────────────────────────
# SCRAPER TRIGGER
# ─────────────────────────────────────────

@app.post("/admin/fix_fees")
def fix_fees(secret: str = Query(...)):
    """Reset all fake ₹100 default fees to 0 (free/unknown) in existing DB records"""
    require_admin(secret)
    conn = get_db()
    conn.execute("UPDATE jobs SET fee_general=0, fee_obc=0, fee_sc_st=0 WHERE fee_general=100")
    return {"success": True, "message": "All fee_general=100 rows reset to 0"}


def _insert_job(conn, job: dict) -> Optional[int]:
    """Insert a single job atomically. Returns the new row id when actually
    inserted, None when the source_url already exists (INSERT OR IGNORE skipped)
    or when the statement errors. Callers used to receive a bool, but the
    `True on IGNORE` path lied about insertions and broke any push routing
    that needed to know which jobs are new.

    Note: relies on the UNIQUE constraint on source_url. INSERT OR IGNORE is
    atomic — two concurrent scrapes can no longer both pass a SELECT and
    double-insert the same job."""
    try:
        docs = job.get("documents_needed")
        conn.execute("""
            INSERT OR IGNORE INTO jobs
            (title, department, source, source_url, category,
             qualifications, vacancies, last_date, states,
             age_min, age_max, fee_general, fee_obc, fee_sc_st,
             pay_scale, pay_level, grade_pay,
             notification_type, application_mode, trust_score,
             published_at, description, documents_needed, scraped_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            job["title"], job["department"], job["source"],
            job["source_url"], job["category"],
            json.dumps(job["qualifications"]),
            job["vacancies"], job["last_date"],
            json.dumps(job["states"]),
            job["age_min"], job["age_max"],
            job["fee_general"], job["fee_obc"], job["fee_sc_st"],
            job.get("pay_scale", ""),
            job.get("pay_level", 0),
            job.get("grade_pay", 0),
            job.get("notification_type", "new"),
            job.get("application_mode", "online"),
            job.get("trust_score", 5),
            job.get("published_at", ""),
            job.get("description", ""),
            json.dumps(docs) if docs else None,
            job["scraped_at"]
        ))
        # TursoAdapter.lastrowid is None when INSERT OR IGNORE skipped a dup
        # (same behavior as the /admin/questions handler relies on).
        return conn.lastrowid or None
    except Exception:
        log.exception("_insert_job failed for url=%s", job.get("source_url"))
        return None


@app.post("/admin/scrape")
def trigger_scrape(secret: str = Query(...)):
    require_admin(secret)
    try:
        from scraper import run_all as run_all_scrapers
        jobs = run_all_scrapers()
        conn = get_db()
        inserted = 0
        new_job_ids: list[int] = []
        cats_inserted: dict[str, int] = {}
        for job in jobs:
            row_id = _insert_job(conn, job)
            if row_id is not None:
                inserted += 1
                new_job_ids.append(row_id)
                cats_inserted[job["category"]] = cats_inserted.get(job["category"], 0) + 1
        # Auto-expire jobs past their last_date
        expired = 0
        all_active = conn.execute("SELECT id, last_date FROM jobs WHERE is_active=1").fetchall()
        for j in all_active:
            try:
                if (datetime.strptime(j["last_date"], "%d/%m/%Y") - datetime.now()).days < 0:
                    conn.execute("UPDATE jobs SET is_active=0 WHERE id=?", (j["id"],))
                    expired += 1
            except Exception:
                pass
        # Generic personalized push (category-based)
        notified = 0
        if inserted > 0:
            try:
                notified = notify_users_personalized(conn, cats_inserted)
            except Exception:
                pass
        # Server-side AlertRule evaluation: per-user push for matched new jobs
        alert_pushes = 0
        if new_job_ids:
            try:
                alert_pushes = notify_users_alert_rule_matches(conn, new_job_ids)
            except Exception:
                pass
        return {
            "success": True,
            "jobs_inserted": inserted,
            "jobs_expired":  expired,
            "notified":      notified,
            "alert_pushes":  alert_pushes,
        }
    except Exception:
        log.exception("admin/scrape failed")
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/admin/notify-quiz")
def notify_quiz(secret: str = Query(...)):
    """Send daily quiz reminder to all subscribed users via topic push."""
    require_admin(secret)
    from datetime import date
    day_num = (date.today() - date(2026, 1, 1)).days % 60  # 60-day rotation
    ok = send_fcm_to_topic(
        "jobmitra_announcements",
        title="📝 Aaj ka Quiz Ready!",
        body=f"Daily GK quiz #{day_num + 1} — kya tum aaj bhi perfect score loge? 🔥",
        data={"screen": "quiz"},
    )
    return {"sent": ok}


@app.post("/admin/notify")
def manual_notify(
    secret: str = Query(...),
    # FCM caps the visible body at ~240 chars; reject anything that would
    # silently truncate or get rejected by Google's HTTP gateway.
    title:  str = Query("🇮🇳 JobMitra", max_length=120),
    body:   str = Query(...,            max_length=240),
):
    """Manually send a push notification to all users. For testing."""
    require_admin(secret)
    conn = get_db()
    tokens = [
        row["fcm_token"]
        for row in conn.execute(
            "SELECT fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != 'test'"
        ).fetchall()
        if row["fcm_token"]
    ]
    sent = send_fcm_to_tokens(tokens, title=title, body=body, data={"screen": "home"})
    return {"sent": sent, "total_users": len(tokens)}


# Per-horizon push copy. Audit recommended 3 separate sends — 2-day (more
# action time), 1-day (last call), 0-day (final morning). Each horizon gets
# its own push so a user with multiple saved jobs gets distinct nudges as
# their deadlines roll in, instead of one merged blast on day 3.
_DEADLINE_HORIZONS = (0, 1, 2)
_DEADLINE_COPY = {
    0: ("⏰ Aaj last date!",   "Aaj last date hai"),
    1: ("⏰ Kal last date",    "Kal last date — apply karo"),
    2: ("⏰ 2 din baad",       "2 din mein last date"),
}


@app.post("/admin/deadline-alerts")
def deadline_alerts(secret: str = Query(...)):
    """
    Send personalised pushes to every user whose saved jobs are 0, 1, or 2
    days from the last date. One push **per (user, horizon)** so a user with
    a job expiring today and another in 2 days gets two distinct nudges
    instead of a single merged blast. Designed for a daily 8 AM IST cron.
    """
    require_admin(secret)
    conn = get_db()
    rows = conn.execute("""
        SELECT u.id AS user_id, u.fcm_token, j.title, j.last_date
        FROM saved_jobs s
        JOIN jobs j  ON s.job_id  = j.id
        JOIN users u ON s.user_id = u.id
        WHERE s.status = 'saved'
          AND j.is_active = 1
          AND u.fcm_token IS NOT NULL
          AND u.fcm_token NOT IN ('', 'test')
    """).fetchall()

    today = datetime.now().date()
    # (user_id, fcm_token, horizon) -> list[job_title]
    bucket: dict[tuple[int, str, int], list[str]] = {}
    for r in rows:
        try:
            ld = datetime.strptime(r["last_date"], "%d/%m/%Y").date()
        except Exception:
            continue
        days_left = (ld - today).days
        if days_left not in _DEADLINE_HORIZONS:
            continue
        key = (r["user_id"], r["fcm_token"], days_left)
        bucket.setdefault(key, []).append(r["title"])

    sent = 0
    per_horizon: dict[int, int] = {h: 0 for h in _DEADLINE_HORIZONS}
    for (_, token, horizon), titles in bucket.items():
        title_text, hdr = _DEADLINE_COPY[horizon]
        first = titles[0]
        if len(titles) == 1:
            body = f"{first[:120]} — {hdr}"
        else:
            body = f"{first[:60]}… +{len(titles) - 1} aur saved jobs — {hdr}"
        ok = send_fcm_to_tokens(
            [token],
            title=title_text,
            body=body[:240],
            data={"deeplink": "saved", "days": horizon},
        )
        if ok:
            sent += 1
            per_horizon[horizon] = per_horizon.get(horizon, 0) + 1
    return {
        "users_notified":  sent,
        "buckets":         len(bucket),
        "rows_scanned":    len(rows),
        "per_horizon":     per_horizon,
    }


@app.post("/admin/reset_jobs")
def reset_jobs(secret: str = Query(...)):
    """Delete all jobs and re-scrape fresh — fixes duplicates"""
    require_admin(secret)
    try:
        conn = get_db()
        conn.execute("DELETE FROM jobs")
        from scraper import run_all as run_all_scrapers
        jobs = run_all_scrapers()
        inserted = sum(1 for job in jobs if _insert_job(conn, job))
        return {"success": True, "jobs_inserted": inserted}
    except Exception:
        log.exception("admin/reset_jobs failed")
        raise HTTPException(status_code=500, detail="internal error")


@app.get("/current-affairs")
def get_current_affairs(
    days: int = Query(7, ge=1, le=30),
    category: Optional[str] = Query(None, max_length=32),
    limit: int = Query(50, ge=1, le=200),
):
    conn = get_db()
    since = (datetime.utcnow() - timedelta(days=days)).strftime("%Y-%m-%d")
    if category and category != "all":
        rows = conn.execute(
            """SELECT id, title, summary, category, pub_date, source_name, source_url
               FROM current_affairs
               WHERE pub_date >= ? AND category = ?
               ORDER BY pub_date DESC, id DESC LIMIT ?""",
            (since, category, limit)
        ).fetchall()
    else:
        rows = conn.execute(
            """SELECT id, title, summary, category, pub_date, source_name, source_url
               FROM current_affairs
               WHERE pub_date >= ?
               ORDER BY pub_date DESC, id DESC LIMIT ?""",
            (since, limit)
        ).fetchall()
    return [
        {
            "id":          r["id"],
            "title":       r["title"],
            "summary":     r["summary"],
            "category":    r["category"],
            "pub_date":    r["pub_date"],
            "source_name": r["source_name"],
            "source_url":  r["source_url"],
        }
        for r in rows
    ]


@app.post("/admin/scrape-ca")
def scrape_current_affairs_endpoint(secret: str = Query(...)):
    require_admin(secret)
    try:
        from scraper import scrape_current_affairs
        articles = scrape_current_affairs()
        conn = get_db()
        inserted = 0
        for a in articles:
            try:
                conn.execute(
                    """INSERT OR REPLACE INTO current_affairs
                       (title, summary, category, pub_date, source_name, source_url)
                       VALUES (?,?,?,?,?,?)""",
                    (a["title"], a["summary"], a["category"],
                     a["pub_date"], a["source_name"], a["source_url"])
                )
                inserted += 1
            except Exception:
                pass
        return {"success": True, "inserted": inserted, "total": len(articles)}
    except Exception:
        log.exception("admin/scrape-ca failed")
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/admin/import-ca")
def import_current_affairs(secret: str = Query(...), payload: dict = Body(...)):
    require_admin(secret)
    articles = payload.get("articles", [])
    conn = get_db()
    inserted = 0
    for a in articles:
        try:
            conn.execute(
                """INSERT OR REPLACE INTO current_affairs
                   (title, summary, category, pub_date, source_name, source_url)
                   VALUES (?,?,?,?,?,?)""",
                (a.get("title",""), a.get("summary",""), a.get("category","misc"),
                 a.get("pub_date",""), a.get("source_name",""), a.get("source_url",""))
            )
            inserted += 1
        except Exception:
            pass
    return {"success": True, "inserted": inserted, "total": len(articles)}


# ─────────────────────────────────────────
# ANNOUNCEMENTS (admit cards, results, answer keys, cut-offs)
# ─────────────────────────────────────────

_ANNOUNCEMENT_TYPES = {"admit_card", "result", "answer_key", "cutoff", "syllabus", "exam_date"}

# Orgs we maintain per-org FCM topics for. Anything outside this list
# falls through to the general "jobmitra_announcements" topic only.
ANNOUNCEMENT_ORG_TOPICS = {
    "SSC", "UPSC", "RRB", "IBPS", "SBI", "RBI", "NABARD",
    "AIIMS", "DRDO", "ISRO", "NTPC", "BHEL", "ONGC",
    "UPSSSC", "UPPSC", "BPSC", "MPPSC", "RPSC", "TNPSC", "KPSC",
    "KVS", "NVS", "CTET", "REET",
    "NEET", "JEE", "CUET", "GATE",
    "FCI", "LIC", "SEBI", "BSNL", "NPCIL", "CSIR", "ICMR",
    "BSF", "CRPF", "CAPF", "CDS", "NDA", "AFCAT",
}


# Announcements older than this drop off public reads. Stale admit cards
# and results clutter the feed and confuse users into thinking the exam is
# still live. Stored rows aren't deleted — just filtered out — so audit
# history stays intact.
_ANNOUNCEMENT_TTL_DAYS = 90


def _announcement_cutoff_iso() -> str:
    return (datetime.now() - timedelta(days=_ANNOUNCEMENT_TTL_DAYS)).isoformat()


@app.get("/announcements")
def list_announcements(
    type: Optional[str] = Query(None, max_length=32),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0, le=10000),
):
    """Public read. Returns only announcements scraped within the last
    _ANNOUNCEMENT_TTL_DAYS (90 days). Optional ?type filter."""
    conn = get_db()
    if type and type not in _ANNOUNCEMENT_TYPES:
        raise HTTPException(status_code=400, detail=f"invalid type; one of {sorted(_ANNOUNCEMENT_TYPES)}")
    cutoff = _announcement_cutoff_iso()
    if type:
        rows = conn.execute(
            "SELECT * FROM announcements "
            "WHERE type = ? AND scraped_at >= ? "
            "ORDER BY scraped_at DESC LIMIT ? OFFSET ?",
            (type, cutoff, limit, offset),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM announcements "
            "WHERE scraped_at >= ? "
            "ORDER BY scraped_at DESC LIMIT ? OFFSET ?",
            (cutoff, limit, offset),
        ).fetchall()
    return {"announcements": [dict(r) for r in rows], "count": len(rows)}


@app.get("/announcements/counts")
def announcement_counts():
    """One-shot tab counts within the same TTL window list_announcements uses,
    otherwise the badge numbers diverge from the feed contents."""
    conn = get_db()
    rows = conn.execute(
        "SELECT type, COUNT(*) AS n FROM announcements "
        "WHERE scraped_at >= ? GROUP BY type",
        (_announcement_cutoff_iso(),),
    ).fetchall()
    return {"counts": {r["type"]: r["n"] for r in rows}}


@app.post("/admin/announcements")
def bulk_insert_announcements(secret: str = Query(...), payload: dict = Body(...)):
    """Idempotent bulk insert keyed by source_url."""
    require_admin(secret)
    items = payload.get("announcements", [])
    if not isinstance(items, list):
        raise HTTPException(status_code=400, detail="announcements must be a list")
    conn = get_db()
    inserted = 0
    for it in items:
        t = (it.get("type") or "").strip()
        url = (it.get("source_url") or "").strip()
        title = (it.get("title") or "").strip()
        if not t or not url or not title or t not in _ANNOUNCEMENT_TYPES:
            continue
        try:
            conn.execute("""
                INSERT OR IGNORE INTO announcements
                (type, title, exam_name, organisation, release_date,
                 source, source_url, description, scraped_at)
                VALUES (?,?,?,?,?,?,?,?,?)
            """, (
                t, title[:300],
                (it.get("exam_name") or "")[:120],
                (it.get("organisation") or "")[:120],
                it.get("release_date") or "",
                (it.get("source") or "")[:80],
                url,
                (it.get("description") or "")[:800],
                it.get("scraped_at") or datetime.now().isoformat(),
            ))
            inserted += 1
        except Exception:
            pass
    return {"inserted": inserted, "total": len(items)}


_ALLOWED_TEST_TOPIC_PREFIXES = (
    "jobmitra_announcements",
    "announcements_org_",
)

@app.post("/admin/test-push")
def test_push(secret: str = Query(...), topic: str = Query("jobmitra_announcements"),
              title: str = Query("Test"), body: str = Query("Smoke test")):
    """Admin smoke test for FCM topic push. Topic must be in our whitelist
    so a leaked secret can't be used to spam arbitrary topics in the Firebase
    project (e.g. topics belonging to the LeadMaps / Resume Maker apps that
    share this Firebase project)."""
    require_admin(secret)
    if not any(topic == p or topic.startswith(p) for p in _ALLOWED_TEST_TOPIC_PREFIXES):
        raise HTTPException(status_code=400, detail="topic not in allow-list")
    ok = send_fcm_to_topic(topic, title, body, data={"deeplink": "announcements"})
    return {"pushed": ok, "topic": topic}


@app.post("/admin/scrape-announcements")
def scrape_announcements_endpoint(secret: str = Query(...)):
    """Run the scraper's announcement pass, insert results, push digest."""
    require_admin(secret)
    try:
        import scraper as _scr
        items = _scr.run_announcements() if hasattr(_scr, "run_announcements") else []
    except Exception:
        log.exception("admin/scrape-announcements failed")
        raise HTTPException(status_code=500, detail="internal error")

    conn = get_db()
    new_count = 0
    per_type: dict[str, int] = {}
    new_items: list[dict] = []  # only the freshly inserted ones (for per-org push)
    for it in items:
        url = it["source_url"]
        existed = conn.execute(
            "SELECT 1 FROM announcements WHERE source_url = ?", (url,)
        ).fetchone()
        try:
            conn.execute("""
                INSERT OR IGNORE INTO announcements
                (type, title, exam_name, organisation, release_date,
                 source, source_url, description, scraped_at)
                VALUES (?,?,?,?,?,?,?,?,?)
            """, (
                it["type"], it["title"][:300],
                it.get("exam_name", "")[:120],
                it.get("organisation", "")[:120],
                it.get("release_date", ""),
                it.get("source", "")[:80],
                url,
                it.get("description", "")[:800],
                it.get("scraped_at") or datetime.now().isoformat(),
            ))
            if not existed:
                new_count += 1
                per_type[it["type"]] = per_type.get(it["type"], 0) + 1
                new_items.append(it)
        except Exception:
            pass

    # Digest push notification to general topic — only when there are NEW items
    pushed = False
    org_pushes: dict[str, int] = {}
    if new_count > 0:
        ann_labels = {
            "admit_card": "admit cards", "result": "results",
            "answer_key": "answer keys", "cutoff": "cut-offs",
            "syllabus": "syllabus updates", "exam_date": "exam dates",
        }
        parts = []
        for t, n in sorted(per_type.items(), key=lambda x: -x[1])[:3]:
            parts.append(f"{n} {ann_labels.get(t, t)}")
        body = ", ".join(parts) if parts else f"{new_count} new"
        pushed = send_fcm_to_topic(
            "jobmitra_announcements",
            title="🇮🇳 Naye Updates",
            body=body[:240],
            data={"deeplink": "announcements", "count": new_count},
        )

        # Per-org granular push (only whitelisted orgs to prevent topic spam)
        per_org: dict[str, list[dict]] = {}
        for it in new_items:
            org = (it.get("organisation") or "").upper()
            if org in ANNOUNCEMENT_ORG_TOPICS:
                per_org.setdefault(org, []).append(it)
        for org, batch in per_org.items():
            type_counts: dict[str, int] = {}
            for b in batch:
                type_counts[b["type"]] = type_counts.get(b["type"], 0) + 1
            body_parts = [f"{n} {ann_labels.get(t, t)}" for t, n in
                          sorted(type_counts.items(), key=lambda x: -x[1])[:2]]
            org_body = f"{org}: {', '.join(body_parts)}" if body_parts else f"{org}: {len(batch)} updates"
            topic_name = f"announcements_org_{org.lower()}"
            ok = send_fcm_to_topic(
                topic_name,
                title=f"📌 {org} Update",
                body=org_body[:240],
                data={"deeplink": "announcements", "org": org},
            )
            if ok:
                org_pushes[org] = len(batch)

    return {
        "inserted": new_count, "total": len(items),
        "by_type": per_type, "pushed": pushed,
        "org_pushes": org_pushes,
    }


@app.post("/admin/bulk_import")
def bulk_import(secret: str = Query(...), payload: dict = Body(...)):
    require_admin(secret)
    jobs = payload.get("jobs", [])
    conn = get_db()
    inserted = 0
    for job in jobs:
        try:
            docs = job.get("documents_needed")
            conn.execute("""
                INSERT OR IGNORE INTO jobs
                (title, department, source, source_url, category,
                 qualifications, vacancies, last_date, states,
                 age_min, age_max, fee_general, fee_obc, fee_sc_st,
                 pay_scale, pay_level, grade_pay,
                 notification_type, application_mode, trust_score,
                 published_at, description, documents_needed, scraped_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                job.get("title", ""), job.get("department", ""),
                job.get("source", ""), job.get("source_url", ""),
                job.get("category", "others"),
                json.dumps(job.get("qualifications", ["graduate"])),
                job.get("vacancies", 0), job.get("last_date", ""),
                json.dumps(job.get("states", ["all"])),
                job.get("age_min", 18), job.get("age_max", 40),
                job.get("fee_general", 0), job.get("fee_obc", 0),
                job.get("fee_sc_st", 0),
                job.get("pay_scale", ""),
                job.get("pay_level", 0),
                job.get("grade_pay", 0),
                job.get("notification_type", "new"),
                job.get("application_mode", "online"),
                job.get("trust_score", 5),
                job.get("published_at", ""),
                job.get("description", ""),
                json.dumps(docs) if docs else None,
                job.get("scraped_at", "")
            ))
            inserted += 1
        except Exception as e:
            log.warning(f"insert failed for {job.get('source_url', '?')[:80]}: {e}")
    return {"inserted": inserted, "total": len(jobs)}


# ─────────────────────────────────────────
# QUIZ / MOCK TEST ENDPOINTS
# ─────────────────────────────────────────

@app.get("/daily-quiz")
def get_daily_quiz(set_index: int = Query(0)):
    """Return 5 questions for the given daily quiz set (0-based index)."""
    conn = get_db()
    conn.execute(
        "SELECT * FROM questions WHERE type='quiz' AND set_index=? ORDER BY sort_order",
        (set_index,)
    )
    rows = conn.fetchall()
    if not rows:
        return {"questions": [], "set_index": set_index}
    questions = [
        {
            "id": r["id"],
            "question": r["question"],
            "options": [r["option_a"], r["option_b"], r["option_c"], r["option_d"]],
            "correct": r["correct"],
            "topic": r["topic"] or "",
            "explanation": r["explanation"] or "",
        }
        for r in rows
    ]
    return {"questions": questions, "set_index": set_index}


@app.get("/mock-tests")
def get_mock_packs():
    """Return all mock test packs with question counts. Single SQL query (no N+1)."""
    conn = get_db()
    rows = conn.execute("""
        SELECT p.pack_id, p.title, p.subtitle, p.emoji, p.color_hex,
               p.is_pyq, p.sort_order,
               COALESCE(q.cnt, 0) AS question_count
        FROM mock_packs p
        LEFT JOIN (
            SELECT pack_id, COUNT(*) AS cnt
            FROM questions
            WHERE type = 'mock'
            GROUP BY pack_id
        ) q ON q.pack_id = p.pack_id
        ORDER BY p.is_pyq, p.sort_order
    """).fetchall()
    return {"packs": [{
        "pack_id":        r["pack_id"],
        "title":          r["title"],
        "subtitle":       r["subtitle"],
        "emoji":          r["emoji"],
        "color_hex":      r["color_hex"],
        "is_pyq":         bool(r["is_pyq"]),
        "sort_order":     r["sort_order"],
        "question_count": r["question_count"],
    } for r in rows]}


@app.get("/mock-tests/{pack_id}")
def get_mock_questions(pack_id: str):
    """Return all questions for a given mock test pack."""
    conn = get_db()
    conn.execute(
        "SELECT * FROM questions WHERE type='mock' AND pack_id=? ORDER BY sort_order",
        (pack_id,)
    )
    rows = conn.fetchall()
    questions = [
        {
            "id": r["id"],
            "question": r["question"],
            "options": [r["option_a"], r["option_b"], r["option_c"], r["option_d"]],
            "correct": r["correct"],
            "topic": r["topic"] or "",
            "explanation": r["explanation"] or "",
        }
        for r in rows
    ]
    return {"pack_id": pack_id, "questions": questions}


@app.get("/admin/quiz-stats")
def admin_quiz_stats(secret: str = Query(...)):
    """Return quiz question counts and max set_index — used by quiz scraper."""
    require_admin(secret)
    conn = get_db()
    max_row   = conn.execute("SELECT MAX(set_index) as m FROM questions WHERE type='quiz'").fetchone()
    total_row = conn.execute("SELECT COUNT(*) as c FROM questions WHERE type='quiz'").fetchone()
    mock_row  = conn.execute("SELECT COUNT(*) as c FROM questions WHERE type='mock'").fetchone()
    return {
        "max_set_index":       max_row["m"]   if max_row   else -1,
        "total_quiz":          total_row["c"] if total_row else 0,
        "total_mock":          mock_row["c"]  if mock_row  else 0,
    }


@app.post("/admin/questions")
def admin_add_questions(secret: str = Query(...), payload: dict = Body(...)):
    """Bulk-insert quiz/mock questions with deduplication by question text hash.
    payload = {"questions": [...], "next_set_index": <optional int>}
    """
    require_admin(secret)
    qs = payload.get("questions", [])
    # Caller may pass next_set_index to continue numbering from a known offset
    next_set = payload.get("next_set_index")
    conn = get_db()

    # If next_set_index not provided, auto-detect current max
    if next_set is None:
        max_row  = conn.execute("SELECT MAX(set_index) as m FROM questions WHERE type='quiz'").fetchone()
        next_set = (max_row["m"] or -1) + 1

    inserted = 0
    set_counter = next_set   # tracks current set bucket for quiz questions
    bucket_size = 0          # how many questions in current set bucket

    for q in qs:
        try:
            q_text = q.get("question", "")
            if not q_text:
                continue
            # Dedup hash — prevents re-inserting same question on daily runs
            q_hash = hashlib.md5(q_text.lower().strip().encode()).hexdigest()

            q_type     = q.get("type", "quiz")
            set_index  = q.get("set_index")

            # Auto-assign set_index for quiz questions where caller passed None
            if q_type == "quiz" and set_index is None:
                set_index = set_counter
                bucket_size += 1
                if bucket_size >= 5:   # 5 questions per daily-quiz set
                    set_counter += 1
                    bucket_size = 0

            conn.execute(
                """INSERT OR IGNORE INTO questions
                   (type, pack_id, set_index, question,
                    option_a, option_b, option_c, option_d,
                    correct, topic, explanation, sort_order, question_hash)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    q_type,
                    q.get("pack_id"),
                    set_index,
                    q_text,
                    q.get("option_a", ""), q.get("option_b", ""),
                    q.get("option_c", ""), q.get("option_d", ""),
                    q.get("correct", 0),
                    q.get("topic", ""),
                    q.get("explanation", ""),
                    q.get("sort_order", 0),
                    q_hash,
                )
            )
            # lastrowid is None when INSERT OR IGNORE skips a duplicate
            if conn.lastrowid:
                inserted += 1
        except Exception:
            pass
    return {"inserted": inserted, "total": len(qs)}


@app.post("/admin/mock-pack")
def admin_upsert_mock_pack(secret: str = Query(...), payload: MockPackIn = Body(...)):
    """Upsert a mock test pack definition."""
    require_admin(secret)
    conn = get_db()
    conn.execute(
        """INSERT OR REPLACE INTO mock_packs
           (pack_id, title, subtitle, emoji, color_hex, is_pyq, sort_order)
           VALUES (?,?,?,?,?,?,?)""",
        (payload.pack_id, payload.title, payload.subtitle, payload.emoji,
         payload.color_hex, int(payload.is_pyq), payload.sort_order)
    )
    return {"success": True, "pack_id": payload.pack_id}


@app.delete("/admin/questions/{q_type}")
def admin_clear_questions(q_type: str, secret: str = Query(...), pack_id: Optional[str] = Query(None)):
    """Delete questions by type ('quiz'/'mock') and optionally by pack_id."""
    require_admin(secret)
    conn = get_db()
    if pack_id:
        conn.execute("DELETE FROM questions WHERE type=? AND pack_id=?", (q_type, pack_id))
    else:
        conn.execute("DELETE FROM questions WHERE type=?", (q_type,))
    return {"success": True}


@app.post("/admin/scrape-quiz")
def trigger_quiz_scrape(secret: str = Query(...)):
    """Run the quiz scraper — fetches MCQs from GKToday, AffairsCloud, OpenTrivia, and PYQ files."""
    require_admin(secret)
    try:
        from quiz_scraper import run_quiz_scraper
        result = run_quiz_scraper()
        return {"success": True, **result}
    except Exception:
        log.exception("admin/scrape-quiz failed")
        raise HTTPException(status_code=500, detail="internal error")


# ─────────────────────────────────────────────────────────────────────────────
# EXAM CALENDAR
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/exam-calendar")
def get_exam_calendar(category: Optional[str] = Query(None)):
    """Return exam calendar entries, optionally filtered by category."""
    conn = get_db()
    if category:
        conn.execute(
            "SELECT * FROM exam_calendar WHERE category=? ORDER BY exam_date, notif_date",
            (category,)
        )
    else:
        conn.execute("SELECT * FROM exam_calendar ORDER BY exam_date, notif_date")
    rows = conn.fetchall()
    return {
        "exams": [
            {
                "id":           r["exam_id"],
                "name":         r["name"],
                "category":     r["category"],
                "emoji":        r["emoji"],
                "notif_date":   r["notif_date"] or None,
                "last_date":    r["last_date"] or None,
                "exam_date":    r["exam_date"] or None,
                "is_tentative": bool(r["is_tentative"]),
                "official_site": r["official_site"] or None,
            }
            for r in rows
        ]
    }


@app.post("/admin/seed-exam-calendar")
def seed_exam_calendar(secret: str = Query(...), payload: dict = Body(...)):
    """Bulk-upsert exam calendar entries. payload = {"exams": [...]}"""
    require_admin(secret)
    exams = payload.get("exams", [])
    inserted = 0
    for e in exams:
        try:
            get_db().execute(
                """INSERT OR REPLACE INTO exam_calendar
                   (exam_id, name, category, emoji, notif_date, last_date,
                    exam_date, is_tentative, official_site, updated_at)
                   VALUES (?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)""",
                (e["id"], e["name"], e.get("category","other"),
                 e.get("emoji","📅"), e.get("notif_date",""), e.get("last_date",""),
                 e.get("exam_date",""), int(e.get("is_tentative", False)),
                 e.get("official_site",""))
            )
            inserted += 1
        except Exception:
            log.exception("seed_exam_calendar row failed: %s", e.get("id"))
    return {"inserted": inserted, "total": len(exams)}


# ─────────────────────────────────────────────────────────────────────────────
# DEPARTMENT PROFILES
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/dept-profiles")
def get_dept_profiles(category: Optional[str] = Query(None)):
    """Return department profile cards, optionally filtered by category."""
    conn = get_db()
    if category:
        conn.execute(
            "SELECT * FROM dept_profiles WHERE category=? ORDER BY rating DESC, name",
            (category,)
        )
    else:
        conn.execute("SELECT * FROM dept_profiles ORDER BY rating DESC, name")
    rows = conn.fetchall()
    return {
        "depts": [
            {
                "id":             r["dept_id"],
                "name":           r["name"],
                "full_name":      r["full_name"],
                "emoji":          r["emoji"],
                "category":       r["category"],
                "color_hex":      r["color_hex"],
                "ministry":       r["ministry"],
                "hq":             r["hq"],
                "about":          r["about"],
                "roles":          _safe_json_loads(r["roles"], []),
                "salary":         r["salary"],
                "work_life":      r["work_life"],
                "perks":          _safe_json_loads(r["perks"], []),
                "promotion_path": r["promotion_path"],
                "best_for":       r["best_for"],
                "rating":         r["rating"],
            }
            for r in rows
        ]
    }


@app.post("/admin/seed-dept-profiles")
def seed_dept_profiles(secret: str = Query(...), payload: dict = Body(...)):
    """Bulk-upsert department profiles. payload = {"depts": [...]}"""
    require_admin(secret)
    depts = payload.get("depts", [])
    inserted = 0
    for d in depts:
        try:
            get_db().execute(
                """INSERT OR REPLACE INTO dept_profiles
                   (dept_id, name, full_name, emoji, category, color_hex,
                    ministry, hq, about, roles, salary, work_life, perks,
                    promotion_path, best_for, rating, updated_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)""",
                (d["id"], d["name"], d.get("full_name",""), d.get("emoji","🏛️"),
                 d.get("category","central"), d.get("color_hex","#1565C0"),
                 d.get("ministry",""), d.get("hq",""), d.get("about",""),
                 json.dumps(d.get("roles",[])), d.get("salary",""),
                 d.get("work_life",""), json.dumps(d.get("perks",[])),
                 d.get("promotion_path",""), d.get("best_for",""),
                 int(d.get("rating", 3)))
            )
            inserted += 1
        except Exception:
            log.exception("seed_dept_profiles row failed: %s", d.get("id"))
    return {"inserted": inserted, "total": len(depts)}


# ─────────────────────────────────────────────────────────────────────────────
# AI CAREER ROADMAP  (Gemini-powered, rewarded-ad gated in Flutter)
# ─────────────────────────────────────────────────────────────────────────────

class _RoadmapRequest(BaseModel):
    age:        int    = Field(22, ge=15, le=65)
    education:  str    = "Graduate"
    state:      str    = "Any"
    category:   str    = "General"
    exam_type:  str    = "Any"
    prep_level: str    = "Beginner"   # Beginner | Intermediate | Advanced

@app.post("/ai/career-roadmap")
def ai_career_roadmap(req: _RoadmapRequest):
    """Generate a personalized career roadmap using Gemini. Rate-limit: callers
    must show a rewarded ad before calling (enforced client-side)."""
    if not _gemini_available:
        raise HTTPException(status_code=503, detail="AI service unavailable")
    roadmap = _gemini.generate_career_roadmap({
        "age":        str(req.age),
        "education":  req.education,
        "state":      req.state,
        "category":   req.category,
        "exam_type":  req.exam_type,
        "prep_level": req.prep_level,
    })
    if roadmap is None:
        raise HTTPException(status_code=503, detail="AI service unavailable")
    return roadmap


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN: Generate quiz questions via Gemini and store them
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/admin/generate-quiz")
def admin_generate_quiz(
    secret:     str = Query(...),
    exam:       str = Query("General GK"),
    count:      int = Query(10, ge=5, le=50),
    difficulty: str = Query("medium"),
):
    """Call Gemini to generate fresh MCQ questions and store them in the DB.
    Run nightly via Cloud Scheduler to keep the question pool fresh."""
    require_admin(secret)
    if not _gemini_available:
        raise HTTPException(status_code=503, detail="AI service unavailable")
    questions = _gemini.generate_quiz_questions(exam=exam, count=count, difficulty=difficulty)
    if not questions:
        raise HTTPException(status_code=503, detail="Gemini returned no questions")

    # Determine next set_index to avoid collisions
    conn = get_db()
    max_row = conn.execute(
        "SELECT MAX(set_index) as m FROM questions WHERE type='quiz'"
    ).fetchone()
    next_idx = (max_row["m"] or -1) + 1 if max_row else 0

    # Split into sets of 5 questions each
    inserted_total = 0
    idx = next_idx
    for batch_start in range(0, len(questions), 5):
        batch = questions[batch_start:batch_start+5]
        for sort_order, q in enumerate(batch):
            q["set_index"]  = idx
            q["sort_order"] = sort_order
            import hashlib as _hlib
            q["question_hash"] = _hlib.md5(
                q["question"].lower().strip().encode()
            ).hexdigest()
        try:
            conn2 = get_db()
            for q in batch:
                conn2.execute(
                    """INSERT OR IGNORE INTO questions
                       (type, set_index, question, option_a, option_b, option_c,
                        option_d, correct, topic, explanation, sort_order, question_hash)
                       VALUES ('quiz',?,?,?,?,?,?,?,?,?,?,?)""",
                    (q["set_index"], q["question"], q["option_a"], q["option_b"],
                     q["option_c"], q["option_d"], q["correct"], q["topic"],
                     q["explanation"], q["sort_order"], q["question_hash"])
                )
                inserted_total += 1
        except Exception:
            log.exception("generate-quiz insert failed at set_index=%d", idx)
        idx += 1

    log.info("generate-quiz: inserted %d questions for exam=%s", inserted_total, exam)
    return {"inserted": inserted_total, "sets_added": idx - next_idx, "exam": exam}
