## Project Overview
Indian Sarkari Naukri aggregator Android app.
- **Live API**: https://jobmitra-api.onrender.com
- **GitHub**: https://github.com/buhtig47/jobmitra
- **Local path**: ~/jobmitra/
- **Scraper secret**: `jobmitra_secret_2024`

## Stack
| Layer | Tech |
|-------|------|
| Backend | FastAPI + SQLite, Python 3.11.8 |
| Deploy | Render.com free tier |
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
| Render cold start 50s | wakeUpServer() added in main.dart |
| DB resets on Render redeploy | Re-run scraper after every deploy |
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
# Push + auto-deploy
cd ~/jobmitra && git add . && git commit -m "msg" && git push

# Import jobs to cloud
curl -X POST "https://jobmitra-api.onrender.com/admin/scrape?secret=jobmitra_secret_2024"

# Check cloud
curl https://jobmitra-api.onrender.com/stats

# Clear app data
adb shell pm clear com.example.jobmitra

# Flutter run
cd ~/jobmitra/flutter_app && flutter run
