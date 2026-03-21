# JobMitra — Complete Project Context for Claude

## Project Overview
JobMitra ek Indian government job (Sarkari Naukri) aggregator app hai.
- **Backend**: FastAPI + SQLite, deployed on Render.com
- **Frontend**: Flutter Android app
- **Scraper**: Python multi-source RSS + direct scraper
- **GitHub**: https://github.com/buhtig47/jobmitra
- **Live API**: https://jobmitra-api.onrender.com
- **Local path**: ~/jobmitra/

---

## Project Structure
```
jobmitra/
├── backend/
│   ├── main.py          ← FastAPI app
│   ├── scraper.py       ← Copy of scraper (for Render)
│   ├── requirements.txt
│   ├── render.yaml
│   └── .python-version  ← "3.11.8" (important!)
├── scraper/
│   └── scraper.py       ← Main scraper v8, run_all() is entry point
└── flutter_app/
    └── lib/
        ├── main.dart
        ├── models/job_model.dart
        ├── services/api_service.dart
        ├── utils/constants.dart      ← kApiBase URL here
        ├── screens/
        │   ├── home_screen.dart
        │   ├── job_detail_screen.dart
        │   ├── onboarding_screen.dart
        │   ├── search_screen.dart
        │   └── saved_jobs_screen.dart
        └── widgets/job_card.dart
```

---

## Current Issues to Fix

### 🔴 Critical — Jobs Not Showing
- App shows "0 jobs" despite cloud having 269 jobs
- Root cause: `/jobs/feed?user_id=X` returns empty — backend filtering too strict
- Fix: Loosen qualification/state filtering in main.py feed endpoint
- Also: Free tier Render spins down — first request takes 50+ seconds

