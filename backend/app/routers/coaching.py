from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from app.services.pose_engine import extract_keypoints_from_video
from app.services.fatigue_service import calculate_fatigue_score
from app.services.gemini_service import get_coaching_report
# from app.middleware.auth import verify_token  # DISABLED

router = APIRouter(prefix="/coaching", tags=["Gemini Coaching"])

@router.post("/report")
async def get_report(
    video: UploadFile = File(...),
    sport: str = Form(...),
    rep_count: int = Form(10)
    # user_id: int = Depends(verify_token)  # DISABLED
):
    video_bytes = await video.read()
    pose_data = extract_keypoints_from_video(video_bytes)
    fatigue_data = calculate_fatigue_score(
        [pose_data["keypoints_sample"]] * max(pose_data["detected_frames"], 2),
        rep_count
    )
    report = get_coaching_report(pose_data, sport, fatigue_data)
    return {"status": "success", "report": report}