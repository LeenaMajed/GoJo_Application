import os
import math
import traceback
from typing import Optional

import numpy as np
from fastapi import FastAPI, UploadFile, File, Form
import uvicorn

from recommend import TourismRecommender
from database_helper import upload_image, insert_place, insert_place_tags, connect_db

os.environ["no_proxy"] = "*"

app = FastAPI()

db_params = {
    "dbname": os.getenv("DB_NAME", "Test2"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "1234"),
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
}

recommender = TourismRecommender(db_params)
recommender.load_data()


def clean_for_json(obj):
    if isinstance(obj, dict):
        return {k: clean_for_json(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [clean_for_json(i) for i in obj]
    if isinstance(obj, float) and math.isnan(obj):
        return None
    if isinstance(obj, np.integer):
        return int(obj)
    if isinstance(obj, np.floating):
        return float(obj)
    return obj


@app.post("/add-place")
async def add_new_place(
    name: str = Form(...),
    category: str = Form(...),
    description: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    duration_minutes: int = Form(...),
    cost_level: str = Form(...),
    rating: float = Form(...),
    tag_ids: str = Form(...),
    image: UploadFile = File(...),
):
    conn = connect_db()
    file_location = f"temp_{image.filename}"
    try:
        with open(file_location, "wb+") as f:
            f.write(image.file.read())

        img_url = upload_image(file_location)

        place_data = {
            "name": name,
            "category": category,
            "description": description,
            "latitude": latitude,
            "longitude": longitude,
            "duration_minutes": duration_minutes,
            "cost_level": cost_level,
            "rating": rating,
            "image_url": img_url,
            "cluster_id": 1,
        }

        place_id = insert_place(conn, **place_data)

        tags = [int(tid.strip()) for tid in tag_ids.split(",") if tid.strip()]
        insert_place_tags(conn, place_id, tags)

        conn.commit()
        recommender.load_data()

        return {"status": "success", "place_id": place_id, "url": img_url}

    except Exception as e:
        conn.rollback()
        traceback.print_exc()
        return {"status": "error", "message": str(e)}

    finally:
        conn.close()
        if os.path.exists(file_location):
            os.remove(file_location)


@app.get("/get-itinerary")
def get_itinerary(
    category: str,
    budget: str,
    days: int = 1,
    tags: Optional[str] = "",
    favorites: Optional[str] = "",
):
    try:
        favorite_names = (
            [item.strip() for item in favorites.split(",") if item.strip()]
            if favorites else []
        )
        prefs = {
            "category": category,
            "budget": budget,
            "tags": tags,
            "favorites": favorite_names,
        }

        top_candidates = recommender.recommend_hybrid(prefs, top_n=15)
        plan, totals = recommender.generate_itinerary_geospatial(top_candidates, days=days)

        return clean_for_json({
            "itinerary": plan,
            "totals": totals,
        })

    except Exception as e:
        traceback.print_exc()
        return {"itinerary": {}, "totals": {}, "error": str(e)}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)