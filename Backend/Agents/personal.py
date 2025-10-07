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

        send_detection_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "send_detection_prompt.txt"
        with open(send_detection_prompt_path, "r", encoding = "utf-8") as f:
            self.send_detection_prompt = f.read().strip()

        title_generation_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "chat_title_generation_prompt.txt"
        with open(title_generation_prompt_path, "r", encoding = "utf-8") as f:
            self.title_generation_prompt = f.read().strip()

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

    # Detect if user wants a message crafted for their partner (invokes the 'send to partner' feature)
    def should_offer_partner_message(self, user_message: str, chat_history: list | None = None) -> bool:
        try:
            if not user_message:
                return False

            # Build a minimal context from the last 15 messages if provided
            messages = [{"role": "system", "content": self.send_detection_prompt}]
            if chat_history:
                recent = chat_history[-15:]
                context_lines = []
                for m in recent:
                    role = "User" if m.get("role") == "user" else "Assistant"
                    context_lines.append(f"{role}: {m.get('content','')}")
                context_block = "Recent conversation (last 15 messages):\n" + "\n".join(context_lines)
                messages.append({"role": "system", "content": context_block})

            messages.append({"role": "user", "content": user_message})
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

    # Generate a short, descriptive title for a chat session based on user message(s)
    # Can be called with just the first message, or with conversation context for better titles
    def generate_chat_title(self, user_messages: list[str]) -> str:
        try:
            if not user_messages or not any(msg.strip() for msg in user_messages):
                return "New chat"

            # Combine all user messages for context
            combined = " ... ".join(msg.strip() for msg in user_messages if msg.strip())

            input_messages = [
                {"role": "system", "content": self.title_generation_prompt},
                {"role": "user", "content": combined}
            ]

            resp = self.client.responses.create(
                model=self.model,
                input=input_messages,
                temperature=0.8  # Higher temperature for more variety and creativity
            )

            text = getattr(resp, "output_text", None)
            if not text:
                parts = []
                for block in getattr(resp, "output", []) or []:
                    if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                        parts.append(block.text)
                text = "".join(parts) if parts else ""

            title = text.strip()

            # Clean up the title (remove quotes, extra punctuation)
            title = title.strip('"\'""''')
            
            # Fallback if title is empty or too long
            if not title or len(title) > 60:
                return "New chat"

            return title

        except Exception as e:
            print(f"OpenAI API error in chat title generation: {e}")
            return "New chat"