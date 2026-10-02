from __future__ import annotations

import json
import math
import os


def _configured_branches() -> list[dict]:
    """Loads verified branch coordinates supplied by deployment configuration.

    No coordinates are guessed: supermarket branch IDs are commercial data and
    must be maintained by the operator that knows the store coverage.
    """
    try:
        raw = json.loads(os.getenv("CONVIENE_COTO_BRANCHES_JSON", "[]"))
    except json.JSONDecodeError:
        return []
    if not isinstance(raw, list):
        return []
    branches = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        try:
            branch = {
                "id": str(item["id"]),
                "name": str(item["name"]),
                "latitude": float(item["latitude"]),
                "longitude": float(item["longitude"]),
            }
        except (KeyError, TypeError, ValueError):
            continue
        branches.append(branch)
    return branches


def _distance_km(latitude: float, longitude: float, branch: dict) -> float:
    radius_km = 6371.0088
    lat_1, lon_1, lat_2, lon_2 = map(
        math.radians,
        [latitude, longitude, branch["latitude"], branch["longitude"]],
    )
    a = math.sin((lat_2 - lat_1) / 2) ** 2 + math.cos(lat_1) * math.cos(lat_2) * math.sin((lon_2 - lon_1) / 2) ** 2
    return radius_km * 2 * math.asin(math.sqrt(a))


def nearby_coto_branches(latitude: float, longitude: float, limit: int = 3) -> list[dict]:
    suggestions = [
        {
            "id": branch["id"],
            "name": branch["name"],
            "distance_km": round(_distance_km(latitude, longitude, branch), 1),
        }
        for branch in _configured_branches()
    ]
    return sorted(suggestions, key=lambda item: item["distance_km"])[:limit]
