import uuid
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware

from .Models.requests import ChatRequest, ChatResponse, MessagesResponse, MessageDTO, SessionsResponse, SessionDTO
from .Agents.chat import ChatAgent
from .auth import get_current_user
from .Database.chat_repository import save_message, list_messages_for_session
from .Database.session_repository import create_session, list_sessions_for_user, touch_session, assert_session_owned_by_user
from .Routers.aasa_router import router as aasa_router
from .Routers.link_router import router as link_router

app = FastAPI()

# Add CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this to your app's domain
    allow_credentials = True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(aasa_router)
app.include_router(link_router)

chat_agent = ChatAgent()

@app.post("/chat/sessions/message", response_model = ChatResponse)
async def chat_message(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
        # Persist user message
        try:
            user_uuid = uuid.UUID(current_user.get("sub"))
        except Exception:
            raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

        # Determine session id: if provided, verify ownership; else create one
        if request.session_id is not None:
            try:
                await assert_session_owned_by_user(user_id=user_uuid, session_id=request.session_id)
                session_uuid = request.session_id
            except PermissionError:
                raise HTTPException(status_code=403, detail="Forbidden: invalid session")
        else:
            session_row = await create_session(user_id=user_uuid, title=None)
            session_uuid = uuid.UUID(session_row["id"])

        await save_message(user_id = user_uuid, session_id = session_uuid, role = "user", content = request.message)

        response = chat_agent.generate_response(request.message)

        # Persist assistant message
        await save_message(user_id = user_uuid, session_id = session_uuid, role = "assistant", content = response)
        await touch_session(session_id=session_uuid)

        return ChatResponse(
            response = response,
            success = True,
            session_id = session_uuid
        )
    except Exception as e:
        raise HTTPException(status_code = 500, detail = f"Error processing message: {str(e)}")

@app.get("/chat/sessions/{session_id}/messages", response_model = MessagesResponse)
async def get_messages(session_id: uuid.UUID, current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    try:
        await assert_session_owned_by_user(user_id=user_uuid, session_id=session_id)
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden: invalid session")

    rows = await list_messages_for_session(user_id = user_uuid, session_id = session_id, limit = 200, offset = 0)
    return MessagesResponse(
        messages=[
            MessageDTO(
                id=uuid.UUID(r["id"]),
                user_id=uuid.UUID(r["user_id"]),
                session_id=uuid.UUID(r["session_id"]),
                role=r["role"],
                content=r["content"],
            )
            for r in rows
        ]
    )

@app.get("/chat/sessions", response_model = SessionsResponse)
async def get_sessions(current_user: dict = Depends(get_current_user)):
    try:
        user_uuid = uuid.UUID(current_user.get("sub"))
    except Exception:
        raise HTTPException(status_code = 401, detail = "Invalid user ID in token")

    rows = await list_sessions_for_user(user_id=user_uuid, limit=100, offset=0)
    return SessionsResponse(
        sessions=[
            SessionDTO(
                id=uuid.UUID(r["id"]),
                user_id=uuid.UUID(r["user_id"]),
                title=r.get("title"),
            )
            for r in rows
        ]
    )