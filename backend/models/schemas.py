from typing import Any, Dict, List, Optional
from pydantic import BaseModel


# ── Memory Orchestrator ───────────────────────────────────────────────────────

class TopicScore(BaseModel):
    topic: str
    scores: List[float]          # historical scores oldest→newest


class FAQActivity(BaseModel):
    topic: str
    times_asked: int
    avg_self_grade: float        # 1–5


class MemorySynthesizeRequest(BaseModel):
    user_profile: Dict[str, str] # name, role, level, target, interview_date
    topic_scores: List[TopicScore]
    episodic_memories: List[str] # last 3–5 session summaries
    faq_activity: List[FAQActivity]


class MemorySynthesizeResponse(BaseModel):
    context_summary: str         # ~200 tokens, cached on iOS for full session


# ── Interview (fully stateless) ───────────────────────────────────────────────

class StartInterviewRequest(BaseModel):
    role: str
    level: str
    domain: str
    context: str                 # coaching summary from /memory/synthesize


class StartInterviewResponse(BaseModel):
    question: str


class Message(BaseModel):
    role: str                    # interviewer | candidate
    content: str


class RubricScores(BaseModel):
    clarity: float
    correctness: float
    communication: float
    edge_cases: float


class SubmitAnswerRequest(BaseModel):
    role: str
    level: str
    domain: str
    context: str                 # cached coaching summary
    session_delta: str           # built locally on iOS after each turn
    history: List[Message]       # full conversation so far
    answer: str


class SubmitAnswerResponse(BaseModel):
    scores: RubricScores
    feedback: str
    topic: str
    next_question: str


class SummariseRequest(BaseModel):
    role: str
    level: str
    context: str
    session_delta: str
    scores: List[Dict[str, Any]] # [{topic, clarity, correctness, communication, edge_cases}]


class SummariseResponse(BaseModel):
    overall_score: float
    strong_areas: List[str]
    weak_spots: List[str]
    summary: str
    next_focus: str


# ── FAQ (fully stateless) ────────────────────────────────────────────────────

class FlashcardContext(BaseModel):
    question: str
    answer: str
    topic: str


class AskQuestionRequest(BaseModel):
    question: str
    topic: Optional[str] = None
    context: str                       # coaching summary
    relevant_flashcards: List[FlashcardContext] = []  # iOS passes related cards


class AskQuestionResponse(BaseModel):
    answer: str
    related_topics: List[str]
    save_as_flashcard: bool


class GenerateFAQRequest(BaseModel):
    notes: str
    topic: str


class GeneratedFlashcard(BaseModel):
    question: str
    answer: str


class GenerateFAQResponse(BaseModel):
    flashcards: List[GeneratedFlashcard]
    topic: str
