from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from app.services.fatigue_service import calculate_fatigue_score
from app.services.pose_engine import extract_keypoints_from_video
# from app.middleware.auth import verify_token
from app.database import get_db
from app.models.user import FatigueSession
from sqlalchemy.orm import Session

router = APIRouter(prefix="/fatigue", tags=["Fatigue API"])

@router.post("/calculate")
async def calculate_fatigue(
    video: UploadFile = File(...),
    rep_count: int = 10,
    # user_id: int = Depends(verify_token),
    db: Session = Depends(get_db)
):
    video_bytes = await video.read()
    pose_data = extract_keypoints_from_video(video_bytes)

    fatigue = calculate_fatigue_score(
        [pose_data["keypoints_sample"]] * pose_data["detected_frames"],
        rep_count
    )

    session = FatigueSession(
        user_id=1,  # hardcoded for testing
        session_load_score=fatigue["session_load_score"],
        rep_count=rep_count,
        avg_velocity=fatigue["avg_velocity"],
        keypoints_snapshot=pose_data["keypoints_sample"]
    )
    db.add(session)
    db.commit()

    return {"status": "success", "fatigue_data": fatigue}