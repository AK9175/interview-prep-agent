from fastapi import APIRouter
from agents.faq_agent import FAQAgent
from models.schemas import (
    AskQuestionRequest, AskQuestionResponse,
    GenerateFAQRequest, GenerateFAQResponse, GeneratedFlashcard,
)

router = APIRouter(prefix="/faq", tags=["FAQ"])
agent = FAQAgent()


@router.post("/ask", response_model=AskQuestionResponse)
def ask_question(req: AskQuestionRequest):
    """
    Answers a technical question using candidate context + relevant flashcards
    passed from SwiftData on the device. No DB reads or writes.
    """
    result = agent.answer(
        question=req.question,
        context=req.context,
        relevant_flashcards=[f.model_dump() for f in req.relevant_flashcards],
        topic=req.topic,
    )
    return AskQuestionResponse(
        answer=result["answer"],
        related_topics=result.get("related_topics", []),
        save_as_flashcard=result.get("save_as_flashcard", False),
    )


@router.post("/generate", response_model=GenerateFAQResponse)
def generate_flashcards(req: GenerateFAQRequest):
    """
    Converts raw notes into flashcards.
    Returns the flashcard list — iOS saves them to SwiftData.
    No DB reads or writes.
    """
    cards = agent.generate_flashcards(req.notes, req.topic)
    return GenerateFAQResponse(
        flashcards=[GeneratedFlashcard(**c) for c in cards],
        topic=req.topic,
    )
