import os
import json
from pathlib import Path
from typing import Dict, Any
from openai import OpenAI


class RelationshipStatsAgent:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "relationship_statistics_prompt.txt"
        with open(prompt_path, "r", encoding="utf-8") as f:
            self.system_prompt = f.read().strip()

    def _build_input(self, partner_a_transcript: str, partner_b_transcript: str) -> list[dict]:
        user_content = (
            "INPUT (full transcripts)\n"
            "<partner_a>\n" + partner_a_transcript + "\n</partner_a>\n\n"
            "<partner_b>\n" + partner_b_transcript + "\n</partner_b>\n\n"
            "OUTPUT\nReturn STRICT JSON with keys communication, trust_level, future_goals, intimacy. Values must be short labels like 'Great', 'Good', 'Fair', 'Poor'. No prose."
        )
        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": user_content},
        ]

    def generate_stats(self, *, partner_a_transcript: str, partner_b_transcript: str) -> Dict[str, str]:
        try:
            input_messages = self._build_input(partner_a_transcript, partner_b_transcript)
            response = self.client.responses.create(
                model=self.model,
                input=input_messages,
            )
            raw = getattr(response, "output_text", None)
            if not raw:
                parts: list[str] = []
                for block in getattr(response, "output", []) or []:
                    if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                        parts.append(block.text)
                raw = ("".join(parts)) if parts else None
            data: Dict[str, Any] = {}
            if raw:
                try:
                    data = json.loads(raw)
                except Exception:
                    # Try to extract JSON substring
                    start = raw.find("{")
                    end = raw.rfind("}")
                    if start != -1 and end != -1:
                        data = json.loads(raw[start:end+1])
            return {
                "communication": str(data.get("communication", "Unknown")),
                "trust_level": str(data.get("trust_level", "Unknown")),
                "future_goals": str(data.get("future_goals", "Unknown")),
                "intimacy": str(data.get("intimacy", "Unknown")),
            }
        except Exception as e:
            print(f"OpenAI API error in relationship stats generation: {e}")
            return {
                "communication": "Unknown",
                "trust_level": "Unknown",
                "future_goals": "Unknown",
                "intimacy": "Unknown",
            }


