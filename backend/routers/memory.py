from fastapi import APIRouter
from agents.memory_agent import MemoryOrchestratorAgent
from models.schemas import MemorySynthesizeRequest, MemorySynthesizeResponse

router = APIRouter(prefix="/memory", tags=["Memory"])
agent = MemoryOrchestratorAgent()


@router.post("/synthesize", response_model=MemorySynthesizeResponse)
def synthesize_memory(req: MemorySynthesizeRequest):
    """
    Called ONCE per session by the iOS app.
    Receives structured memory data from SwiftData,
    returns a compact coaching context summary cached on the device.
    """
    context_summary = agent.synthesize(
        user_profile=req.user_profile,
        topic_scores=[t.model_dump() for t in req.topic_scores],
        episodic_memories=req.episodic_memories,
        faq_activity=[f.model_dump() for f in req.faq_activity],
    )
    return MemorySynthesizeResponse(context_summary=context_summary)
