import os
from dotenv import load_dotenv
from pathlib import Path
from openai import OpenAI

load_dotenv(dotenv_path = Path(__file__).resolve().parent.parent / ".env")

class PersonalInsightAgent:
    def __init__(self):
        self.client = OpenAI(api_key = os.getenv("OPENAI_API_KEY"))
        model = os.getenv("OPENAI_MODEL")
        if not model:
            raise ValueError("Missing OPENAI_MODEL in environment")
        self.model = model

        prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "personal_dialogue_insight.txt"
        with open(prompt_path, "r", encoding = "utf-8") as f:
            self.system_prompt = f.read().strip()

    def build_context(self, current_personal_history: list, partner_personal_history: list, dialogue_history: list, dialogue_message: str, user_a_id = None) -> list:
        # Build context strings
        current_context = "Current partner's recent personal thoughts:\n" + "".join([
            ("You" if msg.get("role") == "user" else "Your AI Assistant") + f": {msg.get('content', '')}\n" for msg in current_personal_history
        ])

        partner_context = ""
        if partner_personal_history:
            partner_context = "\nOther partner's recent personal thoughts:\n" + "".join([
                ("Partner" if msg.get("role") == "user" else "AI Assistant") + f": {msg.get('content', '')}\n" for msg in partner_personal_history
            ])

        dialogue_context_text = ""
        if dialogue_history:
            lines = []
            a_id = str(user_a_id) if user_a_id is not None else None
            for msg in dialogue_history:
                sender_id = str(msg.get('sender_user_id')) if msg.get('sender_user_id') is not None else None
                label = "Partner A:" if (sender_id and a_id and sender_id == a_id) else "Partner B:"
                lines.append(f"{label} {msg.get('content', '')}\n")
            dialogue_context_text = "\nPrevious dialogue between partners:\n" + "".join(lines)

        target_text = f"\nDialogue message to analyze:\n{dialogue_message}\n"

        full_context = f"{current_context}{partner_context}{dialogue_context_text}{target_text}"
        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": full_context}
        ]

    def generate_insight(self, current_personal_history: list, partner_personal_history: list, dialogue_history: list, dialogue_message: str, user_a_id = None) -> str:
        try:
            input_messages = self.build_context(current_personal_history, partner_personal_history, dialogue_history, dialogue_message, user_a_id)
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
            print(f"OpenAI API error in insight generation: {e}")
            return ""

