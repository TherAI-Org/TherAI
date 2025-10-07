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

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "chat_prompt.txt"
        with open(prompt_path, "r", encoding = "utf-8") as f:
            self.system_prompt = f.read().strip()

        partner_message_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "partner_message_prompt.txt"
        with open(partner_message_prompt_path, "r", encoding = "utf-8") as f:
            self.partner_message_prompt = f.read().strip()

    def generate_response(self, user_message: str, chat_history: list = None,
                          partner_context: list = None, user_a_id = None) -> str:
        try:
            input_messages = [{"role": "system", "content": self.system_prompt}]  # Build input array starting with system prompt

            if chat_history:  # Build context from current user personal chat
                for msg in chat_history:
                    role = "user" if msg.get("role") == "user" else "assistant"
                    input_messages.append({"role": role, "content": msg.get("content", "")})

            if partner_context:  # Build context from partner's personal chat
                partner_text = "Other partner's chat:\n"
                for msg in partner_context:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    partner_text += f"{role}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": partner_text.strip()})

            input_messages.append({"role": "user", "content": user_message})  # Add last user message

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


    # Craft a concise and caring message the user can send to their partner.
    def generate_partner_message(self, user_message: str, chat_history: list = None,
                                 partner_context: list = None, user_a_id = None) -> str:
        try:
            current_context = "Current partner's chat:\n"  # Build current personal context
            if chat_history:
                for msg in chat_history:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    current_context += f"{role}: {msg.get('content', '')}\n"

            other_context = ""  # Build partner's personal chat context
            if partner_context:
                other_context = "\nOther partner's chat:\n"
                for msg in partner_context:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    other_context += f"{role}: {msg.get('content', '')}\n"

            full_context = (
                f"{current_context}{other_context}\n"
                f"User's request: {user_message}"
            )

            input_messages = [
                {"role": "system", "content": self.partner_message_prompt},
                {"role": "user", "content": full_context},
            ]

            resp = self.client.responses.create(model=self.model, input=input_messages)
            text = getattr(resp, "output_text", None)
            if text:
                return text.strip()
            parts = []
            for block in getattr(resp, "output", []) or []:
                if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                    parts.append(block.text)
            return ("".join(parts)).strip() if parts else ""
        except Exception as e:
            print(f"OpenAI API error in partner message generation: {e}")
            return ""
