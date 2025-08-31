import os
import openai
from dotenv import load_dotenv
from pathlib import Path
from typing import Dict, Any

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

class ChatAgent:
    def __init__(self):
        # Initialize OpenAI client
        openai.api_key = os.getenv("OPENAI_API_KEY")
        self.client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    def generate_response(self, user_message: str) -> str:
        """Generate AI response using OpenAI API"""
        try:
            # Create the prompt for OpenAI
            system_prompt = """You are a helpful AI assistant. Answer questions accurately and helpfully based on your general knowledge.
            Always be concise, accurate, and helpful."""

            # Make OpenAI API call
            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ],
                max_tokens=500,
                temperature=0.7
            )

            return response.choices[0].message.content.strip()

        except Exception as e:
            print(f"OpenAI API error: {e}")
            return f"I apologize, but I encountered an error while processing your request: {str(e)}"

    def get_health_status(self) -> Dict[str, Any]:
        """Check if the chat agent is properly configured"""
        try:
            # Test OpenAI API key
            test_response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": "Hello"}],
                max_tokens=10
            )

            return {
                "status": "healthy",
                "openai_api": "working"
            }
        except Exception as e:
            return {
                "status": "unhealthy",
                "error": str(e),
                "openai_api": "error"
            }
