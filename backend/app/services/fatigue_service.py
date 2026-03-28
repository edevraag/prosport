import numpy as np
from typing import List, Dict

def calculate_fatigue_score(keypoints_per_frame: List[List[Dict]], rep_count: int) -> Dict:
    if len(keypoints_per_frame) < 2:
        return {"session_load_score": 0.0, "avg_velocity": 0.0, "fatigue_level": "unknown"}

    # Use right wrist (landmark 16) velocity as proxy for movement speed
    WRIST_IDX = 16
    velocities = []

    for i in range(1, len(keypoints_per_frame)):
        prev = keypoints_per_frame[i - 1][WRIST_IDX]
        curr = keypoints_per_frame[i][WRIST_IDX]
        dx = curr["x"] - prev["x"]
        dy = curr["y"] - prev["y"]
        vel = np.sqrt(dx**2 + dy**2)
        velocities.append(vel)

    avg_velocity = float(np.mean(velocities))
    velocity_decay = float(np.mean(velocities[-10:]) / (np.mean(velocities[:10]) + 1e-6))

    # Session load = reps × avg velocity (simple proxy, tune later)
    session_load_score = round(rep_count * avg_velocity * 1000, 2)

    if velocity_decay < 0.6:
        fatigue_level = "high"
    elif velocity_decay < 0.85:
        fatigue_level = "moderate"
    else:
        fatigue_level = "low"

    return {
        "session_load_score": session_load_score,
        "avg_velocity": round(avg_velocity, 6),
        "velocity_decay_ratio": round(velocity_decay, 4),
        "fatigue_level": fatigue_level,
        "rep_count": rep_count
    }