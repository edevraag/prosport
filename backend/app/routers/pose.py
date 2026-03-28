from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from app.services.pose_engine import extract_keypoints_from_video
# from app.middleware.auth import verify_token   ← COMMENT THIS IMPORT TOO

router = APIRouter(prefix="/pose", tags=["Pose Engine"])

@router.post("/analyze")
async def analyze_pose(
    video: UploadFile = File(...),
    # user_id: int = Depends(verify_token)     ← COMMENT THIS LINE
):
    if not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Upload a valid video file")
    video_bytes = await video.read()
    try:
        result = extract_keypoints_from_video(video_bytes)
        return {"status": "success", "data": result}
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))