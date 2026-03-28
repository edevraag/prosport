# app/services/gemini_service.py — Updated for google.genai (no more warnings)
from google import genai
from app.config import settings

# New SDK — replaces deprecated google.generativeai
client = genai.Client(api_key=settings.GEMINI_API_KEY)
MODEL_NAME = "gemini-1.5-flash"

def get_coaching_report(pose_data: dict, sport: str, fatigue_data: dict) -> dict:
    prompt = f"""
You are an elite sports biomechanics coach. Analyze the following athlete data and return a structured coaching report.

Sport: {sport}
Pose Score (0-100, higher = better form visibility): {pose_data.get('pose_score')}
Detected Frames: {pose_data['detected_frames']} / {pose_data['frame_count']} total frames
Fatigue Level: {fatigue_data.get('fatigue_level')}
Session Load Score: {fatigue_data.get('session_load_score')}
Velocity Decay Ratio: {fatigue_data.get('velocity_decay_ratio')} (1.0 = no decay, <0.6 = high fatigue)
Rep Count: {fatigue_data.get('rep_count')}

Provide your response in this exact JSON structure:
{{
  "overall_rating": "<Excellent/Good/Needs Work>",
  "technique_feedback": "<2-3 sentences on movement quality>",
  "fatigue_analysis": "<2 sentences on fatigue state>",
  "top_3_recommendations": ["rec1", "rec2", "rec3"],
  "injury_risk": "<Low/Moderate/High>",
  "recovery_time_estimate": "<e.g. 15-20 minutes>"
}}

Only return the JSON, no extra text.
"""

    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=[{"role": "user", "parts": [{"text": prompt}]}]
        )
        text = response.text.strip()
        
        # Clean JSON from markdown if present
        if "```json" in text:
            text = text.split("```json").split("```").strip()[1]
        
        import json
        return json.loads(text)
        
    except Exception as e:
        return {
            "error": f"Gemini API failed: {str(e)}",
            "raw_response": getattr(response, 'text', 'No response'),
            "status": "failed"
        }