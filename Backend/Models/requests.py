from uuid import UUID
from typing import Optional
from pydantic import BaseModel

# Chat models
class ChatHistoryMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    message: str
    session_id: Optional[UUID] = None
    chat_history: Optional[list[ChatHistoryMessage]] = None

class ChatResponse(BaseModel):
    response: str
    success: bool
    session_id: Optional[UUID] = None

class MessageDTO(BaseModel):
    id: UUID
    user_id: UUID
    session_id: UUID
    role: str
    content: str

class MessagesResponse(BaseModel):
    messages: list[MessageDTO]

class SessionDTO(BaseModel):
    id: UUID
    user_id: UUID
    title: Optional[str] = None

class SessionsResponse(BaseModel):
    sessions: list[SessionDTO]

# Link models
class CreateLinkInviteResponse(BaseModel):
    invite_token: str
    share_url: str

class AcceptLinkInviteRequest(BaseModel):
    invite_token: str

class AcceptLinkInviteResponse(BaseModel):
    success: bool
    relationship_id: UUID | None = None

class UnlinkResponse(BaseModel):
    success: bool
    unlinked: bool

# Link status
class LinkStatusResponse(BaseModel):
    success: bool
    linked: bool
    relationship_id: UUID | None = None
