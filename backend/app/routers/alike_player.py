from fastapi import APIRouter, UploadFile, File, Depends
from app.services.pose_engine import extract_keypoints_from_video
from app.services.similarity_service import find_alike_players
from app.middleware.auth import verify_token
from app.database import get_db
from app.models.user import ProPlayer
from sqlalchemy.orm import Session

router = APIRouter(prefix="/alike-player", tags=["Alike Player"])

@router.post("/find")
async def find_similar_player(
    video: UploadFile = File(...),
    user_id: int = Depends(verify_token),
    db: Session = Depends(get_db)
):
    video_bytes = await video.read()
    pose_data = extract_keypoints_from_video(video_bytes)
    user_vector = pose_data["style_vector"]
    pro_players = db.query(ProPlayer).all()
    matches = find_alike_players(user_vector, pro_players)
    return {"status": "success", "top_matches": matches}