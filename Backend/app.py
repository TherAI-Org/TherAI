import uuid
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware

from .Models.requests import ChatRequest, ChatResponse, MessagesResponse, MessageDTO
from .Agents.chat import ChatAgent
from .auth import get_current_user
from .Database.chat_repository import save_message, list_messages_for_user

app = FastAPI()

# Add CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this to your app's domain
    allow_credentials = True,
    allow_methods=["*"],
    allow_headers=["*"],
)

chat_agent = ChatAgent()

@app.post("/chat/message", response_model = ChatResponse)
async def chat_message(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
        # Persist user message
        try:
            user_uuid = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

        await save_message(user_id = user_uuid, role = "user", content = request.message)

        response = chat_agent.generate_response(request.message)

        # Persist assistant message
        await save_message(user_id = user_uuid, role = "assistant", content = response)

        return ChatResponse(
            response = response,
            success = True
        )
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error processing message: {str(e)}")


@app.get("/chat/messages", response_model = MessagesResponse)
async def get_messages(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    rows = await list_messages_for_user(user_id = user_uuid, limit = 200, offset = 0)
    return MessagesResponse(
        messages=[
            MessageDTO(
                id=uuid.UUID(r["id"]),
                user_id=uuid.UUID(r["user_id"]),
                role=r["role"],
                content=r["content"],
            )
            for r in rows
        ]
    )