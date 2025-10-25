import os
from dotenv import load_dotenv
from pathlib import Path
from openai import OpenAI

load_dotenv(dotenv_path = Path(__file__).resolve().parent.parent / ".env")

class ChatTitleAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        self.model = "gpt-5-mini"

        title_generation_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "chat_title_generation_prompt.txt"
        with open(title_generation_prompt_path, "r", encoding = "utf-8") as f:
            self.title_generation_prompt = f.read().strip()

    def generate_chat_title(self, user_messages: list[str]) -> str:
        try:
            combined = " ... ".join(msg.strip() for msg in user_messages if msg and msg.strip())
            if not combined:
                return "New chat"

            input_messages = [
                {"role": "system", "content": self.title_generation_prompt},
                {"role": "user", "content": combined},
            ]

            resp = self.client.responses.create(
                model = self.model,
                input = input_messages,
                temperature = 0.8,
            )

            text = getattr(resp, "output_text", None) or "".join(
                block.text
                for block in getattr(resp, "output", [])
                if getattr(block, "type", None) == "output_text" and getattr(block, "text", None)
            )

            title = (text or "").strip().strip('"\'')
            return title
        except Exception as e:
            print(f"OpenAI API error in chat title generation: {e}")
            return "New chat"


