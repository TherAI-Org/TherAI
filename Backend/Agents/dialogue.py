import os
from dotenv import load_dotenv
from pathlib import Path
from openai import OpenAI

load_dotenv(dotenv_path = Path(__file__).resolve().parent.parent / ".env")

class DialogueAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        # Load unified dialogue prompt (handles both greeting and continuation)
        dialogue_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "DialoguePrompt.txt"
        with open(dialogue_prompt_path, "r", encoding="utf-8") as f:
            self.dialogue_prompt = f.read().strip()

    def generate_dialogue_response(self, current_partner_history: list, other_partner_history: list = None,
                                  dialogue_history: list = None, partner_name: str = None) -> str:
        """Generate dialogue message handling both first-time and continuation scenarios"""
        try:
            # Build context from current partner's personal chat
            current_context = "Current partner's personal thoughts:\n"
            for msg in current_partner_history:
                role = "User" if msg.get("role") == "user" else "AI Assistant"
                current_context += f"{role}: {msg.get('content', '')}\n"

            # Build other partner's context if available
            other_context = ""
            if other_partner_history:
                other_context = "\nOther partner's personal thoughts:\n"
                for msg in other_partner_history:
                    role = "User" if msg.get("role") == "user" else "AI Assistant"
                    other_context += f"{role}: {msg.get('content', '')}\n"

            # Build dialogue context if available
            dialogue_context_text = ""
            if dialogue_history:
                dialogue_context_text = "\nPrevious dialogue between partners:\n"
                for msg in dialogue_history:
                    sender = "Partner" if msg.get('message_type') == 'request' else "AI Mediator"
                    dialogue_context_text += f"{sender}: {msg.get('content', '')}\n"

            # Add partner name context
            name_context = f"Partner's name: {partner_name}\n" if partner_name else "Partner's name: Unknown\n"

            # Combine all context
            full_context = f"{name_context}\n{current_context}{other_context}{dialogue_context_text}\n\nPlease facilitate this conversation between partners."

            input_messages = [
                {"role": "system", "content": self.dialogue_prompt},
                {"role": "user", "content": full_context}
            ]

            response = self.client.responses.create(
                model=self.model,
                input=input_messages,
            )

            if hasattr(response, "output_text") and response.output_text:
                return response.output_text.strip()

            parts = []
            for block in getattr(response, "output", []) or []:
                if getattr(block, "type", None) == "output_text" and getattr(block, "text", None):
                    parts.append(block.text)
            if parts:
                return "".join(parts).strip()

            return "I'd like to help facilitate this conversation between you and your partner."

        except Exception as e:
            print(f"OpenAI API error in dialogue generation: {e}")
            return f"I'm here to help you and your partner understand each other better."

