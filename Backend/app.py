from fastapi import FastAPI

from .Apple.aasa_router import router as aasa_router
from .Routers.link_router import router as link_router
from .Routers.partner_router import router as partner_router
from .Routers.profile_router import router as profile_router
from .APNS.notifications_router import router as notifications_router
from .Routers.chat_router import router as chat_router

app = FastAPI()

app.include_router(aasa_router)
app.include_router(link_router)
app.include_router(partner_router)
app.include_router(profile_router)
app.include_router(notifications_router)
app.include_router(chat_router)