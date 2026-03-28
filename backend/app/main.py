from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import pose, fatigue, coaching, alike_player
from app.database import Base, engine

Base.metadata.create_all(bind=engine)

app = FastAPI(title="ProLevel AI Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Lock this down in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(pose.router)
app.include_router(fatigue.router)
app.include_router(coaching.router)
app.include_router(alike_player.router)

@app.get("/health")
def health_check():
    return {"status": "ProLevel backend is live 🚀"}