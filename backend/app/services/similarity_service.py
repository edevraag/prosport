import numpy as np
from typing import List

def cosine_similarity(vec_a: List[float], vec_b: List[float]) -> float:
    a, b = np.array(vec_a), np.array(vec_b)
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-6))

def find_alike_players(user_vector: List[float], pro_players: list) -> list:
    results = []
    for player in pro_players:
        pv = player.style_vector
        if pv and len(pv) == len(user_vector):
            score = cosine_similarity(user_vector, pv)
            results.append({
                "player_id": player.id,
                "name": player.name,
                "sport": player.sport,
                "similarity_score": round(score * 100, 2)
            })
    results.sort(key=lambda x: x["similarity_score"], reverse=True)
    return results[:5]  # Top 5 matches