import os
import psycopg2
import cloudinary
import cloudinary.uploader

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME", "dray98g11"),
    api_key=os.getenv("CLOUDINARY_API_KEY", "334641784128282"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET", "DhOFb4P-iZRh8SPEuK_ln30zlnc")
)

def connect_db():
    try:
        conn = psycopg2.connect(
            dbname=os.getenv("DB_NAME", "Test2"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", "1234"),
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432")
        )
        return conn
    except Exception as e:
        raise ConnectionError(f"Database connection failed: {e}")

def upload_image(file_path):
    try:
        result = cloudinary.uploader.upload(file_path)
        return result["secure_url"]
    except Exception as e:
        raise RuntimeError(f"Image upload failed: {e}")

def insert_place(conn, name, description, latitude, longitude,
                 duration_minutes, cost_level,
                 rating, cluster_id, image_url,
                 category=None, city=None,
                 suitable_for=None, best_time=None):
    try:
        with conn.cursor() as cur:
            query = """
                INSERT INTO places
                (name, description, latitude, longitude, duration_minutes,
                 cost_level, rating, cluster_id, image_url,
                 category, city, suitable_for, best_time)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING place_id;
            """
            cur.execute(query, (
                name, description, latitude, longitude,
                duration_minutes, cost_level, rating,
                cluster_id, image_url,
                category, city, suitable_for, best_time
            ))
            place_id = cur.fetchone()[0]
        return place_id
    except Exception as e:
        conn.rollback()
        raise RuntimeError(f"Error inserting place: {e}")

def insert_place_tags(conn, place_id, tag_ids):
    try:
        with conn.cursor() as cur:
            query = """
                INSERT INTO place_tags (place_id, tag_id)
                VALUES (%s, %s)
                ON CONFLICT (place_id, tag_id) DO NOTHING;
            """
            for tag_id in tag_ids:
                cur.execute(query, (place_id, tag_id))
    except Exception as e:
        conn.rollback()
        raise RuntimeError(f"Error inserting place_tags: {e}")

def add_place_with_tags(conn, place_data, tag_ids, image_path):
    try:
        image_url = upload_image(image_path)
        place_data["image_url"] = image_url
        place_id = insert_place(conn, **place_data)
        insert_place_tags(conn, place_id, tag_ids)
        conn.commit()
        return place_id
    except Exception as e:
        conn.rollback()
        raise RuntimeError(f"Transaction failed: {e}")

if __name__ == "__main__":
    conn = connect_db()
    place_data = {
        "name": "Sunny Beach",
        "category": "beach",
        "city": "Varna",
        "description": "A beautiful seaside destination with clear water.",
        "latitude": 42.695,
        "longitude": 27.710,
        "duration_minutes": 180,
        "cost_level": "low",
        "suitable_for": "Families, Couples",
        "best_time": "June to September",
        "rating": 4.6,
        "cluster_id": 1
    }
    tag_ids = [1, 3, 5]
    image_path = "C:\\Users\\Asus\\Desktop\\beach.jpg"
    try:
        new_place_id = add_place_with_tags(conn, place_data, tag_ids, image_path)
        print(f"✅ New place inserted with place_id = {new_place_id}")
    except Exception as e:
        print(f"❌ {e}")
    finally:
        conn.close()