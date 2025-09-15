import os
from dotenv import load_dotenv
from pathlib import Path
from openai import OpenAI

load_dotenv(dotenv_path = Path(__file__).resolve().parent.parent / ".env")

class PersonalAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "ChatPrompt.txt"
        with open(prompt_path, "r", encoding = "utf-8") as f:
            self.system_prompt = f.read().strip()

    def generate_response(self, user_message: str, chat_history: list = None,
                          dialogue_context: list = None, partner_context: list = None,
                          user_a_id = None) -> str:
        try:
            # Build input array starting with system prompt
            input_messages = [{"role": "system", "content": self.system_prompt}]

            # Build context from current user personal chat
            if chat_history:
                for msg in chat_history:
                    role = "user" if msg.get("role") == "user" else "assistant"
                    input_messages.append({"role": role, "content": msg.get("content", "")})

            # Build context from partner's personal chat
            if partner_context:
                partner_text = "Other partner's chat:\n"
                for msg in partner_context:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    partner_text += f"{role}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": partner_text.strip()})

             # Build dialogue context if available
            if dialogue_context:
                dialogue_text = "Previous dialogue between partners:\n"
                a_id = str(user_a_id) if user_a_id is not None else None
                for msg in dialogue_context:
                    sender_id = str(msg.get("sender_user_id")) if msg.get("sender_user_id") is not None else None
                    if sender_id and a_id and sender_id == a_id:
                        label = "Partner A:"
                    else:
                        label = "Partner B:"
                    dialogue_text += f"{label}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": dialogue_text.strip()})

            # Add last user message
            input_messages.append({"role": "user", "content": user_message})

            response = self.client.responses.create(
                model = self.model,
                input = input_messages,
            )

            if hasattr(response, "output_text") and response.output_text:
                return response.output_text.strip()
            parts = []
            for block in getattr(response, "output", []) or []:
                if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                    parts.append(block.text)
            if parts:
                return "".join(parts).strip()

            return ""

        except Exception as e:
            print(f"OpenAI API error: {e}")
            return ""
