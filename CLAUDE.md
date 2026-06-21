## Project Overview
Indian Sarkari Naukri aggregator Android app.
- **Live API**: https://jobmitra-api-830207301447.asia-south1.run.app (Google Cloud Run, asia-south1, revision 00043)
- **Legacy API**: https://jobmitra-api.onrender.com (Render, deprecated — dead, do not use)
- **GitHub**: https://github.com/buhtig47/jobmitra
- **Local path**: ~/jobmitra/
- **GCP project**: jobmitra-17db0
- **Scraper secret**: `jobmitra_secret_2024` (synced to Secret Manager `SCRAPER_SECRET:latest` for Cloud Run, also in GitHub Secrets). Rotate later as a security pass.
- **Play Store**: v1.7.5+21 AAB built — ready to upload once v1.7.4+20 description fix is approved

## Stack
| Layer | Tech |
|-------|------|
| Backend | FastAPI + Turso (libsql cloud), Python 3.11.8 |
| Deploy | Google Cloud Run, asia-south1, scale-to-zero |
| Secrets | Google Secret Manager (TURSO_URL, TURSO_TOKEN, SCRAPER_SECRET, GEMINI_API_KEY) |
| Frontend | Flutter Android |
| Font | Google Fonts — Poppins |
| HTTP | package:http |
| Storage | SharedPreferences + Hive (offline cache) |
| Animation | shimmer: ^3.0.0 |
| Ads | google_mobile_ads (banner, interstitial, app open) |
| Push | firebase_messaging + flutter_local_notifications |
| Automation | Cloud Scheduler (OIDC) → Cloud Run cron endpoints |

---

## Current Status
- [x] Scraper v8 — ~270 jobs from 86+ sources
- [x] FastAPI backend live on Cloud Run (asia-south1, rev 00043)
- [x] Flutter app on Play Store (v1.7.4+20 in review)
- [x] Premium job cards with category colors + urgency badges
- [x] Job detail screen with Apply button
- [x] Onboarding flow complete
- [x] Search + Saved + Profile screens
- [x] Firebase Push Notifications (FCM topics, deadline alerts, smart alerts)
- [x] Hive offline cache (feed cached, "Last updated X ago" shown)
- [x] AdMob — banner (every 5th card), interstitial, app open on resume
- [x] Daily Quiz with streak tracking (streak shown on home screen + quiz screen)
- [x] Announcements screen
- [x] Alert rules (user sets keyword/category rules, gets notified on match)
- [x] Cloud Scheduler automation — scrape @ 2 AM IST + quiz push @ 8 AM IST (OIDC-secured)

---

## Pending Tasks (Priority Order)

### Phase 1 — Bug Fixes + Quick Wins ✅ ALL DONE
All Phase 1 items were already implemented in prior sessions. Verified clean in v1.7.5+21.

