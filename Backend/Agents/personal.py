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

        # Dialogue prompt to craft messages for the partner
        try:
            dialogue_prompt_path = Path(__file__).resolve().parent.parent / "Prompts" / "DialoguePrompt.txt"
            with open(dialogue_prompt_path, "r", encoding = "utf-8") as f:
                self.dialogue_prompt = f.read().strip()
        except Exception:
            self.dialogue_prompt = "You help write supportive, clear messages for a romantic partner."

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

            context_aware_prompt = (
                "You are analyzing a personal therapy conversation to detect if someone is explicitly "
                "asking for help with WHAT TO SAY to their romantic partner.\n\n"
                
                "Consider the conversation context and current message together. Look for:\n"
                "- Direct requests for help with wording/phrasing for their partner\n"
                "- Questions about how to communicate something specific to their partner\n"
                "- Requests for message suggestions to send to their partner\n\n"
                
                "Only say YES if the conversation context clearly shows the person wants help with "
                "expressing something specific to their partner, not just general relationship support.\n\n"
                
                "Be conservative. Only say YES when there's clear intent to get help with wording/phrasing.\n\n"
                "Respond with ONLY YES or NO.\n\n"
                f"{conversation_context}{user_message}"
            )

            messages = [{"role": "system", "content": context_aware_prompt}]
            resp = self.client.responses.create(model=self.model, input=messages, temperature=0)
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
        """AI-only classifier to detect if user wants a message to send to their partner.

        Returns True if the user is asking the AI to WRITE/COMPOSE/DRAFT a message
        to SEND to their partner; False otherwise. Output is based on a strict
        YES/NO single-token response from the model.
        """
        try:
            if not user_message:
                return False

            detection_prompt = (
                "You are a precise classifier for partner message requests. Your job is to detect "
                "when someone is explicitly asking for help with WHAT TO SAY to their romantic partner.\n\n"
                
                "Say YES ONLY if the user is:\n"
                "- Directly asking what to say/tell/write to their partner\n"
                "- Requesting help with wording or phrasing for their partner\n"
                "- Asking for a message to send to their partner\n"
                "- Wanting help expressing something specific to their partner\n\n"
                
                "Direct request patterns (YES):\n"
                "- 'How do I tell him/her...'\n"
                "- 'What should I say...'\n"
                "- 'I need to tell them...'\n"
                "- 'Give me a message to tell her...'\n"
                "- 'I was wondering how I could tell...'\n"
                "- 'Help me tell my partner...'\n"
                "- 'I want to tell her...'\n"
                "- 'I should tell him...'\n"
                "- 'I need to tell her this'\n"
                "- 'Give a message to tell her I love her'\n"
                "- 'What can I say to my wife about...'\n"
                "- 'How do I explain this to him...'\n\n"
                
                "Say NO for:\n"
                "- General relationship advice requests\n"
                "- Venting about relationship problems without asking for wording\n"
                "- Asking what to DO (actions, not words)\n"
                "- General emotional support requests\n"
                "- Questions about other people's relationships\n"
                "- Non-relationship topics\n\n"
                
                "Be conservative. Only say YES when there's clear intent to get help with wording/phrasing for their partner.\n\n"
                
                "Examples that should be YES:\n"
                "- 'Hey, I was wondering how I could tell my wife we need a divorce...'\n"
                "- 'I need to tell her this'\n"
                "- 'Give a message to tell her I love her'\n"
                "- 'What should I say to my husband about the money issue?'\n"
                "- 'How do I tell her I'm sorry?'\n"
                "- 'Help me tell my partner how I feel'\n\n"
                
                "Examples that should be NO:\n"
                "- 'I feel like he doesn't listen to me'\n"
                "- 'We've been fighting a lot lately'\n"
                "- 'She seems distant and I don't know why'\n"
                "- 'I'm frustrated with how things are going'\n"
                "- 'I'm worried about our relationship'\n"
                "- 'I'm hurt by what happened yesterday'\n"
                "- 'We keep having the same argument'\n"
                "- 'Should I tell him the truth?'\n"
                "- 'What should I do about this situation?'\n"
                "- 'I'm stressed about work'\n\n"
                
                "Respond with ONLY YES or NO.\n\n"
                f"User: {user_message}"
            )

            messages = [{"role": "system", "content": detection_prompt}]
            resp = self.client.responses.create(model=self.model, input=messages, temperature=0)
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
                                 dialogue_context: list = None, partner_context: list = None,
                                 user_a_id = None) -> str:
        """Craft a concise, caring message the user can send to their partner.

        Uses the dialogue prompt and combines current personal chat, the partner's
        personal chat (if available), and prior dialogue context (A/B labeled).
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

            # Build dialogue context (A/B labeled)
            dialogue_context_text = ""
            if dialogue_context:
                dialogue_context_text = "\nPrevious dialogue between partners:\n"
                a_id_str = str(user_a_id) if user_a_id is not None else None
                for msg in dialogue_context:
                    sender_id = str(msg.get('sender_user_id')) if msg.get('sender_user_id') is not None else None
                    label = "Partner A:" if sender_id and a_id_str and sender_id == a_id_str else "Partner B:"
                    dialogue_context_text += f"{label} {msg.get('content', '')}\n"

            full_context = (
                f"{current_context}{other_context}{dialogue_context_text}\n"
                f"User's request: {user_message}"
            )

            input_messages = [
                {"role": "system", "content": self.dialogue_prompt},
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
