import os
from dotenv import load_dotenv
from pathlib import Path
from openai import OpenAI

load_dotenv(dotenv_path = Path(__file__).resolve().parent.parent / ".env")


class RelationshipHealthAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "iOS" / "relationship_health_prompt.txt"
        with open(prompt_path, "r", encoding = "utf-8") as f:
            self.system_prompt = f.read().strip()

    def _build_input(self, partner_a_transcript: str, partner_b_transcript: str) -> list[dict]:
        user_content = (
            "INPUT (full transcripts)\n"
            "<partner_a>\n" + partner_a_transcript + "\n</partner_a>\n\n"
            "<partner_b>\n" + partner_b_transcript + "\n</partner_b>\n\n"
            "OUTPUT\nReturn one paragraph with 3–4 sentences as specified above. No JSON, no bullet points, no headers—just the paragraph."
        )
        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": user_content},
        ]

    def generate_summary(self, *, partner_a_transcript: str, partner_b_transcript: str) -> str:
        try:
            input_messages = self._build_input(partner_a_transcript, partner_b_transcript)
            response = self.client.responses.create(
                model = self.model,
                input = input_messages,
            )
            if hasattr(response, "output_text") and response.output_text:
                return response.output_text.strip()
            parts: list[str] = []
            for block in getattr(response, "output", []) or []:
                if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                    parts.append(block.text)
            return ("".join(parts)).strip()
        except Exception as e:
            print(f"OpenAI API error in relationship health generation: {e}")
            return ""


