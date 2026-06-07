"""
gemini_service.py — Gemini AI integration for JobMitra.

Provides two capabilities:
  1. Quiz question generation — exam-specific MCQs with explanations.
     Called by /admin/generate-quiz (nightly cron) and stores results in
     the questions DB via /admin/questions.

  2. Career roadmap — personalized exam strategy based on user profile.
     Called by /ai/career-roadmap on-demand (rewarded-ad gated in Flutter).

Model choice:
  - gemini-1.5-flash : quiz gen (fast, cheap, structured output)
  - gemini-1.5-pro   : career roadmap (better reasoning for nuanced advice)

Both fall back gracefully: if GEMINI_API_KEY is missing or the call fails,
callers get an empty result and log an error — no crash.
"""

import json
import logging
import os
import re

log = logging.getLogger("jobmitra")

# Lazy import so the app still starts if the package isn't installed yet
# (e.g. during a cold deploy before pip finishes).
try:
    import google.generativeai as genai
    _genai_available = True
except ImportError:
    _genai_available = False
    log.warning("google-generativeai not installed — AI features disabled")


def _client(model: str):
    """Return a configured GenerativeModel, or None if unavailable."""
    if not _genai_available:
        return None
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        log.error("GEMINI_API_KEY not set — AI features disabled")
        return None
    genai.configure(api_key=api_key)
    return genai.GenerativeModel(model)


# ── Quiz generation ──────────────────────────────────────────────────────────

_QUIZ_PROMPT = """You are an expert Indian government exam coach. Generate {count} multiple-choice questions (MCQs) for the exam: {exam}.

Requirements:
- Questions must be relevant to the {exam} exam syllabus
- Each question must have exactly 4 options (A, B, C, D)
- Difficulty: {difficulty}
- Topics: {topics}
- Include a clear, educational explanation (2-3 sentences) for the correct answer
- Questions should test conceptual understanding, not just rote memory
- Mix question types: fact-based, application, and analytical

Return ONLY a valid JSON array with this exact structure (no markdown, no extra text):
[
  {{
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct": 0,
    "topic": "Topic name",
    "explanation": "Why this is the correct answer..."
  }}
]

correct is the 0-based index of the right answer.
"""

_EXAM_TOPICS = {
    "SSC CGL":   "Quantitative Aptitude, English Language, General Intelligence, General Awareness",
    "SSC CHSL":  "Quantitative Aptitude, English Language, General Intelligence, General Awareness",
    "SSC MTS":   "General Intelligence, English Language, Numerical Aptitude, General Awareness",
    "UPSC CSE":  "Indian Polity, History, Geography, Economy, Science & Technology, Environment, Current Affairs",
    "RRB NTPC":  "Mathematics, General Intelligence, General Awareness, English",
    "IBPS PO":   "Quantitative Aptitude, English, Reasoning, Computer Aptitude, Banking Awareness",
    "SBI PO":    "Data Analysis, Reasoning, English, General/Economy/Banking Awareness",
    "RBI Grade B": "Economics, Finance, Management, English",
    "UPPSC":     "Indian History, Geography, Polity, Economy, Science, UP-specific GK",
    "BPSC":      "Indian History, Bihar GK, Geography, Polity, Economy",
    "General GK": "Indian History, Geography, Polity, Economy, Science, Current Affairs",
}


