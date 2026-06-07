#!/usr/bin/env python3
"""
seed_data.py — One-time seed for exam_calendar and dept_profiles tables.

Usage:
    python backend/seed_data.py
    # or on Cloud (after deploy):
    # curl -X POST "API_URL/admin/seed-exam-calendar?secret=SECRET" -d '{"exams":[...]}'

Run this after a fresh deploy to populate the DB.
"""

import os
import requests

API_BASE = os.getenv("API_BASE", "https://jobmitra-api-830207301447.asia-south1.run.app")
SECRET   = os.getenv("SCRAPER_SECRET") or input("Enter SCRAPER_SECRET: ").strip()

HEADERS = {"Content-Type": "application/json"}


# ── Exam Calendar ─────────────────────────────────────────────────────────────

EXAM_CALENDAR = [
    # UPSC
    {"id": "upsc_cse_2026", "name": "UPSC Civil Services 2026", "category": "upsc", "emoji": "🏛️",
     "notif_date": "2026-01-22", "last_date": "2026-03-11", "exam_date": "2026-05-24",
     "is_tentative": True, "official_site": "upsc.gov.in"},
    {"id": "upsc_cds2_2026", "name": "UPSC CDS II 2026", "category": "upsc", "emoji": "🏛️",
     "notif_date": "2026-05-28", "last_date": "2026-06-17", "exam_date": "2026-09-13",
     "is_tentative": True, "official_site": "upsc.gov.in"},
    {"id": "upsc_capf_2026", "name": "UPSC CAPF AC 2026", "category": "upsc", "emoji": "🏛️",
     "notif_date": "2026-04-22", "last_date": "2026-05-13", "exam_date": "2026-08-02",
     "is_tentative": True, "official_site": "upsc.gov.in"},
    # SSC
    {"id": "ssc_cgl_2025", "name": "SSC CGL 2025 (Tier II)", "category": "ssc", "emoji": "📋",
     "exam_date": "2026-01-18", "is_tentative": False, "official_site": "ssc.gov.in"},
    {"id": "ssc_chsl_2026", "name": "SSC CHSL 2026", "category": "ssc", "emoji": "📋",
     "notif_date": "2026-05-01", "last_date": "2026-05-31", "exam_date": "2026-07-20",
     "is_tentative": True, "official_site": "ssc.gov.in"},
    {"id": "ssc_cgl_2026", "name": "SSC CGL 2026", "category": "ssc", "emoji": "📋",
     "notif_date": "2026-06-15", "last_date": "2026-07-15", "exam_date": "2026-09-10",
     "is_tentative": True, "official_site": "ssc.gov.in"},
    {"id": "ssc_mts_2026", "name": "SSC MTS 2026", "category": "ssc", "emoji": "📋",
     "notif_date": "2026-07-01", "last_date": "2026-07-31", "exam_date": "2026-10-01",
     "is_tentative": True, "official_site": "ssc.gov.in"},
    # Banking
    {"id": "sbi_po_2026", "name": "SBI PO 2026", "category": "banking", "emoji": "🏦",
     "notif_date": "2026-04-01", "last_date": "2026-04-25", "exam_date": "2026-06-14",
     "is_tentative": True, "official_site": "sbi.co.in"},
    {"id": "ibps_po_2026", "name": "IBPS PO 2026", "category": "banking", "emoji": "🏦",
     "notif_date": "2026-07-28", "last_date": "2026-08-18", "exam_date": "2026-10-03",
     "is_tentative": True, "official_site": "ibps.in"},
    {"id": "ibps_clerk_2026", "name": "IBPS Clerk 2026", "category": "banking", "emoji": "🏦",
     "notif_date": "2026-08-01", "last_date": "2026-08-21", "exam_date": "2026-11-28",
     "is_tentative": True, "official_site": "ibps.in"},
    {"id": "rbi_grade_b_2026", "name": "RBI Grade B 2026", "category": "banking", "emoji": "🏦",
     "notif_date": "2026-05-15", "last_date": "2026-06-05", "exam_date": "2026-07-19",
     "is_tentative": True, "official_site": "rbi.org.in"},
    # Railway
    {"id": "rrb_ntpc_2025", "name": "RRB NTPC 2025 (Result)", "category": "railway", "emoji": "🚂",
     "exam_date": "2025-09-15", "is_tentative": False, "official_site": "indianrailways.gov.in"},
    {"id": "rrb_group_d_2026", "name": "RRB Group D 2026", "category": "railway", "emoji": "🚂",
     "notif_date": "2026-06-01", "last_date": "2026-07-01", "exam_date": "2026-09-15",
     "is_tentative": True, "official_site": "indianrailways.gov.in"},
    {"id": "rrb_alp_2026", "name": "RRB ALP / Technician 2026", "category": "railway", "emoji": "🚂",
     "notif_date": "2026-05-01", "last_date": "2026-06-01", "exam_date": "2026-08-10",
     "is_tentative": True, "official_site": "indianrailways.gov.in"},
    # Defence
    {"id": "nda1_2026", "name": "NDA & NA I 2026", "category": "defence", "emoji": "⭐",
     "notif_date": "2026-01-14", "last_date": "2026-02-03", "exam_date": "2026-04-12",
     "is_tentative": False, "official_site": "upsc.gov.in"},
    {"id": "agniveer_2026", "name": "Agniveer Army 2026", "category": "defence", "emoji": "⭐",
     "notif_date": "2026-02-01", "last_date": "2026-03-01", "exam_date": "2026-05-01",
     "is_tentative": True, "official_site": "joinindianarmy.nic.in"},
    # State PSC
    {"id": "bpsc_70th", "name": "BPSC 70th CCE", "category": "state", "emoji": "📜",
     "exam_date": "2025-12-13", "is_tentative": False, "official_site": "bpsc.bih.nic.in"},
    {"id": "uppsc_pre_2026", "name": "UPPSC PCS Pre 2026", "category": "state", "emoji": "📜",
     "notif_date": "2026-03-01", "last_date": "2026-04-15", "exam_date": "2026-07-20",
     "is_tentative": True, "official_site": "uppsc.up.nic.in"},
    {"id": "rpsc_ras_2026", "name": "RPSC RAS 2026", "category": "state", "emoji": "📜",
     "notif_date": "2026-04-01", "last_date": "2026-05-01", "exam_date": "2026-10-18",
     "is_tentative": True, "official_site": "rpsc.rajasthan.gov.in"},
]


