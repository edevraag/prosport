from sqlalchemy import Column, Integer, String, Float, JSON, DateTime
from app.database import Base
import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)

class FatigueSession(Base):
    __tablename__ = "fatigue_sessions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer)
    session_load_score = Column(Float)
    rep_count = Column(Integer)
    avg_velocity = Column(Float)
    keypoints_snapshot = Column(JSON)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class ProPlayer(Base):
    __tablename__ = "pro_players"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    sport = Column(String)
    style_vector = Column(JSON)  # list of floats — cosine similarity target