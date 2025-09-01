from uuid import UUID
from typing import Optional
from pydantic import BaseModel

class ChatRequest(BaseModel):
    message: str
    session_id: Optional[UUID] = None

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
