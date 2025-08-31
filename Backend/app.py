from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware

from Models.requests import ChatRequest, ChatResponse
from Agents.chat import ChatAgent
from auth import get_current_user

app = FastAPI(title="TherAI Backend", version="0.1.0")

# Add CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this to your app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

chat_agent = ChatAgent()

@app.post("/chat/message", response_model = ChatResponse)
async def chat_message(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
        if not request.message.strip():
            raise HTTPException(status_code = 400, detail = "Message cannot be empty")

        response = chat_agent.generate_response(request.message)

        return ChatResponse(
            response = response,
            success = True
        )

    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error processing message: {str(e)}")


