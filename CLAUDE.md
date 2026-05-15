## Project Overview
Indian Sarkari Naukri aggregator Android app.
- **Live API**: https://jobmitra-api-830207301447.asia-south1.run.app (Google Cloud Run, asia-south1)
- **Legacy API**: https://jobmitra-api.onrender.com (Render, deprecated — kill once Flutter ships)
- **GitHub**: https://github.com/buhtig47/jobmitra
- **Local path**: ~/jobmitra/
- **GCP project**: jobmitra-17db0
- **Scraper secret**: `jobmitra_secret_2024` (synced to Secret Manager `SCRAPER_SECRET:latest` for Cloud Run, also in GitHub Secrets). Rotate later as a security pass.

## Stack
| Layer | Tech |
|-------|------|
| Backend | FastAPI + Turso (libsql cloud), Python 3.11.8 |
| Deploy | Google Cloud Run, asia-south1, scale-to-zero |
| Secrets | Google Secret Manager (TURSO_URL, TURSO_TOKEN, SCRAPER_SECRET) |
| Frontend | Flutter Android |
| Font | Google Fonts — Poppins |
| HTTP | package:http |
| Storage | SharedPreferences |
| Animation | shimmer: ^3.0.0 |

---

## Current Status
- [x] Scraper v8 — ~270 jobs from 86+ sources
- [x] FastAPI backend live on Render
- [x] Flutter app running on Android
- [x] Premium job cards with category colors
- [x] Jobs feed working (139 jobs showing)
- [x] Job detail screen with Apply button
- [x] Onboarding flow complete
- [x] Search + Saved + Profile screens exist

---

## Pending Tasks (Priority Order)

### 1. Shimmer Animation Fix
**File**: `flutter_app/lib/screens/home_screen.dart`
**Problem**: Shimmer shows blank white cards — no visible animation
**Fix**:
- Add fixed height: 160 to shimmer skeleton cards
- Add colored shimmer bar at top of each card
- Add shimmer to search results loading too

### 2. New RSS Sources
**File**: `scraper/scraper.py`
**Add to RSS_SOURCES list**:
```python
{"name": "freejobalert",    "url": "https://www.freejobalert.com/feed/"},
{"name": "bharatnaukri",    "url": "https://bharatnaukri.com/feed/"},
{"name": "govtjobsdiary",   "url": "https://govtjobsdiary.com/feed/"},
{"name": "sharmajobs",      "url": "https://www.sharmajobs.com/feed/"},
{"name": "sarkarinaukri2025","url": "https://sarkarinaukri2025.com/feed/"},
```
After adding: copy scraper.py to backend/ and push to GitHub.

### 3. Firebase Push Notifications
- Firebase project banana hai
- google-services.json add karo android/app/
- firebase_messaging package add karo
- FCM token properly save karo (abhi "test" hardcoded)

### 4. Offline Mode (Hive Cache)
- hive + hive_flutter packages add karo
- Jobs fetch hone ke baad Hive mein save karo
- App open pe pehle Hive se load karo (instant)
- "Last updated X min ago" show karo

### 5. AdMob Integration
- google_mobile_ads package add karo
- Banner ad har 5th job card ke baad
- Interstitial job detail se back aane par

---

## Known Bugs

| Bug | Fix |
|-----|-----|
| ~~Render cold start 50s~~ | Migrated to Cloud Run (asia-south1). Cold start ~2s. wakeUpServer() in main.dart now redundant — remove next pass |
| ~~DB resets on Render redeploy~~ | Stale — Turso (cloud DB) used; persistent across deploys |
| Hindi garbled text | Force UTF-8, filter mojibake in scraper |
| user_id mismatch | adb shell pm clear com.example.jobmitra |

---

## Important Files

| File | Purpose |
|------|---------|
| flutter_app/lib/utils/constants.dart | API URL, Colors, Theme |
| flutter_app/lib/screens/home_screen.dart | Main feed + shimmer |
| flutter_app/lib/widgets/job_card.dart | Premium job card UI |
| flutter_app/lib/services/api_service.dart | All API calls |
| flutter_app/lib/models/job_model.dart | Job + UserProfile models |
| backend/main.py | FastAPI endpoints |
| scraper/scraper.py | Multi-source scraper, entry: run_all() |

---

## Colors
```dart
primary    = Color(0xFF1A6B3C)  // India Green
accent     = Color(0xFFFF9933)  // Saffron
background = Color(0xFFF5F7F5)
```

## Deploy Commands
```bash
# Cloud Run redeploy (from backend/)
cd ~/jobmitra/backend && gcloud run deploy jobmitra-api \
  --source=. --region=asia-south1 --project=jobmitra-17db0 \
  --set-secrets=TURSO_URL=TURSO_URL:latest,TURSO_TOKEN=TURSO_TOKEN:latest,SCRAPER_SECRET=SCRAPER_SECRET:latest

# Fetch SCRAPER_SECRET (for curl admin endpoints)
SECRET=$(gcloud secrets versions access latest --secret=SCRAPER_SECRET --project=jobmitra-17db0)

# Trigger scrape
curl -X POST "https://jobmitra-api-830207301447.asia-south1.run.app/admin/scrape?secret=${SECRET}"

# Check stats
curl https://jobmitra-api-830207301447.asia-south1.run.app/stats

# Clear app data
adb shell pm clear com.example.jobmitra

# Flutter run
cd ~/jobmitra/flutter_app && flutter run
