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

        title_generation_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "chat_title_generation_prompt.txt"
        with open(title_generation_prompt_path, "r", encoding = "utf-8") as f:
            self.title_generation_prompt = f.read().strip()

    def generate_response(self, user_message: str, chat_history: list = None,
                          partner_context: list = None, user_a_id = None) -> str:
        try:
            input_messages = [{"role": "system", "content": self.system_prompt}]  # Start with system prompt only

            # If partner context is provided by the caller, inject it as a labeled system block
            if partner_context:
                partner_text = "Partner context — treat this as what THEY said; generate a response for the CURRENT USER to send.\n"
                for msg in partner_context:
                    role = "Partner" if msg.get("role") == "user" else "AI Assistant to Partner"
                    partner_text += f"{role}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": partner_text.strip()})

            # Final reminder so the model uses the UI block tag when suggesting a partner message
            input_messages.append({
                "role": "system",
                "content": "MANDATORY: Wrap any partner-intended text strictly inside <partner_message>…</partner_message>. No duplicates outside the tags."
            })

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