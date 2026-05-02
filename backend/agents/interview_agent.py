import json
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


class InterviewAgent:
    def __init__(self):
        self.client = Groq(api_key=os.environ["GROQ_API_KEY"])

    def _domain_guidance(self, domain: str) -> str:
        if domain == "behavioral":
            return (
                "Ask STAR-format behavioral questions only (Situation, Task, Action, Result). "
                "Examples: 'Tell me about a time you...', 'Describe a situation where...', "
                "'Give me an example of...'. Never ask technical or coding questions."
            )
        elif domain == "system-design":
            return (
                "Ask system design questions only. Examples: design a URL shortener, "
                "design a chat system, design a rate limiter. Never ask coding or behavioral questions."
            )
        else:
            return f"Ask {domain} questions only. Never drift into other domains."

    def _system(self, role: str, level: str, domain: str, context: str) -> str:
        return (
            f"You are an experienced interviewer.\n\n"
            f"CANDIDATE CONTEXT (for tone and difficulty calibration only):\n{context}\n\n"
            f"You are conducting a {level}-level {role} interview.\n"
            f"DOMAIN: {domain.upper()} — {self._domain_guidance(domain)}\n"
            "Ask one question at a time. Be concise and professional."
        )

    def start(self, role: str, level: str, domain: str, context: str) -> str:
        return _complete_with_retry(
            self.client,
            model=MODEL,
            max_tokens=300,
            messages=[
                {"role": "system", "content": self._system(role, level, domain, context)},
                {"role": "user", "content": f"Ask the opening question for this {domain} interview. Return only the question, no preamble."},
            ],
        )

    def evaluate(
        self,
        role: str,
        level: str,
        domain: str,
        context: str,
        session_delta: str,
        history: List[Dict[str, str]],
        answer: str,
    ) -> Dict[str, Any]:
        conversation = "\n".join(f"{m['role'].upper()}: {m['content']}" for m in history)
        delta_section = f"\nIN-SESSION PROGRESS:\n{session_delta}" if session_delta else ""

        user_prompt = (
            f"{delta_section}\n\nCONVERSATION:\n{conversation}\nCANDIDATE: {answer}\n\n"
            f"Evaluate the candidate's last answer. The next_question MUST be about {domain}. Return JSON only:\n"
            '{"scores":{"clarity":0-100,"correctness":0-100,"communication":0-100,"edge_cases":0-100},'
            '"feedback":"2-3 sentence constructive feedback",'
            '"topic":"concept tested",'
            '"next_question":"follow-up or new question strictly about ' + domain + '"}'
        )
        text = _complete_with_retry(
            self.client,
            model=MODEL,
            max_tokens=600,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": self._system(role, level, domain, context)},
                {"role": "user", "content": user_prompt},
            ],
        )
        return json.loads(text)

    def summarise(
        self,
        role: str,
        level: str,
        context: str,
        session_delta: str,
        scores: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        score_lines = "\n".join(
            f"Q{i+1}: clarity={s.get('clarity',0)} correctness={s.get('correctness',0)} "
            f"communication={s.get('communication',0)} edge_cases={s.get('edge_cases',0)}"
            for i, s in enumerate(scores)
        )
        prompt = (
            f"CANDIDATE CONTEXT:\n{context}\n\n"
            f"IN-SESSION PROGRESS:\n{session_delta}\n\n"
            f"SESSION SCORES:\n{score_lines}\n\n"
            f"Summarise this {level}-level {role} interview. Return JSON only:\n"
            '{"overall_score":0-100,"strong_areas":["up to 3"],"weak_spots":["up to 3"],'
            '"summary":"2-3 sentence assessment","next_focus":"most important topic to study next"}'
        )
        text = _complete_with_retry(
            self.client,
            model=MODEL,
            max_tokens=400,
            response_format={"type": "json_object"},
            messages=[{"role": "user", "content": prompt}],
        )
        return json.loads(text)
