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
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            department  TEXT,
            source      TEXT,
            source_url  TEXT,
            category    TEXT,
            qualifications TEXT,
            vacancies   INTEGER DEFAULT 0,
            last_date   TEXT,
            states      TEXT,
            age_min     INTEGER DEFAULT 18,
            age_max     INTEGER DEFAULT 40,
            fee_general INTEGER DEFAULT 0,
            fee_obc     INTEGER DEFAULT 0,
            fee_sc_st   INTEGER DEFAULT 0,
            scraped_at  TEXT,
            is_active   INTEGER DEFAULT 1
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

        CREATE INDEX IF NOT EXISTS idx_jobs_category  ON jobs(category);
        CREATE INDEX IF NOT EXISTS idx_jobs_active    ON jobs(is_active);
        CREATE INDEX IF NOT EXISTS idx_saved_user     ON saved_jobs(user_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_jobs_url ON jobs(source_url)
    """)

init_db()

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

    jobs_raw = conn.execute("""
        SELECT * FROM jobs
        WHERE is_active = 1
        ORDER BY scraped_at DESC
        LIMIT 500
    """).fetchall()

    eligible_jobs = []
    for job in jobs_raw:
        job_quals  = json.loads(job["qualifications"] or '["graduate"]')
        job_states = json.loads(job["states"] or '["all"]')

        if not user_qualifies(user_education, job_quals):
            continue
        if user_age < job["age_min"] or user_age > job["age_max"]:
            continue
        if "all" not in job_states and user_state not in job_states:
            continue
        if user_job_types and job["category"] not in user_job_types:
            continue

        try:
            last_date = datetime.strptime(job["last_date"], "%d/%m/%Y")
            days_left = (last_date - datetime.now()).days
        except:
            days_left = 30

        if days_left < 0:
            continue

        if user_category == "general":
            fee = job["fee_general"]
        elif user_category == "obc":
            fee = job["fee_obc"]
        else:
            fee = job["fee_sc_st"]

        eligible_jobs.append({
            "id":         job["id"],
            "title":      job["title"],
            "department": job["department"],
            "source":     job["source"],
            "source_url": job["source_url"],
            "category":   job["category"],
            "vacancies":  job["vacancies"],
            "last_date":  job["last_date"],
            "days_left":  days_left,
            "urgency":    "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
            "fee":        fee,
            "is_free":    fee == 0,
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
    page_size: int = 20
):
    conn = get_db()
    jobs = conn.execute("""
        SELECT * FROM jobs
        WHERE is_active = 1
        AND (title LIKE ? OR department LIKE ? OR category LIKE ?)
        ORDER BY scraped_at DESC
        LIMIT ? OFFSET ?
    """, (f"%{q}%", f"%{q}%", f"%{q}%", page_size, (page - 1) * page_size)).fetchall()

    return {"jobs": [dict(j) for j in jobs], "query": q}


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
        "scraped_at":     job["scraped_at"],
        "documents_needed": [
            "Aadhar Card",
            "10th Marksheet",
            "12th Marksheet (if required)",
            "Graduation Certificate (if required)",
            "Caste Certificate (OBC/SC/ST ke liye)",
            "Passport Size Photo (recent)",
            "Signature scan",
            "Bank Account details",
        ]
    }


@app.post("/jobs/save")
def save_job(req: SaveJobRequest):
    conn = get_db()
    conn.execute("""
        INSERT OR REPLACE INTO saved_jobs (user_id, job_id, status)
        VALUES (?, ?, ?)
    """, (req.user_id, req.job_id, req.status))
    return {"success": True}


@app.get("/users/{user_id}/saved")
def get_saved_jobs(user_id: int):
    conn = get_db()
    rows = conn.execute("""
        SELECT j.*, s.status, s.saved_at
        FROM saved_jobs s
        JOIN jobs j ON s.job_id = j.id
        WHERE s.user_id = ?
        ORDER BY s.saved_at DESC
    """, (user_id,)).fetchall()
    return {"saved_jobs": [dict(r) for r in rows]}


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
                     age_min, age_max, fee_general, fee_obc, fee_sc_st, scraped_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, (
                    job["title"], job["department"], job["source"],
                    job["source_url"], job["category"],
                    json.dumps(job["qualifications"]),
                    job["vacancies"], job["last_date"],
                    json.dumps(job["states"]),
                    job["age_min"], job["age_max"],
                    job["fee_general"], job["fee_obc"], job["fee_sc_st"],
                    job["scraped_at"]
                ))
                inserted += 1
            except:
                pass
        return {"success": True, "jobs_inserted": inserted}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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
                     age_min, age_max, fee_general, fee_obc, fee_sc_st, scraped_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, (
                    job["title"], job["department"], job["source"],
                    job["source_url"], job["category"],
                    json.dumps(job["qualifications"]),
                    job["vacancies"], job["last_date"],
                    json.dumps(job["states"]),
                    job["age_min"], job["age_max"],
                    job["fee_general"], job["fee_obc"], job["fee_sc_st"],
                    job["scraped_at"]
                ))
                inserted += 1
            except:
                pass
        return {"success": True, "jobs_inserted": inserted}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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
                 age_min, age_max, fee_general, fee_obc, fee_sc_st, scraped_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                job.get("title", ""), job.get("department", ""),
                job.get("source", ""), job.get("source_url", ""),
                job.get("category", "others"),
                json.dumps(job.get("qualifications", ["graduate"])),
                job.get("vacancies", 0), job.get("last_date", ""),
                json.dumps(job.get("states", ["all"])),
                job.get("age_min", 18), job.get("age_max", 40),
                job.get("fee_general", 100), job.get("fee_obc", 100),
                job.get("fee_sc_st", 0), job.get("scraped_at", "")
            ))
            inserted += 1
        except:
            pass
    return {"inserted": inserted, "total": len(jobs)}