# ── Department Profiles ────────────────────────────────────────────────────────

DEPT_PROFILES = [
    {
        "id": "ias_ips_irs",
        "name": "IAS / IPS / IRS",
        "full_name": "Indian Administrative / Police / Revenue Service",
        "emoji": "🇮🇳",
        "category": "central",
        "color_hex": "#1A237E",
        "ministry": "Ministry of Personnel, DoPT",
        "hq": "North Block, New Delhi",
        "about": "India's most powerful bureaucrats. Become District Collector, SP, Commissioner. Control over policy, law & order, and revenue.",
        "roles": ["IAS – District Collector / SDM", "IPS – SP / DIG / Inspector General", "IRS – Income Tax / Customs Officer"],
        "salary": "₹56,100 – ₹2,50,000/month",
        "work_life": "Field postings are hectic (24x7). Better balance at senior levels.",
        "perks": ["Government bungalow", "Government car + driver", "Z/Y security", "Priority medical (CGHS)", "Staff at home", "Power & prestige"],
        "promotion_path": "SDM → ADM → DM/Collector → Commissioner → Secretary → Cabinet Secretary",
        "best_for": "Those who want both power and public service",
        "rating": 5,
    },
    {
        "id": "ssc_cgl_posts",
        "name": "SSC CGL Posts",
        "full_name": "Income Tax / Excise / CBI / Audit",
        "emoji": "🏛️",
        "category": "central",
        "color_hex": "#1565C0",
        "ministry": "Various Central Ministries",
        "hq": "Pan India",
        "about": "SSC CGL ke through Inspector Income Tax, Excise, CBI, CAG Auditor, CSS. Stable central govt job with Grade Pay 4200-4600.",
        "roles": ["Inspector Income Tax", "Inspector Central Excise", "Sub Inspector CBI", "Auditor (CAG/CGDA)", "CSS (MEA, PMO postings)"],
        "salary": "₹35,000 – ₹65,000/month",
        "work_life": "IT/Excise inspection field duty, Audit 9-5. Office based stable.",
        "perks": ["HRA 27% in X cities", "LTC (hometown + abroad)", "CGHS medical", "Reimbursements", "Subsidized canteen"],
        "promotion_path": "Inspector → SI → ITO (Income Tax Officer) → ACIT → DCIT",
        "best_for": "Those who want stability and good salary without IAS-level prep",
        "rating": 4,
    },
    {
        "id": "drdo",
        "name": "DRDO",
        "full_name": "Defence Research and Development Organisation",
        "emoji": "🔬",
        "category": "research",
        "color_hex": "#004D40",
        "ministry": "Ministry of Defence",
        "hq": "DRDO Bhawan, New Delhi",
        "about": "India's premier defence R&D body — missiles, radar, electronics, materials. 50+ labs across India. A dream for scientists and engineers.",
        "roles": ["Scientist B (Graduate entry)", "Junior Research Fellow (JRF)", "Technician A/B (ITI/Diploma)", "RAC entry via GATE/interview"],
        "salary": "₹56,000 – ₹1,50,000/month (Scientist B)",
        "work_life": "Research lab hours 9–6. Project deadlines can be intense but no field duty.",
        "perks": ["DRDO housing colony", "Subsidized schools (Kendriya Vidyalaya priority)", "Lab equipment budget", "Foreign conference sponsorship", "Patent incentives"],
        "promotion_path": "Scientist B → C → D → E → F → G → Distinguished Scientist",
        "best_for": "Engineers / Science grads who want to work on cutting-edge research",
        "rating": 4,
    },
    {
        "id": "isro",
        "name": "ISRO",
        "full_name": "Indian Space Research Organisation",
        "emoji": "🚀",
        "category": "research",
        "color_hex": "#01579B",
        "ministry": "Dept. of Space, GoI",
        "hq": "Antariksh Bhawan, Bengaluru",
        "about": "Chandrayaan, Mangalyaan, PSLV. India's pride. The ultimate govt tech job for scientists and engineers.",
        "roles": ["Scientist / Engineer SC (entry)", "Technical Assistant", "ICRB recruitment via GATE"],
        "salary": "₹56,000 – ₹1,60,000/month",
        "work_life": "Intense during launch seasons. Postings in Bengaluru/Sriharikota common.",
        "perks": ["ISRO housing/guest houses", "Best-in-class labs", "Foreign deputation", "Canteen + creche", "Learning culture"],
        "promotion_path": "SC → SD → SE → SF → SG → Outstanding Scientist",
        "best_for": "B.Tech/M.Tech grads with GATE score (ECE/CS/ME/AE)",
        "rating": 5,
    },
    {
        "id": "ongc",
        "name": "ONGC",
        "full_name": "Oil and Natural Gas Corporation",
        "emoji": "🛢️",
        "category": "central",
        "color_hex": "#E65100",
        "ministry": "Ministry of Petroleum & Natural Gas",
        "hq": "Deendayal Urja Bhawan, New Delhi",
        "about": "India's largest oil & gas PSU. Exploration, drilling, refining. Remote postings but package is excellent.",
        "roles": ["Assistant Executive Engineer (AEE)", "Junior Assistant Technician (JAT)", "Geoscientist (Type A)", "Non-Executive (NE) Staff"],
        "salary": "₹60,000 – ₹1,80,000/month",
        "work_life": "Remote offshore/onshore posting possible. 28-on/28-off rotation in field. City posting = 9-5.",
        "perks": ["Offshore/field allowance (2x-3x salary)", "Free accommodation", "LTC + medical + children education", "ONGC township facilities"],
        "promotion_path": "E1 → E2 → E3 → E4 (Manager) → E5 (DGM) → E6 (GM)",
        "best_for": "Petroleum/Mechanical/Chemical/Geo engineers",
        "rating": 4,
    },
    {
        "id": "indian_railways",
        "name": "Indian Railways",
        "full_name": "Ministry of Railways — All Departments",
        "emoji": "🚂",
        "category": "railway",
        "color_hex": "#4527A0",
        "ministry": "Ministry of Railways",
        "hq": "Rail Bhawan, New Delhi",
        "about": "World's largest employer. 13 lakh+ employees. NTPC, Group D, ALP, JE, SE, RRB Board. Pan India posting.",
        "roles": ["Group D (track maintainer, helper)", "ALP / Technician", "NTPC (Guard, CA, Stationmaster)", "Junior Engineer (JE)", "Senior Section Engineer (SSE)"],
        "salary": "₹18,000 – ₹75,000/month",
        "work_life": "Shift duty for operational posts (SM, Guard). Office posts 9-5.",
        "perks": ["Free railway pass (self + family)", "Quarter allocation", "Kendriya Vidyalaya priority", "Railway canteen", "Medical (CGHS equivalent)"],
        "promotion_path": "Group D → Group C → Supervisor → JE → SE → Divisional Engineer",
        "best_for": "Those who want stability and are willing to be posted anywhere in India",
        "rating": 4,
    },
    {
        "id": "sbi",
        "name": "SBI",
        "full_name": "State Bank of India",
        "emoji": "🏦",
        "category": "banking",
        "color_hex": "#1B5E20",
        "ministry": "Ministry of Finance",
        "hq": "SBI Bhavan, Mumbai",
        "about": "India's largest public sector bank. SBI PO is the most prestigious banking career with the fastest promotion track.",
        "roles": ["Probationary Officer (PO)", "Clerk (JA/JAA)", "Specialist Officer (SO)", "Circle Based Officer (CBO)"],
        "salary": "₹42,000 – ₹95,000/month",
        "work_life": "Branch: 9-5 (busy in month-end). 6-day week in branches.",
        "perks": ["Subsidized home loan (2-3% below market)", "Medical + LFC", "Pension (old employees)", "SBI brand weight", "Transfer across India"],
        "promotion_path": "PO → JMGS I → MMGS II → MMGS III → SMGS IV → SMGS V (AGM) → TEG VI (DGM)",
        "best_for": "Those who want a banking career with fast promotions",
        "rating": 4,
    },
    {
        "id": "rbi",
        "name": "RBI",
        "full_name": "Reserve Bank of India",
        "emoji": "💰",
        "category": "banking",
        "color_hex": "#004D40",
        "ministry": "Ministry of Finance (autonomous)",
        "hq": "Mint Road, Mumbai",
        "about": "India's central bank. Grade B officer is one of the most coveted govt jobs. Research, regulation, monetary policy.",
        "roles": ["Grade B Officer (DR)", "Grade B DEPR / DSIM (Economics/Statistics)", "Assistant (Grade C equivalent)", "Office Attendant"],
        "salary": "₹80,000 – ₹1,20,000/month (Grade B)",
        "work_life": "Best work-life balance in banking. 5-day week. AC offices.",
        "perks": ["RBI staff quarters (prime locations)", "Interest-free / low-rate loans", "Excellent medical", "Study leave for higher education", "Global assignments (IMF, BIS)"],
        "promotion_path": "Grade B → Grade C → Grade D (DGM) → Grade E (GM) → Grade F → Deputy Governor",
        "best_for": "High-achievers in banking — worth 2+ years of prep",
        "rating": 5,
    },
    {
        "id": "indian_army",
        "name": "Indian Army",
        "full_name": "Indian Army — Officer & Other Ranks",
        "emoji": "🪖",
        "category": "defence",
        "color_hex": "#33691E",
        "ministry": "Ministry of Defence",
        "hq": "South Block, New Delhi",
        "about": "NDA/CDS/TES/UES se officer. Soldier GD/Clerk/Technical se jawaan. Pride, adventure, pension, canteen.",
        "roles": ["Lieutenant (NDA/CDS graduate entry)", "JCO (Junior Commissioned Officer)", "Soldier GD / Clerk / Technical", "Army MNS (Nursing Officer)"],
        "salary": "₹56,100 – ₹2,50,000/month (Officer)",
        "work_life": "Field posting = intense. Peace station = decent. Family accommodation provided.",
        "perks": ["Army canteen (40-50% discount)", "Free medical", "Subsidized school (Army Public School)", "Pension (after 15 years)", "Adventure sports"],
        "promotion_path": "Lieutenant → Captain → Major → Lt Col → Colonel → Brigadier → MG → Lt Gen → COAS",
        "best_for": "12th pass or graduates who want adventure + national service",
        "rating": 4,
    },
    {
        "id": "crpf_bsf_cisf",
        "name": "CRPF / BSF / CISF",
        "full_name": "Central Armed Police Forces",
        "emoji": "🛡️",
        "category": "defence",
        "color_hex": "#827717",
        "ministry": "Ministry of Home Affairs",
        "hq": "CGO Complex, New Delhi",
        "about": "India's largest CAPF. Border guarding, VIP protection, industrial security. Officer via UPSC CAPF, Constable via SSC CPO.",
        "roles": ["Assistant Commandant (UPSC CAPF)", "Sub Inspector (SSC CPO)", "Constable (CHSL/GD)", "Head Constable"],
        "salary": "₹25,000 – ₹90,000/month",
        "work_life": "Border/conflict posting = high risk. Field allowance excellent. 60-day leave/year.",
        "perks": ["Risk/hardship allowance", "Free ration", "Govt accommodation", "Medical", "CAPF canteen"],
        "promotion_path": "Constable → HC → ASI → SI → Inspector → AC → DC → IG → ADG → DG",
        "best_for": "Those who want challenging field service with good pay",
        "rating": 3,
    },
    {
        "id": "state_electricity_boards",
        "name": "State Electricity Boards",
        "full_name": "UPPCL / MPPKVVCL / HPSEBL etc.",
        "emoji": "⚡",
        "category": "state",
        "color_hex": "#F57F17",
        "ministry": "State Power Departments",
        "hq": "State capitals",
        "about": "JE, AE, AEE roles in state electricity boards — state-level govt job for engineering grads. Usually home state posting.",
        "roles": ["Junior Engineer (JE) – Electrical/Civil", "Assistant Engineer (AE/AEE)", "Revenue Accountant / Cashier", "Technician"],
        "salary": "₹30,000 – ₹80,000/month",
        "work_life": "Field + office mix. Emergency duty during power cuts.",
        "perks": ["Concessional electricity at home", "State govt medical", "Housing in state cities", "Job security"],
        "promotion_path": "JE → AE → AEE → EE (Executive Engineer) → SE → CE",
        "best_for": "Electrical/Civil engineers who want to stay in their home state",
        "rating": 3,
    },
    {
        "id": "kvs_nvs_teaching",
        "name": "Teaching (KVS / NVS / DSSSB)",
        "full_name": "Kendriya / Navodaya / Delhi Govt Teachers",
        "emoji": "📚",
        "category": "central",
        "color_hex": "#880E4F",
        "ministry": "Ministry of Education",
        "hq": "Pan India",
        "about": "18 vacancies per school, 1244 KVs. PGT, TGT, PRT. Excellent leaves, summer vacation, work-life balance.",
        "roles": ["PRT (Primary Teacher)", "TGT (Trained Graduate Teacher)", "PGT (Post Graduate Teacher)", "Librarian / Lab Assistant"],
        "salary": "₹28,000 – ₹60,000/month",
        "work_life": "Best in any govt job. 60-day summer + winter vacation. 9-4 school hours.",
        "perks": ["School holidays = your holidays", "Free CGHS medical", "GPF/NPS", "Concessional school fee for own children", "Respectful profession"],
        "promotion_path": "TGT → PGT → Vice Principal → Principal (competitive process)",
        "best_for": "B.Ed holders who want stability and excellent work-life balance",
        "rating": 4,
    },
]


def seed_exam_calendar():
    print(f"\nSeeding exam calendar ({len(EXAM_CALENDAR)} entries)...")
    r = requests.post(
        f"{API_BASE}/admin/seed-exam-calendar",
        params={"secret": SECRET},
        json={"exams": EXAM_CALENDAR},
        headers=HEADERS,
        timeout=60,
    )
    if r.status_code == 200:
        d = r.json()
        print(f"  OK: inserted {d['inserted']} / {d['total']} exam entries")
    else:
        print(f"  FAIL {r.status_code}: {r.text[:200]}")


def seed_dept_profiles():
    print(f"\nSeeding dept profiles ({len(DEPT_PROFILES)} entries)...")
    r = requests.post(
        f"{API_BASE}/admin/seed-dept-profiles",
        params={"secret": SECRET},
        json={"depts": DEPT_PROFILES},
        headers=HEADERS,
        timeout=60,
    )
    if r.status_code == 200:
        d = r.json()
        print(f"  OK: inserted {d['inserted']} / {d['total']} dept entries")
    else:
        print(f"  FAIL {r.status_code}: {r.text[:200]}")


if __name__ == "__main__":
    seed_exam_calendar()
    seed_dept_profiles()
    print("\nSeed complete. App will now load live data from backend.")
