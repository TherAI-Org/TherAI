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

        dialogue_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "DialoguePrompt.txt"
        with open(dialogue_prompt_path, "r", encoding = "utf-8") as f:
            self.dialogue_prompt = f.read().strip()

    def generate_dialogue_response(self, current_partner_history: list, other_partner_history: list = None,
                                   dialogue_history: list = None, user_a_id = None) -> str:
        try:
            # Build context from current user personal chat
            current_context = "Current partner's chat:\n"
            for msg in current_partner_history:
                role = "User" if msg.get("role") == "user" else "Assistant"
                current_context += f"{role}: {msg.get('content', '')}\n"

            # Build context from partner's personal chat
            other_context = ""
            if other_partner_history:
                other_context = "\nOther partner's chat:\n"
                for msg in other_partner_history:
                    role = "User" if msg.get("role") == "user" else "Assistant"
                    other_context += f"{role}: {msg.get('content', '')}\n"

            # Build dialogue context if available
            dialogue_context_text = ""
            if dialogue_history:
                dialogue_context_text = "\nPrevious dialogue between partners:\n"
                for msg in dialogue_history:
                    try:
                        sender_id = str(msg.get('sender_user_id')) if msg.get('sender_user_id') is not None else None
                        a_id = str(user_a_id) if user_a_id is not None else None
                    except Exception:
                        sender_id = msg.get('sender_user_id')
                        a_id = str(user_a_id) if user_a_id is not None else None

                    if sender_id and a_id and sender_id == a_id:
                        label = "Partner A:"
                    else:
                        label = "Partner B:"

                    dialogue_context_text += f"{label}: {msg.get('content', '')}\n"

            full_context = f"{current_context}{other_context}{dialogue_context_text}"

            input_messages = [
                {"role": "system", "content": self.dialogue_prompt},
                {"role": "user", "content": full_context}
            ]

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
            print(f"OpenAI API error in dialogue generation: {e}")
            return ""