def generate_quiz_questions(exam: str = "General GK", count: int = 10,
                             difficulty: str = "medium") -> list[dict]:
    """
    Generate MCQ questions for the given exam using Gemini.
    Returns a list of question dicts compatible with /admin/questions schema.
    Returns [] on any failure.
    """
    model = _client("gemini-1.5-flash")
    if model is None:
        return []

    topics = _EXAM_TOPICS.get(exam, _EXAM_TOPICS["General GK"])
    prompt = _QUIZ_PROMPT.format(
        count=count, exam=exam, difficulty=difficulty, topics=topics
    )

    try:
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.7,
                "max_output_tokens": 4096,
            },
            request_options={"timeout": 60},
        )
        raw = response.text.strip()
        # Strip markdown code fences if the model wrapped the JSON
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
        questions = json.loads(raw)
        # Validate structure
        valid = []
        for q in questions:
            if (isinstance(q.get("question"), str) and
                    isinstance(q.get("options"), list) and
                    len(q["options"]) == 4 and
                    isinstance(q.get("correct"), int) and
                    0 <= q["correct"] <= 3):
                valid.append({
                    "question":    q["question"],
                    "option_a":    q["options"][0],
                    "option_b":    q["options"][1],
                    "option_c":    q["options"][2],
                    "option_d":    q["options"][3],
                    "correct":     q["correct"],
                    "topic":       q.get("topic", exam),
                    "explanation": q.get("explanation", ""),
                    "type":        "quiz",
                })
        log.info("Gemini generated %d valid quiz questions for %s", len(valid), exam)
        return valid
    except Exception as e:
        log.exception("Gemini quiz generation failed for exam=%s: %s", exam, e)
        return []


# ── Career roadmap ────────────────────────────────────────────────────────────

_ROADMAP_PROMPT = """You are India's top Sarkari Naukri career counselor. Create a personalized exam preparation roadmap for this candidate:

Profile:
- Age: {age} years
- Education: {education}
- State: {state}
- Category: {category}
- Preferred exam type: {exam_type}
- Current preparation level: {prep_level}

Provide a detailed, actionable roadmap. Return ONLY valid JSON (no markdown):
{{
  "summary": "2-3 sentence overview of the candidate's best opportunities",
  "top_exams": [
    {{
      "name": "Exam name",
      "body": "Conducting organization",
      "why_fit": "Why this exam suits this specific profile",
      "eligibility": "Age/education requirement match",
      "competition_level": "Low / Medium / High / Very High",
      "salary": "Starting salary range",
      "timeline": "How long to prepare",
      "phase": "short / medium / long"
    }}
  ],
  "study_plan": {{
    "daily_hours": 4,
    "weekly_schedule": {{
      "monday": "Topic or subject",
      "tuesday": "Topic or subject",
      "wednesday": "Topic or subject",
      "thursday": "Topic or subject",
      "friday": "Topic or subject",
      "saturday": "Topic or subject",
      "sunday": "Revision and mock tests"
    }},
    "key_topics": ["Topic 1", "Topic 2", "Topic 3", "Topic 4", "Topic 5"],
    "books": ["Book 1 by Author", "Book 2 by Author"],
    "free_resources": ["Resource 1", "Resource 2"]
  }},
  "motivational_tip": "One powerful, personalized motivational message for this specific profile",
  "common_mistakes": ["Mistake 1 to avoid", "Mistake 2 to avoid", "Mistake 3 to avoid"]
}}

top_exams: give exactly 3-4 exams best suited for THIS profile.
Be specific to India's 2025-26 exam cycle. Use real exam names and real salary figures.
"""


def generate_career_roadmap(profile: dict) -> dict | None:
    """
    Generate a personalized career roadmap using Gemini Flash.
    profile keys: age, education, state, category, exam_type, prep_level
    Returns the roadmap dict, or None on failure.
    """
    # Use flash instead of pro — response time drops from ~60s to ~8s with
    # comparable quality for structured JSON output. Pro was causing 504s.
    model = _client("gemini-1.5-flash")
    if model is None:
        return None

    prompt = _ROADMAP_PROMPT.format(
        age=profile.get("age", "22"),
        education=profile.get("education", "Graduate"),
        state=profile.get("state", "Any"),
        category=profile.get("category", "General"),
        exam_type=profile.get("exam_type", "Any"),
        prep_level=profile.get("prep_level", "Beginner"),
    )

    try:
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.6,
                "max_output_tokens": 2048,
            },
            request_options={"timeout": 90},
        )
        raw = response.text.strip()
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
        roadmap = json.loads(raw)
        log.info("Gemini career roadmap generated for profile age=%s edu=%s",
                 profile.get("age"), profile.get("education"))
        return roadmap
    except Exception as e:
        log.exception("Gemini roadmap generation failed: %s", e)
        return None
