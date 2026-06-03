from fastapi import FastAPI, UploadFile, File, Form, Query
from typing import Optional
import uvicorn, os

from recommend import TourismRecommender
from database_helper import upload_image, insert_place, insert_place_tags, connect_db

app = FastAPI()

db_params = {
    "dbname": os.getenv("DB_NAME", "Test2"),
    "user":   os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "1234"),
    "host":   os.getenv("DB_HOST", "localhost")
}

recommender = TourismRecommender(db_params)
recommender.load_data()


# ── 1. ADD PLACE FROM FLUTTER (business add-place screen with image) ──────────
@app.post("/add-place")
async def add_new_place(
    name: str = Form(...), category: str = Form(...),
    description: str = Form(...), latitude: float = Form(...),
    longitude: float = Form(...), duration_minutes: int = Form(...),
    cost_level: str = Form(...), rating: float = Form(0.0),
    tag_ids: str = Form(...), image: UploadFile = File(...)
):
    conn = connect_db()
    try:
        file_location = f"temp_{image.filename}"
        with open(file_location, "wb+") as f:
            f.write(image.file.read())
        img_url = upload_image(file_location)
        place_id = insert_place(conn,
            name=name, category=category, description=description,
            latitude=latitude, longitude=longitude,
            duration_minutes=duration_minutes, cost_level=cost_level,
            rating=rating, image_url=img_url, cluster_id=1)
        tags = [int(t.strip()) for t in tag_ids.split(",") if t.strip()]
        insert_place_tags(conn, place_id, tags)
        conn.commit()
        recommender.load_data()
        return {"status": "success", "place_id": place_id, "url": img_url}
    except Exception as e:
        conn.rollback()
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()


# ── 2. SYNC FIREBASE-APPROVED PLACE INTO POSTGRESQL ──────────────────────────
# Flutter calls this when admin approves a business listing in Firebase.
# Inserts the place into PostgreSQL so the AI recommender includes it.
@app.post("/sync-approved-place")
async def sync_approved_place(
    name:             str   = Form(...),
    category:         str   = Form(...),
    description:      str   = Form(""),
    latitude:         float = Form(0.0),
    longitude:        float = Form(0.0),
    duration_minutes: int   = Form(60),
    cost_level:       str   = Form("medium"),
    rating:           float = Form(0.0),
    image_url:        str   = Form(""),
    tags:             str   = Form(""),
    firebase_doc_id:  str   = Form(""),
):
    conn = connect_db()
    try:
        # Skip if already synced
        with conn.cursor() as cur:
            cur.execute(
                "SELECT place_id FROM places WHERE name=%s AND latitude=%s AND longitude=%s",
                (name, latitude, longitude)
            )
            existing = cur.fetchone()
            if existing:
                recommender.load_data()
                return {"status": "already_exists", "place_id": existing[0]}

        place_id = insert_place(conn,
            name=name, category=category, description=description,
            latitude=latitude, longitude=longitude,
            duration_minutes=duration_minutes, cost_level=cost_level,
            rating=rating, image_url=image_url, cluster_id=1)

        # Map tag names -> tag IDs
        if tags.strip():
            tag_names = [t.strip().lower() for t in tags.split(",") if t.strip()]
            with conn.cursor() as cur:
                tag_ids = []
                for tag_name in tag_names:
                    cur.execute(
                        "SELECT tag_id FROM tags WHERE LOWER(tag_name)=%s", (tag_name,)
                    )
                    row = cur.fetchone()
                    if row:
                        tag_ids.append(row[0])
            if tag_ids:
                insert_place_tags(conn, place_id, tag_ids)

        conn.commit()
        recommender.load_data()   # hot-reload so AI sees the new place immediately
        return {"status": "success", "place_id": place_id}
    except Exception as e:
        conn.rollback()
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()


# ── 3. GET AI ITINERARY ───────────────────────────────────────────────────────
@app.get("/get-itinerary")
def get_itinerary(
    category: str, budget: str, days: int = 1,
    tags: Optional[str] = "",
    favorites: Optional[str] = Query("", description="Comma-separated favorite place names")
):
    prefs = {"category": category, "budget": budget, "tags": tags, "favorites": favorites}
    top_candidates = recommender.recommend_hybrid(prefs, top_n=15)
    plan, totals = recommender.generate_itinerary_geospatial(top_candidates, days=days)
    return {"itinerary": plan, "totals": totals}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
