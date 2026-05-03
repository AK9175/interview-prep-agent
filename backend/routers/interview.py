from fastapi import APIRouter
from agents.interview_agent import InterviewAgent
from models.schemas import (
    StartInterviewRequest, StartInterviewResponse,
    SubmitAnswerRequest, SubmitAnswerResponse, RubricScores,
    SummariseRequest, SummariseResponse,
)

router = APIRouter(prefix="/interview", tags=["Interview"])
agent = InterviewAgent()


@router.post("/start", response_model=StartInterviewResponse)
def start_interview(req: StartInterviewRequest):
    """
    Returns the opening interview question.
    Context summary (from /memory/synthesize) guides topic selection.
    No DB reads or writes — fully stateless.
    """
    question = agent.start(req.role, req.level, req.domain, req.context)
    return StartInterviewResponse(question=question)


@router.post("/answer", response_model=SubmitAnswerResponse)
def submit_answer(req: SubmitAnswerRequest):
    """
    Evaluates the candidate's answer.
    Receives full conversation history and session delta from iOS.
    Returns rubric scores + next question.
    No DB reads or writes — fully stateless.
    """
    result = agent.evaluate(
        role=req.role,
        level=req.level,
        domain=req.domain,
        context=req.context,
        session_delta=req.session_delta,
        history=[m.model_dump() for m in req.history],
        answer=req.answer,
    )
    return SubmitAnswerResponse(
        scores=RubricScores(**result["scores"]),
        feedback=result["feedback"],
        topic=result["topic"],
        next_question=result["next_question"],
    )


@router.post("/summarise", response_model=SummariseResponse)
def summarise_session(req: SummariseRequest):
    """
    Generates end-of-session summary + episodic memory note.
    iOS saves the result to SwiftData locally.
    No DB reads or writes — fully stateless.
    """
    result = agent.summarise(
        role=req.role,
        level=req.level,
        context=req.context,
        session_delta=req.session_delta,
        scores=req.scores,
    )
    return SummariseResponse(**result)
