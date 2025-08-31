from uuid import UUID
from pydantic import BaseModel

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    response: str
    success: bool

class MessageDTO(BaseModel):
    id: UUID
    user_id: UUID
    role: str
    content: str

class MessagesResponse(BaseModel):
    messages: list[MessageDTO]
