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

    def _is_ask_about_partner(self, user_message: str) -> bool:
        """Return True if the user is asking what the partner said/happened."""
        if not user_message:
            return False
        text = user_message.lower().strip()
        triggers = [
            "what happened",
            "what did he say",
            "what did she say",
            "what did they say",
            "what did my partner say",
            "what was that",
            "what did he send",
            "what did she send",
            "what did they send",
            "what did my partner send",
            "what did they just say",
            "what did he just say",
            "what did she just say",
            "what did my partner just say",
            "what did they just send",
            "what did my partner just send",
        ]
        return any(phrase in text for phrase in triggers)

    def _get_latest_partner_dialogue_message(self, dialogue_context: list, user_a_id) -> str | None:
        """Extract the latest message from the other partner in the dialogue."""
        if not dialogue_context:
            return None
        a_id = str(user_a_id) if user_a_id is not None else None
        for msg in reversed(dialogue_context):
            sender_id = str(msg.get("sender_user_id")) if msg.get("sender_user_id") is not None else None
            # If we know user A id, pick the first message whose sender is not A (i.e., the partner)
            if a_id is not None:
                if sender_id != a_id:
                    content = msg.get("content", "")
                    return content.strip() if isinstance(content, str) else None
            else:
                # If we don't know which is A, assume last message is the one just received
                content = msg.get("content", "")
                return content.strip() if isinstance(content, str) else None
        return None

    def _get_latest_partner_personal_message(self, partner_context: list) -> str | None:
        """Fallback: use partner's last 'user' message from their personal chat."""
        if not partner_context:
            return None
        for msg in reversed(partner_context):
            role = msg.get("role")
            if role == "user":
                content = msg.get("content", "")
                return content.strip() if isinstance(content, str) else None
        return None

    def generate_response(self, user_message: str, chat_history: list = None,
                          dialogue_context: list = None, partner_context: list = None,
                          user_a_id = None) -> str:
        try:
            # Fast-path: if the user is asking what the partner said, surface it immediately
            if self._is_ask_about_partner(user_message):
                latest = self._get_latest_partner_dialogue_message(dialogue_context, user_a_id)
                if not latest:
                    latest = self._get_latest_partner_personal_message(partner_context)
                if latest:
                    return latest

            # Build input array starting with system prompt
            input_messages = [{"role": "system", "content": self.system_prompt}]

            # PRIORITIZE: partner-provided context first so the model uses it immediately
            if partner_context:
                partner_text = "Other partner's chat:\n"
                for msg in partner_context:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    partner_text += f"{role}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": partner_text.strip()})

            # Include prior dialogue between partners next
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

            # Build context from current user personal chat
            if chat_history:
                for msg in chat_history:
                    role = "user" if msg.get("role") == "user" else "assistant"
                    input_messages.append({"role": role, "content": msg.get("content", "")})

            # Add last user message
            input_messages.append({"role": "user", "content": user_message})

            response = self.client.responses.create(
                model = self.model,
                input = input_messages,
                max_output_tokens = self.max_output_tokens,
                temperature = self.temperature,
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
