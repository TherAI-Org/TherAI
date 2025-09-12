import uuid
from fastapi import FastAPI, HTTPException, Depends

from .Models.requests import ChatRequest, ChatResponse, MessagesResponse, MessageDTO, SessionsResponse, SessionDTO
from .Agents.personal import PersonalAgent
from .auth import get_current_user
from .Database.chat_repository import save_message, list_messages_for_session, get_partner_chat_history
from .Database.dialogue_repository import get_dialogue_history_for_context
from .Database.session_repository import create_session, list_sessions_for_user, touch_session, assert_session_owned_by_user
from .Database.linked_sessions_repository import get_linked_session_by_user, get_partner_personal_session
from .Routers.aasa_router import router as aasa_router
from .Routers.link_router import router as link_router
from .Routers.dialogue_router import router as dialogue_router

app = FastAPI()

app.include_router(aasa_router)
app.include_router(link_router)
app.include_router(dialogue_router)

personal_agent = PersonalAgent()

# Send a message and receive an assistant response, creating a session if needed
@app.post("/chat/sessions/message", response_model = ChatResponse)
async def chat_message(request: ChatRequest, current_user: dict = Depends(get_current_user)):
    try:
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

        # Convert chat history to the format expected by the chat agent
        chat_history_for_agent = None
        if request.chat_history:
            chat_history_for_agent = [
                {"role": msg.role, "content": msg.content}
                for msg in request.chat_history
            ]

        # AUTO-ENHANCED CONTEXT: Get linked session context automatically
        dialogue_context = None
        partner_context = None

        try:
            # Check if user has a linked session (bonded relationship)
            linked_session = await get_linked_session_by_user(user_id=user_uuid)

            if linked_session:
                # User is in a bonded relationship - get enhanced context
                from .Database.link_repository import get_link_status_for_user
                linked, relationship_id = await get_link_status_for_user(user_id=user_uuid)

                if linked and relationship_id:
                    # Get dialogue history for relationship context
                    dialogue_context = await get_dialogue_history_for_context(user_id=user_uuid)

                    # Get partner's personal chat history from their bonded session
                    partner_personal_session_id = await get_partner_personal_session(
                        user_id=user_uuid,
                        relationship_id=relationship_id
                    )

                    if partner_personal_session_id:
                        # Get partner's messages from their bonded personal session
                        # We need to get partner's user_id first
                        from .Database.link_repository import get_partner_user_id
                        partner_user_id = await get_partner_user_id(user_id=user_uuid)

                        if partner_user_id:
                            partner_messages = await list_messages_for_session(
                                user_id=partner_user_id,
                                session_id=partner_personal_session_id,
                                limit=50
                            )
                            partner_context = partner_messages
        except Exception as e:
            # If context retrieval fails, continue without it (user may not be linked)
            print(f"Context retrieval warning: {e}")

        response = personal_agent.generate_response(
            request.message,
            chat_history_for_agent,
            dialogue_context = dialogue_context,
            partner_context = partner_context
        )

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

# Get messages for a specific session owned by the current user
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

# List chat sessions for the current user
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