### Phase 2 — UI/UX Redesign ✅ ALL DONE
Audited against the code 2026-06-14 (v1.7.9+26) — every item already implemented in prior sessions:
- Job card: left-edge colored bar, hero title, metadata grid, full-card tap, "NEW" badge <24h → `job_card.dart`
- Home screen: sticky greeting header, categories carousel, sectioned feed (Closing Soon / New Today / All) → `_feedItems` + `_SectionHeader` in `home_screen.dart`
- Job detail: tabbed content (Overview/Eligibility/Documents), sticky CTA → `job_detail_screen.dart`. NOTE: uses a fixed gradient header, NOT a collapsing SliverAppBar (deliberate, fine — don't redo).
- Search: inline loading, recent searches chips, filter sheet → `search_screen.dart`
- Profile edit: PopScope dirty-check dialog (`canPop:false`), age slider → `profile_edit_screen.dart`
- Saved jobs: stage tracker pill row, filter chips → `saved_jobs_screen.dart`

### Phase 3 — Backend Refactors (future)
- SQL pushdown for feed (fix "fetch 300, filter, slice" anti-pattern)
- Turso connection pool
- Async FCM fanout (aiohttp)
- SCRAPER_SECRET rotation + remove `_LEGACY_LEAKED_SECRET` block
- Mojibake filter (reject Devanagari+Latin garbage)
- Scraper observability (alert if >20% sources fail)
- `CREATE INDEX idx_jobs_scraped_at ON jobs(scraped_at DESC)`

### Next: Fix Play Store rejection (Misleading Claims) + upload AAB
- **Rejection (2026-06-14):** Misleading Claims policy → "Broken or Inaccessible Source Link". Root cause: store-listing description listed `https://isro.gov.in` (bare domain has NO DNS record; only `https://www.isro.gov.in` resolves). All other 16 source URLs return 200.
- **Store-listing fix (manual, in Play Console — NOT in repo):** change `• ISRO: https://isro.gov.in` → `• ISRO: https://www.isro.gov.in`. Do NOT file an appeal (that path is for claiming govt affiliation). Fix + resubmit via Publishing overview.
- **In-app fix (shipped in code):** `disclaimer_screen.dart` source links — ISRO `isro.gov.in`→`www.isro.gov.in`, ONGC `ongcindia.com`→`www.ongcindia.com` (flaky SSL on bare), RRB `rrbcdg.gov.in`→`www.rrbcdg.gov.in` (timeouts on bare).
- AAB built: `flutter_app/build/app/outputs/bundle/release/app-release.aab` (65.3 MB), version **1.7.9+26**.

---

## Known Bugs

| Bug | Fix |
|-----|-----|
| Shimmer invisible (white-on-white) | Phase 1 B1 — change placeholder boxes to `Color(0xFFE0E0E0)` |
| wakeUpServer() still in main.dart | Phase 1 B2 — delete function + call site |
| Interstitial not firing on job detail back | Phase 1 B3 — PopScope → AdService().showInterstitial() |
| Hindi garbled text | Phase 3 — mojibake filter in scraper |
| user_id mismatch | `adb shell pm clear com.jobmitra.app` |

---

## Important Files

| File | Purpose |
|------|---------|
| flutter_app/lib/utils/constants.dart | API URL, Colors, Theme |
| flutter_app/lib/screens/home_screen.dart | Main feed + shimmer + streak chip |
| flutter_app/lib/widgets/job_card.dart | Premium job card UI |
| flutter_app/lib/services/api_service.dart | All API calls |
| flutter_app/lib/models/job_model.dart | Job + UserProfile models |
| flutter_app/lib/services/ad_service.dart | Banner, interstitial, app open ads |
| flutter_app/lib/services/ad_ids.dart | AdMob unit IDs (test vs prod via --dart-define) |
| flutter_app/lib/services/notification_service.dart | FCM + local notifications + deeplink routing |
| flutter_app/lib/screens/daily_quiz_screen.dart | Daily quiz + streak tracking (SharedPrefs: quiz_streak) |
| flutter_app/lib/screens/announcements_screen.dart | Announcements feed |
| backend/main.py | FastAPI endpoints (OIDC cron at /internal/cron/scrape + /internal/cron/quiz) |
| backend/scraper.py | Canonical scraper (DO NOT overwrite with scraper/scraper.py) |
| backend/quiz_scraper.py | Quiz content scraper |
| scraper/scraper.py | Dev copy — sync to backend/scraper.py after changes |

---

## Cloud Scheduler (Automated — no manual curl needed)
| Job | Schedule | Endpoint | What it does |
|-----|----------|----------|--------------|
| `jobmitra-daily-scrape` | 20:30 UTC (2 AM IST) daily | `POST /internal/cron/scrape` | Scrapes all sources + pushes "New Jobs" FCM notification |
| `jobmitra-daily-quiz` | 02:30 UTC (8 AM IST) daily | `POST /internal/cron/quiz` | Scrapes quiz questions + pushes "Aaj ka Quiz Ready!" notification |

Both endpoints use OIDC auth (`jobmitra-scheduler@jobmitra-17db0.iam.gserviceaccount.com`).

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
# --max-instances 2: caps billing; backend is I/O-bound (Turso HTTP), 2 instances handle peak load
# --memory 512Mi: default is 1Gi; FastAPI+uvicorn+scraper fits in 512Mi, halves idle cost
cd ~/jobmitra/backend && gcloud run deploy jobmitra-api \
  --source=. --region=asia-south1 --project=jobmitra-17db0 \
  --max-instances=2 --memory=512Mi --cpu=1 \
  --set-secrets=TURSO_URL=TURSO_URL:latest,TURSO_TOKEN=TURSO_TOKEN:latest,SCRAPER_SECRET=SCRAPER_SECRET:latest,GEMINI_API_KEY=GEMINI_API_KEY:latest

# Manual scrape trigger (only for testing — normally runs via Cloud Scheduler)
SECRET=$(gcloud secrets versions access latest --secret=SCRAPER_SECRET --project=jobmitra-17db0)
curl -X POST "https://jobmitra-api-830207301447.asia-south1.run.app/admin/scrape?secret=${SECRET}"

# Check stats
curl https://jobmitra-api-830207301447.asia-south1.run.app/stats

# Check health
curl https://jobmitra-api-830207301447.asia-south1.run.app/health

# Clear app data
adb shell pm clear com.jobmitra.app

# Release APK build (real AdMob unit IDs injected at build time)
cd ~/jobmitra/flutter_app && flutter build apk --release \
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-1651515480969781/2757886235 \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-1651515480969781/7986162182 \
  --dart-define=ADMOB_APP_OPEN_ID=ca-app-pub-1651515480969781/4564824326 \
  --dart-define=ADMOB_REWARDED_ID=ca-app-pub-1651515480969781/4594108866

# Release AAB (for Play Store)
cd ~/jobmitra/flutter_app && flutter build appbundle --release \
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-1651515480969781/2757886235 \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-1651515480969781/7986162182 \
  --dart-define=ADMOB_APP_OPEN_ID=ca-app-pub-1651515480969781/4564824326 \
  --dart-define=ADMOB_REWARDED_ID=ca-app-pub-1651515480969781/4594108866

# Flutter run
cd ~/jobmitra/flutter_app && flutter run
```
