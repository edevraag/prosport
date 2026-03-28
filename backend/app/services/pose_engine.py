# app/services/pose_engine.py — COMPLETE FIX for 0.10.33+ (mp.solutions.pose REMOVED)
import cv2, tempfile, os, urllib.request, numpy as np
from pathlib import Path
from typing import List, Dict
import mediapipe as mp

# ── Tasks API ONLY (solutions.pose deleted in 0.10.31+) ───────────────────────
BaseOptions           = mp.tasks.BaseOptions
PoseLandmarker        = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
RunningMode           = mp.tasks.vision.RunningMode
VisionRunningMode     = mp.tasks.vision.RunningMode

MODEL_PATH = Path("pose_landmarker_full.task")
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "pose_landmarker/pose_landmarker_full/float16/"
    "latest/pose_landmarker_full.task"
)

def _download_model():
    if not MODEL_PATH.exists():
        print(f"[pose] Downloading {MODEL_PATH.name} (~29MB)...")
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
        print("[pose] Model ready!")

def _get_landmarker():
    _download_model()
    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(MODEL_PATH)),
        running_mode=RunningMode.IMAGE,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    return PoseLandmarker.create_from_options(options)

# ── EXACT SAME API your routers expect ────────────────────────────────────────
def extract_keypoints_from_video(video_bytes: bytes) -> Dict:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
        tmp.write(video_bytes)
        tmp_path = tmp.name

    cap = cv2.VideoCapture(tmp_path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    all_keypoints = []
    frame_count = 0

    landmarker = _get_landmarker()
    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret: break
            frame_count += 1

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
            result = landmarker.detect(mp_image)

            if result.pose_landmarks:
                keypoints = [{
                    "x": round(lm.x, 4), "y": round(lm.y, 4),
                    "z": round(lm.z, 4), "visibility": round(lm.visibility, 4)
                } for lm in result.pose_landmarks[0]]
                all_keypoints.append(keypoints)
    finally:
        landmarker.close()
        cap.release()
        os.unlink(tmp_path)

    if not all_keypoints:
        raise ValueError("No pose detected. Try better lighting/video angle.")

    return {
        "frame_count": frame_count,
        "fps": float(fps),
        "detected_frames": len(all_keypoints),
        "keypoints_sample": all_keypoints[0],
        "style_vector": compute_style_vector(all_keypoints),
        "pose_score": compute_pose_score(all_keypoints),
    }

# ── Your original helpers (unchanged) ─────────────────────────────────────────
def compute_pose_score(frames: List) -> float:
    scores = [np.mean([lm["visibility"] for lm in frame]) for frame in frames]
    return round(float(np.mean(scores)) * 100, 2)

def compute_style_vector(frames: List) -> List[float]:
    arr = np.array([[[lm["x"], lm["y"], lm["z"]] for lm in frame] for frame in frames])
    return arr.mean(axis=0).flatten().tolist()

def compute_joint_angle(a, b, c) -> float:
    a, b, c = np.array(a), np.array(b), np.array(c)
    ba = a - b; bc = c - b
    cosine = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-6)
    return float(np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0))))