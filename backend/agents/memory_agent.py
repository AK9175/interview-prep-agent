import os
import time
from typing import Any, Dict, List

from groq import Groq, RateLimitError, InternalServerError

MODEL = "llama-3.3-70b-versatile"


def _complete_with_retry(client: Groq, **kwargs) -> str:
    for attempt in range(4):
        try:
            response = client.chat.completions.create(**kwargs)
            return response.choices[0].message.content.strip()
        except (RateLimitError, InternalServerError):
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("unreachable")


class MemoryOrchestratorAgent:
    def __init__(self):
        self.client = Groq(api_key=os.environ["GROQ_API_KEY"])

    def synthesize(
        self,
        user_profile: Dict[str, str],
        topic_scores: List[Dict[str, Any]],
        episodic_memories: List[str],
        faq_activity: List[Dict[str, Any]],
    ) -> str:
        score_lines = []
        for t in topic_scores:
            scores = t["scores"]
            trend = "→".join(str(int(s)) for s in scores)
            avg = sum(scores) / len(scores)
            direction = (
                "improving" if len(scores) > 1 and scores[-1] > scores[0]
                else "declining" if len(scores) > 1 and scores[-1] < scores[0]
                else "stable"
            )
            score_lines.append(f"  {t['topic']}: {trend} (avg {avg:.0f}, {direction})")

        scores_text = "\n".join(score_lines) if score_lines else "  No sessions yet"
        episodes_text = "\n".join(
            f"  Session {i+1}: {mem}" for i, mem in enumerate(episodic_memories[-5:])
        ) if episodic_memories else "  No previous sessions"
        faq_text = "\n".join(
            f"  {f['topic']}: asked {f['times_asked']}x, self-grade {f['avg_self_grade']:.1f}/5"
            for f in faq_activity
        ) if faq_activity else "  No FAQ activity yet"

        prompt = (
            "You are a coaching coordinator for an AI interview prep platform. "
            "Analyse the candidate's memory data and write a concise coaching brief "
            "(max 250 tokens) that an AI interviewer and tutor will use as context.\n\n"
            "Include: top 1-2 priority topics, topics to avoid, patterns worth surfacing, "
            "recommended coaching tone, and one specific tip based on FAQ activity.\n\n"
            f"CANDIDATE:\n"
            f"  Name: {user_profile.get('name','Unknown')}\n"
            f"  Role: {user_profile.get('role','SWE')} | Level: {user_profile.get('level','mid')}\n"
            f"  Target: {user_profile.get('target','General')} | Interview: {user_profile.get('interview_date','TBD')}\n\n"
            f"TOPIC PERFORMANCE:\n{scores_text}\n\n"
            f"RECENT SESSIONS:\n{episodes_text}\n\n"
            f"FAQ ACTIVITY:\n{faq_text}\n\n"
            "Write the coaching brief now:"
        )

        return _complete_with_retry(
            self.client,
            model=MODEL,
            max_tokens=300,
            messages=[{"role": "user", "content": prompt}],
        )
