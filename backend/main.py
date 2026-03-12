"""
JobMitra - FastAPI Backend
Deploy on Render.com (free tier)
"""

from fastapi import FastAPI, HTTPException, Query, Body, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import sqlite3
import json
from datetime import datetime, timedelta
import os

app = FastAPI(title="JobMitra API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = os.getenv("DB_PATH", "jobmitra.db")

# ─────────────────────────────────────────
# DATABASE SETUP
# ─────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

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
            qualifications TEXT,   -- JSON array: ["10th","12th"]
            vacancies   INTEGER DEFAULT 0,
            last_date   TEXT,
            states      TEXT,      -- JSON array: ["UP","Bihar"] or ["all"]
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
            category        TEXT,      -- general/obc/sc/st
            age             INTEGER,
            job_types       TEXT,      -- JSON array of interested categories
            language        TEXT DEFAULT 'hinglish',
            created_at      TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS saved_jobs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER,
            job_id      INTEGER,
            status      TEXT DEFAULT 'saved', -- saved/applied/exam_scheduled
            saved_at    TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id),
            FOREIGN KEY(job_id)  REFERENCES jobs(id)
        );

        CREATE INDEX IF NOT EXISTS idx_jobs_category  ON jobs(category);
        CREATE INDEX IF NOT EXISTS idx_jobs_active    ON jobs(is_active);
        CREATE INDEX IF NOT EXISTS idx_saved_user     ON saved_jobs(user_id);
    """)
    conn.commit()
    conn.close()

init_db()

# ─────────────────────────────────────────
# MODELS
# ─────────────────────────────────────────
class UserProfile(BaseModel):
    fcm_token:  str
    state:      str
    education:  str       # 8th/10th/12th/diploma/graduate/postgraduate
    category:   str       # general/obc/sc/st
    age:        int
    job_types:  list[str] # ["railway","banking","ssc"]
    language:   str = "hinglish"

class SaveJobRequest(BaseModel):
    user_id: int
    job_id:  int
    status:  str = "saved"

# ─────────────────────────────────────────
# EDUCATION HIERARCHY — for smart filtering
# ─────────────────────────────────────────
EDUCATION_LEVELS = {
    "8th": 1, "10th": 2, "12th": 3,
    "diploma": 3, "graduate": 4, "postgraduate": 5
}

def user_qualifies(user_education: str, job_qualifications: list) -> bool:
    """Returns True if user's education meets job requirement"""
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
    """Register or update user profile"""
    conn = get_db()
    try:
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
            cur = conn.execute("""
                INSERT INTO users (fcm_token, state, education, category, age, job_types, language)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                profile.fcm_token, profile.state, profile.education,
                profile.category, profile.age,
                json.dumps(profile.job_types), profile.language
            ))
            user_id = cur.lastrowid

        conn.commit()
        return {"success": True, "user_id": user_id}
    finally:
        conn.close()


@app.get("/jobs/feed")
def get_job_feed(
    user_id:   int,
    page:      int = 1,
    page_size: int = 20
):
    """
    Smart filtered job feed for a specific user.
    Returns only jobs the user is eligible for.
    """
    conn = get_db()
    try:
        user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_state     = user["state"]
        user_education = user["education"]
        user_category  = user["category"]
        user_age       = user["age"]
        user_job_types = json.loads(user["job_types"] or "[]")

        # Get all active jobs
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
            job_types_list = [job["category"]]

            # Filter 1: Qualification check
            if not user_qualifies(user_education, job_quals):
                continue

            # Filter 2: Age check
            if user_age < job["age_min"] or user_age > job["age_max"]:
                continue

            # Filter 3: State check
            if "all" not in job_states and user_state not in job_states:
                continue

            # Filter 4: Job type preference
            if user_job_types and job["category"] not in user_job_types:
                continue

            # Calculate days remaining
            try:
                last_date = datetime.strptime(job["last_date"], "%d/%m/%Y")
                days_left = (last_date - datetime.now()).days
            except:
                days_left = 30

            if days_left < 0:
                continue  # Expired

            # Fee for this user's category
            if user_category == "general":
                fee = job["fee_general"]
            elif user_category == "obc":
                fee = job["fee_obc"]
            else:
                fee = job["fee_sc_st"]

            eligible_jobs.append({
                "id":          job["id"],
                "title":       job["title"],
                "department":  job["department"],
                "source":      job["source"],
                "source_url":  job["source_url"],
                "category":    job["category"],
                "vacancies":   job["vacancies"],
                "last_date":   job["last_date"],
                "days_left":   days_left,
                "urgency":     "red" if days_left <= 7 else ("yellow" if days_left <= 14 else "green"),
                "fee":         fee,
                "is_free":     fee == 0,
            })

        # Sort: urgent first, then by vacancies
        eligible_jobs.sort(key=lambda x: (x["days_left"], -x["vacancies"]))

        # Paginate
        total  = len(eligible_jobs)
        start  = (page - 1) * page_size
        end    = start + page_size

        return {
            "total":    total,
            "page":     page,
            "jobs":     eligible_jobs[start:end],
            "has_more": end < total,
        }
    finally:
        conn.close()


@app.get("/jobs/{job_id}")
def get_job_detail(job_id: int, user_category: str = "general"):
    """Full job detail with user-specific fee"""
    conn = get_db()
    try:
        job = conn.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        try:
            last_date = datetime.strptime(job["last_date"], "%d/%m/%Y")
            days_left = (last_date - datetime.now()).days
        except:
            days_left = 30

        fee = job["fee_general"]
        if user_category == "obc":   fee = job["fee_obc"]
        elif user_category in ("sc", "st"): fee = job["fee_sc_st"]

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
            # Documents checklist (standard)
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
    finally:
        conn.close()


@app.get("/jobs/search")
def search_jobs(
    q:         str = Query(..., min_length=2),
    page:      int = 1,
    page_size: int = 20
):
    """Search jobs by keyword"""
    conn = get_db()
    try:
        jobs = conn.execute("""
            SELECT * FROM jobs
            WHERE is_active = 1
            AND (title LIKE ? OR department LIKE ? OR category LIKE ?)
            ORDER BY scraped_at DESC
            LIMIT ? OFFSET ?
        """, (f"%{q}%", f"%{q}%", f"%{q}%", page_size, (page-1)*page_size)).fetchall()

        return {"jobs": [dict(j) for j in jobs], "query": q}
    finally:
        conn.close()


@app.post("/jobs/save")
def save_job(req: SaveJobRequest):
    """Save a job to user's list"""
    conn = get_db()
    try:
        conn.execute("""
            INSERT OR REPLACE INTO saved_jobs (user_id, job_id, status)
            VALUES (?, ?, ?)
        """, (req.user_id, req.job_id, req.status))
        conn.commit()
        return {"success": True}
    finally:
        conn.close()


@app.get("/users/{user_id}/saved")
def get_saved_jobs(user_id: int):
    """Get user's saved/applied jobs"""
    conn = get_db()
    try:
        rows = conn.execute("""
            SELECT j.*, s.status, s.saved_at
            FROM saved_jobs s
            JOIN jobs j ON s.job_id = j.id
            WHERE s.user_id = ?
            ORDER BY s.saved_at DESC
        """, (user_id,)).fetchall()

        return {"saved_jobs": [dict(r) for r in rows]}
    finally:
        conn.close()


@app.get("/stats")
def get_stats():
    """App statistics — show on home screen"""
    conn = get_db()
    try:
        total_jobs    = conn.execute("SELECT COUNT(*) as c FROM jobs WHERE is_active=1").fetchone()["c"]
        total_users   = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()["c"]
        by_category   = conn.execute("""
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
    finally:
        conn.close()


# ─────────────────────────────────────────
# SCRAPER TRIGGER (call from cron)
# ─────────────────────────────────────────
@app.post("/admin/scrape")
def trigger_scrape(secret: str = Query(...)):
    """Trigger scraper — protected by secret key"""
    if secret != os.getenv("SCRAPER_SECRET", "jobmitra_secret_2024"):
        raise HTTPException(status_code=403, detail="Unauthorized")

    try:
        import sys
        
        from scraper import run_all as run_all_scrapers  # local copy

        jobs = run_all_scrapers()
        conn = get_db()

        inserted = 0
        for job in jobs:
            try:
                conn.execute("""
                    INSERT INTO jobs
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

        conn.commit()
        conn.close()

        return {"success": True, "jobs_inserted": inserted}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ─────────────────────────────────────────
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
                job.get("title",""), job.get("department",""),
                job.get("source",""), job.get("source_url",""),
                job.get("category","others"),
                json.dumps(job.get("qualifications",["graduate"])),
                job.get("vacancies",0), job.get("last_date",""),
                json.dumps(job.get("states",["all"])),
                job.get("age_min",18), job.get("age_max",40),
                job.get("fee_general",100), job.get("fee_obc",100),
                job.get("fee_sc_st",0), job.get("scraped_at","")
            ))
            inserted += 1
        except: pass
    conn.commit()
    conn.close()
    return {"inserted": inserted, "total": len(jobs)}
