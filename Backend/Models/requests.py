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
    focus_snippet: Optional[str] = None

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
    last_message_at: Optional[str] = None
    last_message_content: Optional[str] = None

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
    linked_at: str | None = None

# Dialogue models
class DialogueRequestBody(BaseModel):
    message: str
    session_id: UUID

class DialogueRequestResponse(BaseModel):
    success: bool
    request_id: UUID
    dialogue_session_id: UUID

class DialogueMessageDTO(BaseModel):
    id: UUID
    dialogue_session_id: UUID
    request_id: Optional[UUID] = None
    content: str
    message_type: str  # "request" or "ai_mediation"
    sender_user_id: UUID
    created_at: str

class DialogueMessagesResponse(BaseModel):
    messages: list[DialogueMessageDTO]
    dialogue_session_id: UUID

class PendingRequestDTO(BaseModel):
    id: UUID
    sender_user_id: UUID
    sender_session_id: UUID
    request_content: str
    created_at: str
    status: str

class PendingRequestsResponse(BaseModel):
    requests: list[PendingRequestDTO]

class ExtractContextRequest(BaseModel):
    relationship_id: UUID
    target_session_id: UUID  # Personal session to extract context into

# Dialogue acceptance response
class AcceptDialogueResponse(BaseModel):
    success: bool
    partner_session_id: UUID
    dialogue_session_id: UUID

# Dialogue insight
class DialogueInsightRequest(BaseModel):
    source_session_id: UUID
    dialogue_message_id: Optional[UUID] = None
    dialogue_message_content: Optional[str] = None

class DialogueInsightResponse(BaseModel):
    insight: str
