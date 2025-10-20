import os
from pathlib import Path
from typing import List, Optional
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path = Path(__file__).resolve().parent.parent / ".env")

class ChatAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "chat_prompt.txt"
        with open(prompt_path, "r", encoding = "utf-8") as f:
            self.system_prompt = f.read().strip()

    def build_messages(self, *, session_partner_letter: str, last_user_message: str, partner_ab_context_text: Optional[str] = None) -> List[dict]:
        input_messages: List[dict] = [
            {"role": "system", "content": f"I'm Partner {session_partner_letter}"},
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": f"last user message: {last_user_message}"},
        ]

        if partner_ab_context_text:
            input_messages.append({"role": "system", "content": partner_ab_context_text})

        return input_messages

    def create_response(self, *, messages: List[dict], previous_response_id: Optional[str] = None):
        return self.client.responses.create(
            model = self.model,
            input = messages,
            previous_response_id = previous_response_id,
        )


