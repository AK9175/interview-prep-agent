import json
import os
import time
from typing import Any, Dict, List, Optional

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


class FAQAgent:
    def __init__(self):
        self.client = Groq(api_key=os.environ["GROQ_API_KEY"])

    def answer(
        self,
        question: str,
        context: str,
        relevant_flashcards: List[Dict[str, str]],
        topic: Optional[str] = None,
    ) -> Dict[str, Any]:
        flashcard_context = ""
        if relevant_flashcards:
            cards = "\n".join(f"Q: {c['question']}\nA: {c['answer']}" for c in relevant_flashcards)
            flashcard_context = f"\nRELEVANT FLASHCARDS:\n{cards}\n"

        prompt = (
            "You are a personal technical study assistant.\n\n"
            f"CANDIDATE CONTEXT:\n{context}\n"
            f"{flashcard_context}\n"
            f"QUESTION: {question}\n\n"
            "Personalise your answer using the candidate context. Return JSON only:\n"
            '{"answer":"clear concise explanation 2-4 sentences",'
            '"related_topics":["2-3 related topics"],'
            '"save_as_flashcard":true or false}'
        )
        text = _complete_with_retry(
            self.client,
            model=MODEL,
            max_tokens=400,
            response_format={"type": "json_object"},
            messages=[{"role": "user", "content": prompt}],
        )
        return json.loads(text)

    def generate_flashcards(self, notes: str, topic: str) -> List[Dict[str, str]]:
        prompt = (
            f"Convert these study notes into flashcards for topic: {topic}\n\n"
            f"NOTES:\n{notes}\n\n"
            "Return a JSON object with a 'flashcards' array of 5-15 cards:\n"
            '{"flashcards":[{"question":"...","answer":"concise 1-3 sentence answer"}]}'
        )
        text = _complete_with_retry(
            self.client,
            model=MODEL,
            max_tokens=2000,
            response_format={"type": "json_object"},
            messages=[{"role": "user", "content": prompt}],
        )
        data = json.loads(text)
        return data.get("flashcards", data) if isinstance(data, dict) else data
