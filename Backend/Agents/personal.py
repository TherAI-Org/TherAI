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

        partner_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "partner_prompt.txt"
        with open(partner_prompt_path, "r", encoding = "utf-8") as f:
            self.partner_prompt = f.read().strip()

        detection_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "partner_msg_help_prompt.txt"
        with open(detection_prompt_path, "r", encoding = "utf-8") as f:
            self.partner_detection_prompt = f.read().strip()

        context_offer_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "partner_msg_craft_prompt.txt"
        with open(context_offer_prompt_path, "r", encoding = "utf-8") as f:
            self.context_offer_prompt = f.read().strip()

    def generate_response(self, user_message: str, chat_history: list = None,
                          partner_context: list = None, user_a_id = None) -> str:
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

    def _should_offer_partner_message(self, user_message: str, chat_history: list = None) -> bool:
        """Context-aware detection that considers conversation history for subtle relationship cues."""
        try:
            if not user_message:
                return False

            # Build conversation context for better detection
            conversation_context = ""
            if chat_history:
                conversation_context = "Recent conversation:\n"
                for msg in chat_history[-5:]:  # Last 5 messages for context
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    conversation_context += f"{role}: {msg.get('content', '')}\n"
                conversation_context += "\nCurrent message: "

            user_context = f"{conversation_context}{user_message}"
            messages = [
                {"role": "system", "content": self.context_offer_prompt},
                {"role": "user", "content": user_context},
            ]
            resp = self.client.responses.create(model = self.model, input = messages, temperature = 0)
            text = getattr(resp, "output_text", None)
            if not text:
                parts = []
                for block in getattr(resp, "output", []) or []:
                    if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                        parts.append(block.text)
                text = "".join(parts) if parts else ""
            verdict = (text or "").strip().upper()
            return verdict.startswith("YES")
        except Exception as e:
            print(f"Context-aware partner message detection error: {e}")
            return False

    def _is_requesting_partner_message(self, user_message: str) -> bool:
        try:
            if not user_message:
                return False

            messages = [
                {"role": "system", "content": self.partner_detection_prompt},
                {"role": "user", "content": f"User: {user_message}"},
            ]
            resp = self.client.responses.create(model = self.model, input = messages, temperature = 0)
            text = getattr(resp, "output_text", None)
            if not text:
                parts = []
                for block in getattr(resp, "output", []) or []:
                    if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                        parts.append(block.text)
                text = "".join(parts) if parts else ""
            verdict = (text or "").strip().upper()
            return verdict.startswith("YES")
        except Exception as e:
            print(f"Partner message detection error: {e}")
            return False

    def generate_partner_message(self, user_message: str, chat_history: list = None,
                                 partner_context: list = None, user_a_id = None) -> str:
        """Craft a concise, caring message the user can send to their partner.

        Uses the partner prompt and combines current personal chat and the partner's
        personal chat (if available).
        """
        try:
            # Build current personal context
            current_context = "Current partner's chat:\n"
            if chat_history:
                for msg in chat_history:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    current_context += f"{role}: {msg.get('content', '')}\n"

            # Build partner's personal chat context
            other_context = ""
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
                {"role": "system", "content": self.partner_prompt},
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
