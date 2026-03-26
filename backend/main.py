"""
JobMitra - FastAPI Backend
Deploy on Render.com (free tier)
DB: Turso (libsql cloud) — persistent across deploys
"""

from fastapi import FastAPI, HTTPException, Query, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import json
import os
import base64
import requests as _requests
from datetime import datetime, timedelta

app = FastAPI(title="JobMitra API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

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
        r = _requests.post(
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
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            type         TEXT NOT NULL DEFAULT 'quiz',
            pack_id      TEXT DEFAULT NULL,
            set_index    INTEGER DEFAULT NULL,
            question     TEXT NOT NULL,
            option_a     TEXT NOT NULL,
            option_b     TEXT NOT NULL,
            option_c     TEXT NOT NULL,
            option_d     TEXT NOT NULL,
            correct      INTEGER NOT NULL,
            topic        TEXT DEFAULT '',
            sort_order   INTEGER DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_jobs_category  ON jobs(category);
        CREATE INDEX IF NOT EXISTS idx_jobs_active    ON jobs(is_active);
        CREATE INDEX IF NOT EXISTS idx_saved_user     ON saved_jobs(user_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_jobs_url ON jobs(source_url);
        CREATE INDEX IF NOT EXISTS idx_ca_date        ON current_affairs(pub_date);
        CREATE INDEX IF NOT EXISTS idx_ca_category    ON current_affairs(category);
        CREATE INDEX IF NOT EXISTS idx_q_type         ON questions(type);
        CREATE INDEX IF NOT EXISTS idx_q_pack         ON questions(pack_id);
        CREATE INDEX IF NOT EXISTS idx_q_set          ON questions(set_index)
    """)

init_db()

# ── Schema migration: safely add new columns to existing Turso DB ──
# These ALTER TABLE calls fail silently if the column already exists.
_MIGRATIONS = [
    "ALTER TABLE jobs ADD COLUMN pay_scale TEXT DEFAULT ''",
    "ALTER TABLE jobs ADD COLUMN pay_level INTEGER DEFAULT 0",
    "ALTER TABLE jobs ADD COLUMN grade_pay INTEGER DEFAULT 0",
    "ALTER TABLE jobs ADD COLUMN notification_type TEXT DEFAULT 'new'",
    "ALTER TABLE jobs ADD COLUMN application_mode TEXT DEFAULT 'online'",
    "ALTER TABLE jobs ADD COLUMN trust_score INTEGER DEFAULT 5",
    "ALTER TABLE jobs ADD COLUMN published_at TEXT DEFAULT ''",
    "ALTER TABLE jobs ADD COLUMN description TEXT DEFAULT ''",
]
for _sql in _MIGRATIONS:
    try:
        get_db().execute(_sql)
    except Exception:
        pass

# ─────────────────────────────────────────
# MODELS
# ─────────────────────────────────────────
class UserProfile(BaseModel):
    fcm_token:  str
    state:      str
    education:  str
    category:   str
    age:        int
    job_types:  list[str]
    language:   str = "hinglish"

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
    Get OAuth2 access token for FCM v1 API.
    Requires FIREBASE_CREDENTIALS_B64 env var — base64-encoded service account JSON.
    Get it: Firebase Console → Project Settings → Service accounts → Generate new private key
    Then: base64 -w0 serviceAccountKey.json
    """
    creds_b64 = os.getenv("FIREBASE_CREDENTIALS_B64", "")
    if not creds_b64:
        return None
    try:
        creds_json = json.loads(base64.b64decode(creds_b64).decode())
        # Use google-auth to get access token
        import google.oauth2.service_account as sa
        import google.auth.transport.requests as ga_requests
        credentials = sa.Credentials.from_service_account_info(
            creds_json,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
        credentials.refresh(ga_requests.Request())
        return credentials.token
    except Exception as e:
        print(f"FCM token error: {e}")
        return None


def send_fcm_to_tokens(tokens: list[str], title: str, body: str, data: dict = None) -> int:
    """
    Send FCM notification to a list of FCM tokens via HTTP v1 API.
    Returns number of successful sends.
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

    sent = 0
    for token in tokens:
        if not token or token == "test":
            continue
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
                "data": {k: str(v) for k, v in (data or {}).items()},
            }
        }
        try:
            r = _requests.post(url, headers=headers, json=payload, timeout=10)
            if r.status_code == 200:
                sent += 1
        except Exception:
            pass
    return sent


def notify_users_new_jobs(conn, new_count: int, categories: list[str]):
    """Send push notification to all users with valid FCM tokens."""
    if new_count == 0:
        return 0
    tokens = [
        row["fcm_token"]
        for row in conn.execute(
            "SELECT fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != 'test'"
        ).fetchall()
        if row["fcm_token"]
    ]
    if not tokens:
        return 0

    # Build a catchy body
    cat_str = ", ".join(categories[:3]) if categories else "Govt"
    if len(categories) > 3:
        cat_str += f" +{len(categories)-3} more"
    body = f"{new_count} nai sarkari jobs: {cat_str}"

    return send_fcm_to_tokens(
        tokens,
        title="🇮🇳 JobMitra — Nai Jobs Aayi!",
        body=body,
        data={"screen": "home"},
    )


# ─────────────────────────────────────────
# ROUTES
# ─────────────────────────────────────────

@app.get("/")
def root():
    return {"message": "JobMitra API v1.0 🇮🇳", "status": "running"}


@app.post("/users/register")
def register_user(profile: UserProfile):
    conn = get_db()
    existing = conn.execute(
        "SELECT id FROM users WHERE fcm_token = ?", (profile.fcm_token,)
    ).fetchone()

    if existing:
        conn.execute("""
            UPDATE users SET state=?, education=?, category=?, age=?,
            job_types=?, language=? WHERE fcm_token=?
        """, (
            profile.state, profile.education, profile.category,
            profile.age, json.dumps(profile.job_types),
            profile.language, profile.fcm_token
        ))
        user_id = existing["id"]
    else:
        conn.execute("""
            INSERT INTO users (fcm_token, state, education, category, age, job_types, language)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            profile.fcm_token, profile.state, profile.education,
            profile.category, profile.age,
            json.dumps(profile.job_types), profile.language
        ))
        user_id = conn.lastrowid

    return {"success": True, "user_id": user_id}


@app.get("/jobs/feed")
def get_job_feed(user_id: int, page: int = 1, page_size: int = 20):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user_state     = user["state"]
    user_education = user["education"]
    user_category  = user["category"]
    user_age       = user["age"]
    user_job_types = json.loads(user["job_types"] or "[]")

    # Push age filter and optional category filter to SQL — reduces rows Python processes
    cat_filter = ""
    cat_params: list = [user_age, user_age]
    if user_job_types:
        placeholders = ",".join("?" * len(user_job_types))
        cat_filter = f"AND category IN ({placeholders})"
        cat_params += user_job_types

    jobs_raw = conn.execute(f"""
        SELECT * FROM jobs
        WHERE is_active = 1
          AND age_min <= ? AND age_max >= ?
          {cat_filter}
        ORDER BY scraped_at DESC
        LIMIT 300
    """, cat_params).fetchall()

    today = datetime.now()
    eligible_jobs = []
    for job in jobs_raw:
        job_states = json.loads(job["states"] or '["all"]')
        if "all" not in job_states and user_state.lower() not in [s.lower() for s in job_states]:
            continue

        job_quals = json.loads(job["qualifications"] or '["graduate"]')
        if not user_qualifies(user_education, job_quals):
            continue

        try:
            last_date = datetime.strptime(job["last_date"], "%d/%m/%Y")
            days_left = (last_date - today).days
        except:
            days_left = 30

        if days_left < 0:
            continue

        if user_category == "obc":
            fee = job["fee_obc"]
        elif user_category in ("sc", "st"):
            fee = job["fee_sc_st"]
        else:
            fee = job["fee_general"]

        eligible_jobs.append({
            "id":             job["id"],
            "title":          job["title"],
            "department":     job["department"],
            "source":         job["source"],
            "source_url":     job["source_url"],
            "category":       job["category"],
            "vacancies":      job["vacancies"],
            "last_date":      job["last_date"],
            "days_left":      days_left,
            "urgency":        "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
            "fee":            fee,
            "is_free":        fee == 0,
            "qualifications": job_quals,
            "states":         json.loads(job["states"] or '["all"]'),
            "age_min":        job["age_min"],
            "age_max":        job["age_max"],
            "pay_scale":      job["pay_scale"] or "",
        })

    eligible_jobs.sort(key=lambda x: (x["days_left"], -x["vacancies"]))

    total = len(eligible_jobs)
    start = (page - 1) * page_size
    end   = start + page_size

    return {
        "total":    total,
        "page":     page,
        "jobs":     eligible_jobs[start:end],
        "has_more": end < total,
    }


@app.get("/jobs/search")
def search_jobs(
    q:         str = Query(..., min_length=2),
    page:      int = 1,
    page_size: int = 20,
    user_category: str = "general",
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
        except:
            days_left = 30

        if days_left < 0:
            continue

        if user_category == "obc":
            fee = job["fee_obc"]
        elif user_category in ("sc", "st"):
            fee = job["fee_sc_st"]
        else:
            fee = job["fee_general"]

        results.append({
            "id":             job["id"],
            "title":          job["title"],
            "department":     job["department"],
            "source":         job["source"],
            "source_url":     job["source_url"],
            "category":       job["category"],
            "vacancies":      job["vacancies"],
            "last_date":      job["last_date"],
            "days_left":      days_left,
            "urgency":        "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
            "fee":            fee,
            "is_free":        fee == 0,
            "qualifications": json.loads(job["qualifications"] or "[]"),
            "states":         json.loads(job["states"] or '["all"]'),
            "age_min":        job["age_min"],
            "age_max":        job["age_max"],
            "pay_scale":      job["pay_scale"] or "",
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
    except:
        days_left = 30

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
        "qualifications": json.loads(job["qualifications"] or "[]"),
        "vacancies":      job["vacancies"],
        "last_date":      job["last_date"],
        "days_left":      days_left,
        "urgency":        "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
        "age_min":        job["age_min"],
        "age_max":        job["age_max"],
        "fee":            fee,
        "is_free":        fee == 0,
        "states":         json.loads(job["states"] or '["all"]'),
        "pay_scale":      job["pay_scale"] or "",
        "scraped_at":     job["scraped_at"],
    }


@app.post("/jobs/save")
def save_job(req: SaveJobRequest):
    conn = get_db()
    # saved_jobs has no unique(user_id,job_id) constraint, so INSERT OR REPLACE
    # would always insert a new row — instead, upsert manually.
    existing = conn.execute(
        "SELECT id FROM saved_jobs WHERE user_id=? AND job_id=? LIMIT 1",
        (req.user_id, req.job_id)
    ).fetchone()
    if existing:
        conn.execute(
            "UPDATE saved_jobs SET status=?, saved_at=CURRENT_TIMESTAMP WHERE id=?",
            (req.status, existing["id"])
        )
    else:
        conn.execute(
            "INSERT INTO saved_jobs (user_id, job_id, status) VALUES (?, ?, ?)",
            (req.user_id, req.job_id, req.status)
        )
    return {"success": True}


@app.get("/users/{user_id}/saved")
def get_saved_jobs(user_id: int, user_category: str = "general"):
    conn = get_db()
    user = conn.execute("SELECT category FROM users WHERE id=?", (user_id,)).fetchone()
    cat = (user["category"] if user else None) or user_category

    rows = conn.execute("""
        SELECT j.*, s.status, s.saved_at
        FROM saved_jobs s
        JOIN jobs j ON s.job_id = j.id
        WHERE s.user_id = ?
          AND s.status != 'unsaved'
          AND s.id = (
              SELECT MAX(id) FROM saved_jobs
              WHERE user_id = s.user_id AND job_id = s.job_id
          )
        ORDER BY s.saved_at DESC
    """, (user_id,)).fetchall()

    results = []
    for row in rows:
        try:
            ld = datetime.strptime(row["last_date"], "%d/%m/%Y")
            days_left = (ld - datetime.now()).days
        except:
            days_left = 30

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
def get_stats():
    conn = get_db()
    total_jobs  = conn.execute("SELECT COUNT(*) as c FROM jobs WHERE is_active=1").fetchone()["c"]
    total_users = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()["c"]
    by_category = conn.execute("""
        SELECT category, COUNT(*) as count
        FROM jobs WHERE is_active=1
        GROUP BY category ORDER BY count DESC
    """).fetchall()
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
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    conn = get_db()
    conn.execute("UPDATE jobs SET fee_general=0, fee_obc=0, fee_sc_st=0 WHERE fee_general=100")
    return {"success": True, "message": "All fee_general=100 rows reset to 0"}


@app.post("/admin/scrape")
def trigger_scrape(secret: str = Query(...)):
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    try:
        from scraper import run_all as run_all_scrapers
        jobs = run_all_scrapers()
        conn = get_db()
        inserted = 0
        for job in jobs:
            try:
                conn.execute("""
                    INSERT OR IGNORE INTO jobs
                    (title, department, source, source_url, category,
                     qualifications, vacancies, last_date, states,
                     age_min, age_max, fee_general, fee_obc, fee_sc_st,
                     pay_scale, pay_level, grade_pay,
                     notification_type, application_mode, trust_score,
                     published_at, description, scraped_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
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
                    job["scraped_at"]
                ))
                inserted += 1
            except:
                pass
        # Auto-expire jobs past their last_date
        expired = 0
        all_jobs = conn.execute("SELECT id, last_date FROM jobs WHERE is_active=1").fetchall()
        today = datetime.now().strftime("%d/%m/%Y")
        for j in all_jobs:
            try:
                ld = datetime.strptime(j["last_date"], "%d/%m/%Y")
                if (ld - datetime.now()).days < 0:
                    conn.execute("UPDATE jobs SET is_active=0 WHERE id=?", (j["id"],))
                    expired += 1
            except:
                pass
        # Send push notifications about new jobs
        notified = 0
        if inserted > 0:
            try:
                new_cats = list({j["category"] for j in jobs})
                notified = notify_users_new_jobs(conn, inserted, new_cats)
            except Exception:
                pass
        return {"success": True, "jobs_inserted": inserted, "jobs_expired": expired, "notified": notified}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/admin/notify")
def manual_notify(secret: str = Query(...), title: str = Query("🇮🇳 JobMitra"), body: str = Query(...)):
    """Manually send a push notification to all users. For testing."""
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
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


@app.post("/admin/reset_jobs")
def reset_jobs(secret: str = Query(...)):
    """Delete all jobs and re-scrape fresh — fixes duplicates"""
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    try:
        conn = get_db()
        conn.execute("DELETE FROM jobs")
        from scraper import run_all as run_all_scrapers
        jobs = run_all_scrapers()
        inserted = 0
        for job in jobs:
            try:
                conn.execute("""
                    INSERT OR IGNORE INTO jobs
                    (title, department, source, source_url, category,
                     qualifications, vacancies, last_date, states,
                     age_min, age_max, fee_general, fee_obc, fee_sc_st,
                     pay_scale, pay_level, grade_pay,
                     notification_type, application_mode, trust_score,
                     published_at, description, scraped_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
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
                    job["scraped_at"]
                ))
                inserted += 1
            except:
                pass
        return {"success": True, "jobs_inserted": inserted}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/current-affairs")
def get_current_affairs(
    days: int = Query(7, ge=1, le=30),
    category: Optional[str] = Query(None),
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
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
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
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/admin/import-ca")
def import_current_affairs(secret: str = Query(...), payload: dict = Body(...)):
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
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


@app.post("/admin/bulk_import")
def bulk_import(secret: str = Query(...), payload: dict = Body(...)):
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    jobs = payload.get("jobs", [])
    conn = get_db()
    inserted = 0
    for job in jobs:
        try:
            conn.execute("""
                INSERT OR IGNORE INTO jobs
                (title, department, source, source_url, category,
                 qualifications, vacancies, last_date, states,
                 age_min, age_max, fee_general, fee_obc, fee_sc_st,
                 pay_scale, pay_level, grade_pay,
                 notification_type, application_mode, trust_score,
                 published_at, description, scraped_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
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
                job.get("scraped_at", "")
            ))
            inserted += 1
        except:
            pass
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
            "topic": r["topic"],
        }
        for r in rows
    ]
    return {"questions": questions, "set_index": set_index}


@app.get("/mock-tests")
def get_mock_packs():
    """Return all mock test packs with question counts."""
    conn = get_db()
    conn.execute("SELECT * FROM mock_packs ORDER BY is_pyq, sort_order")
    packs = conn.fetchall()
    result = []
    for p in packs:
        conn.execute(
            "SELECT COUNT(*) as cnt FROM questions WHERE type='mock' AND pack_id=?",
            (p["pack_id"],)
        )
        cnt_row = conn.fetchone()
        cnt = cnt_row["cnt"] if cnt_row else 0
        result.append({
            "pack_id":    p["pack_id"],
            "title":      p["title"],
            "subtitle":   p["subtitle"],
            "emoji":      p["emoji"],
            "color_hex":  p["color_hex"],
            "is_pyq":     bool(p["is_pyq"]),
            "sort_order": p["sort_order"],
            "question_count": cnt,
        })
    return {"packs": result}


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
            "topic": r["topic"],
        }
        for r in rows
    ]
    return {"pack_id": pack_id, "questions": questions}


@app.post("/admin/questions")
def admin_add_questions(secret: str = Query(...), payload: dict = Body(...)):
    """Bulk-insert quiz/mock questions. payload = {"questions": [...]}"""
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    qs = payload.get("questions", [])
    conn = get_db()
    inserted = 0
    for q in qs:
        try:
            conn.execute(
                """INSERT INTO questions
                   (type, pack_id, set_index, question,
                    option_a, option_b, option_c, option_d,
                    correct, topic, sort_order)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    q.get("type", "quiz"),
                    q.get("pack_id"),
                    q.get("set_index"),
                    q["question"],
                    q["option_a"], q["option_b"], q["option_c"], q["option_d"],
                    q["correct"],
                    q.get("topic", ""),
                    q.get("sort_order", 0),
                )
            )
            inserted += 1
        except Exception:
            pass
    return {"inserted": inserted, "total": len(qs)}


@app.post("/admin/mock-pack")
def admin_upsert_mock_pack(secret: str = Query(...), payload: MockPackIn = Body(...)):
    """Upsert a mock test pack definition."""
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
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
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    conn = get_db()
    if pack_id:
        conn.execute("DELETE FROM questions WHERE type=? AND pack_id=?", (q_type, pack_id))
    else:
        conn.execute("DELETE FROM questions WHERE type=?", (q_type,))
    return {"success": True}
