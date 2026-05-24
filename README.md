# JobMitra

> Indian Sarkari Naukri (government jobs) aggregator — a Flutter Android app powered by a FastAPI backend that scrapes 270+ openings from 86+ sources.

[![Flutter](https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://www.python.org)
[![Cloud Run](https://img.shields.io/badge/Google_Cloud_Run-deployed-4285F4?logo=googlecloud)](https://cloud.google.com/run)
[![Turso](https://img.shields.io/badge/DB-Turso_(libSQL)-4ff8d2)](https://turso.tech)

**Live API:** https://jobmitra-api-830207301447.asia-south1.run.app

---

## What it does

JobMitra centralises Indian government job listings — SSC, UPSC, banking, railways, defence, state-level recruitments — into a single mobile feed. Instead of bouncing across dozens of slow, ad-laden websites, users get a clean, fast Android app with category-coded cards, search, and saved-jobs.

- **86+ sources** scraped on a schedule (RSS + HTML parsers)
- **~270 active listings** at any time, deduplicated and normalised
- **Sub-2s cold start** on Google Cloud Run (asia-south1)
- **Persistent cloud DB** (Turso) — survives redeploys
- **Premium UI** with shimmer loading, category colours, onboarding flow

---

## Architecture

```
┌──────────────┐      ┌──────────────────────┐      ┌──────────────────┐
│  Scraper     │ ───► │  FastAPI Backend     │ ───► │  Flutter Android │
│  (Python)    │      │  (Cloud Run, py3.11) │      │  (HTTP + cache)  │
│  86+ sources │      │                      │      │                  │
└──────────────┘      └──────────┬───────────┘      └──────────────────┘
                                 │
                                 ▼
                       ┌──────────────────┐
                       │ Turso (libSQL)   │
                       │ persistent cloud │
                       └──────────────────┘
```

---

## Tech Stack

| Layer        | Tech                                                |
|--------------|-----------------------------------------------------|
| Mobile       | Flutter (Android), Material 3, Google Fonts (Poppins) |
| State/Cache  | SharedPreferences, `package:http`, shimmer 3.0      |
| Backend      | FastAPI, Python 3.11.8                              |
| Database     | Turso (libSQL — distributed SQLite)                 |
| Deploy       | Google Cloud Run (asia-south1, scale-to-zero)       |
| Secrets      | Google Secret Manager                               |
| CI / Cron    | GitHub Actions (scheduled scrape trigger)           |
| Scraper      | RSS + custom HTML parsers, dedup + mojibake filter  |

---

## Repository Layout

```
jobmitra/
├── flutter_app/          Flutter Android app
│   ├── lib/
│   │   ├── screens/      home, search, saved, profile, job_detail
│   │   ├── widgets/      job_card and supporting widgets
│   │   ├── services/     api_service.dart — backend client
│   │   ├── models/       Job + UserProfile models
│   │   └── utils/        constants.dart — API URL, colours, theme
│   └── android/
├── backend/              FastAPI app deployed to Cloud Run
│   ├── main.py           API endpoints
│   ├── scraper.py        scraper invoked by /admin/scrape
│   ├── Dockerfile
│   └── requirements.txt
├── scraper/              Standalone scraper (also runs in backend)
└── docs/                 Hosted privacy policy + delete-data pages
```

---

## Running Locally

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Set required env vars (use a .env or export):
#   TURSO_URL, TURSO_TOKEN, SCRAPER_SECRET
uvicorn main:app --reload
```

### Flutter app

```bash
cd flutter_app
flutter pub get
flutter run                              # debug build, points to live API by default
```

To point the app at a local backend, edit `flutter_app/lib/utils/constants.dart` and set the API base URL to `http://10.0.2.2:8000` (Android emulator → host).

### Release build

```bash
cd flutter_app
flutter build apk --release
# or, for Play Store:
flutter build appbundle --release
```

---

## Design Choices

- **Cloud Run over a VM**: scale-to-zero keeps costs near zero while idle; cold starts are ~2s, acceptable for a job-search use case.
- **Turso over Postgres**: SQLite ergonomics, distributed reads, free tier comfortably fits the workload. The database survives redeploys (unlike ephemeral container disks).
- **Scraper inside the API container**: simplifies deploy, lets a single Cloud Run service handle both `/jobs` reads and `/admin/scrape` writes. Secret-gated to prevent abuse.
- **SharedPreferences + on-launch fetch**: lightweight cache for last-seen jobs; future iteration moves to Hive for richer offline mode.

---

## Status

This is an active, deployed project. The backend is live on Cloud Run, the Flutter app runs on Android, and the scraper produces fresh listings on schedule. Roadmap items (Firebase push, Hive offline cache, AdMob integration, more RSS sources) are tracked privately.

---

## License

All rights reserved. Source published for portfolio review.