### 🔴 UI Issues
- Shimmer loading shows blank white cards (no animation)
- Job cards load but take too long (Render cold start)
- Search screen works but no trending searches shown
- AppBar is basic — needs stats (today's new jobs count)

### 🟡 Scraper Issues  
- Only ~270 jobs from ~86 sources — many sources dead
- Need to add: freejobalert.com, bharatnaukri.com, govtjobsdiary.com
- `run_all_scrapers` was wrong name — correct is `run_all()`
- Hindi titles from rojgar_result2 show garbled text (encoding issue)

---

## Backend API Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users/register` | Register user |
| GET | `/jobs/feed?user_id=1` | Filtered job feed |
| GET | `/jobs/{id}` | Job detail |
| GET | `/jobs/search?q=railway` | Search |
| POST | `/jobs/save` | Save job |
| GET | `/users/{id}/saved` | Saved jobs |
| GET | `/stats` | App stats |
| POST | `/admin/scrape?secret=` | Trigger scraper |
| POST | `/admin/bulk_import?secret=` | Import JSON jobs |

**Scraper Secret**: `jobmitra_secret_2024`

---

## DB Schema (SQLite)
```sql
CREATE TABLE jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    department TEXT,
    source TEXT,
    source_url TEXT,
    category TEXT,
    qualifications TEXT,  -- JSON array
    vacancies INTEGER DEFAULT 0,
    last_date TEXT,
    states TEXT,          -- JSON array
    age_min INTEGER DEFAULT 18,
    age_max INTEGER DEFAULT 40,
    fee_general INTEGER DEFAULT 0,
    fee_obc INTEGER DEFAULT 0,
    fee_sc_st INTEGER DEFAULT 0,
    scraped_at TEXT,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fcm_token TEXT UNIQUE,
    state TEXT DEFAULT 'all',
    education TEXT DEFAULT 'graduate',
    category TEXT DEFAULT 'general',
    age INTEGER DEFAULT 25,
    job_types TEXT,       -- JSON array
    language TEXT DEFAULT 'hinglish',
    created_at TEXT
);
```

---

## Flutter App — Key Files

### constants.dart — Colors & API
```dart
const String kApiBase = "https://jobmitra-api.onrender.com";

class AppColors {
  static const primary = Color(0xFF1A6B3C);   // India Green
  static const accent  = Color(0xFFFF9933);   // Saffron
  static const background = Color(0xFFF5F7F5);
}
```

### Job Model fields
- id, title, department, source, sourceUrl
- category, vacancies, lastDate, daysLeft
- urgency (green/yellow/red), fee, isFree
- qualifications, states, ageMin, ageMax

---

## Render Deployment
- **URL**: https://jobmitra-api.onrender.com
- **Plan**: Free (spins down after inactivity)
- **Python**: 3.11.8 (pinned via .python-version)
- **Root dir**: backend/
- **Start**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Env vars**: SCRAPER_SECRET=jobmitra_secret_2024
- **Note**: No persistent disk on free tier — DB resets on redeploy!

### To redeploy after changes:
```bash
cd ~/jobmitra
git add .
git commit -m "your message"
git push
# Render auto-deploys from main branch
```

### To import jobs after Render reset:
```bash
curl -X POST "https://jobmitra-api.onrender.com/admin/scrape?secret=jobmitra_secret_2024"
# Wait 3-5 minutes for scraper to finish
curl https://jobmitra-api.onrender.com/stats
```

---

## Features to Add (Priority Order)

### 🔥 High Priority
1. **Fix jobs feed** — loosen backend filtering so jobs actually show
2. **Shimmer animation** — add shimmer package, animated loading skeleton
3. **Premium AppBar** — gradient, show "X new jobs today", notification bell
4. **Search improvements** — trending searches, recent history, filter by state
5. **Wake-up ping** — on app start, ping Render to wake it up before user reaches feed

### 🟡 Medium Priority  
6. **More RSS sources** — freejobalert, bharatnaukri, govtjobsdiary, employmentnews
7. **State filter** — filter jobs by state in home feed
8. **Job sharing** — share job via WhatsApp (already has share button)
9. **Notification badge** — show unread count on Jobs tab
10. **Daily auto-scrape** — cron job on Render (needs paid plan for persistent jobs)

### 🟢 Nice to Have
11. **Firebase notifications** — push alerts for new railway/banking jobs
12. **Offline mode** — cache last 50 jobs locally with Hive
13. **Apply tracker** — mark jobs as "Applied", "Saved", "Rejected"
14. **Admit card / Result tracker** — beyond just jobs
15. **AdMob integration** — banner in feed, interstitial after job detail

---

## Common Commands

```bash
# Run Flutter app
cd ~/jobmitra/flutter_app
flutter run

# Run backend locally
cd ~/jobmitra/backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Run scraper
cd ~/jobmitra/scraper
python3 scraper.py

# Import jobs to local DB
python3 << 'EOF'
import sqlite3, json, os
db = os.path.expanduser("~/jobmitra/backend/jobmitra.db")
jobs = json.load(open(os.path.expanduser("~/jobmitra/backend/scraped_jobs.json")))
conn = sqlite3.connect(db)
# ... insert logic
EOF

# Check cloud stats
curl https://jobmitra-api.onrender.com/stats

# Trigger cloud scraper
curl -X POST "https://jobmitra-api.onrender.com/admin/scrape?secret=jobmitra_secret_2024"

# Push to GitHub + auto-deploy Render
cd ~/jobmitra && git add . && git commit -m "fix" && git push
```

---

## Known Bugs

| Bug | Location | Fix |
|-----|----------|-----|
| Jobs not showing | main.py feed endpoint | Loosen qualification filter |
| Shimmer blank white | home_screen.dart | Add shimmer package animation |
| Render cold start 50s | Flutter api_service.dart | Add wake-up ping on app launch |
| Hindi garbled text | scraper.py RSS parser | Force UTF-8 decode |
| `run_all_scrapers` wrong | main.py import | Fixed: use `run_all` |
| Body not imported | main.py | Fixed: `from fastapi import ... Body` |
| Free tier DB reset | Render | Workaround: re-run scraper after deploy |

---

## Tech Stack Versions
- Flutter: Latest stable
- Dart: Latest
- FastAPI: 0.115.0
- Python: 3.11.8
- Pydantic: 2.7.0
- Android min SDK: 21
- Target SDK: Latest flutter default
- Google Fonts: poppins (main font)

---

## Monetization Plan
1. **AdMob** — banner ads in job feed (after 1000 downloads)
2. **Premium ₹99/month** — early notifications, unlimited bookmarks, ad-free
3. **Coaching institute ads** — targeted by state + exam category

---

## Next Session Checklist
- [ ] Fix jobs feed endpoint (most critical)
- [ ] Add shimmer animation
- [ ] Add wake-up ping for Render cold start
- [ ] Add 5+ new RSS sources
- [ ] Premium AppBar with stats
- [ ] Search screen improvements