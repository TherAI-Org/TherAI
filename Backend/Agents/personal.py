import os
from dotenv import load_dotenv
from pathlib import Path
from openai import OpenAI

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

class PersonalAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "ChatPrompt.txt"
        with open(prompt_path, "r", encoding="utf-8") as f:
            self.system_prompt = f.read().strip()


    def generate_response(self, user_message: str, chat_history: list = None,
                         dialogue_context: list = None, partner_context: list = None) -> str:
        try:
            # Build input array starting with system prompt
            input_messages = [{"role": "system", "content": self.system_prompt}]

            # Add chat history if provided
            if chat_history:
                for msg in chat_history:
                    role = "user" if msg.get("role") == "user" else "assistant"
                    input_messages.append({"role": role, "content": msg.get("content", "")})

            # Add dialogue context if provided
            if dialogue_context:
                dialogue_text = "DIALOGUE CONTEXT (Shared conversations with partner):\n"
                for msg in dialogue_context:
                    sender = "Partner" if msg.get("message_type") == "request" else "AI Mediator"
                    dialogue_text += f"{sender}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": dialogue_text.strip()})

            # Add partner context if provided
            if partner_context:
                partner_text = "PARTNER CONTEXT (Partner's recent personal thoughts):\n"
                for msg in partner_context:
                    role = "Partner" if msg.get("role") == "user" else "AI Assistant to Partner"
                    partner_text += f"{role}: {msg.get('content', '')}\n"
                input_messages.append({"role": "system", "content": partner_text.strip()})

            # Add the current user message
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

            return "I apologize, but I couldn't generate a response."

        except Exception as e:
            print(f"OpenAI API error: {e}")
            return f"I apologize, but I encountered an error while processing your request: {str(e)}"
