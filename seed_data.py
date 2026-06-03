"""
╔══════════════════════════════════════════════════════════════════════════════╗
║              GOJO APP — FULL DATA SEEDER                                    ║
║                                                                              ║
║  Seeds ALL places, services, and tags into:                                  ║
║    1. PostgreSQL  (so the AI recommender can use them)                       ║
║    2. Firebase Firestore  (so the Flutter app can display them)              ║
║                                                                              ║
║  HOW TO RUN:                                                                 ║
║    1. Place your Firebase service account JSON in the same folder as        ║
║       this script and name it  firebase_key.json                            ║
║       (Firebase Console → Project Settings → Service accounts →             ║
║        Generate new private key)                                            ║
║    2. Make sure PostgreSQL is running and the .venv is active               ║
║    3. Run:  python seed_data.py                                              ║
║                                                                              ║
║  SAFE TO RE-RUN — skips anything already in the database                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import os
import sys
import psycopg2
from datetime import datetime

# ── Try Firebase Admin ────────────────────────────────────────────────────────
try:
    import firebase_admin
    from firebase_admin import credentials, firestore as fb_firestore
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print("⚠️  firebase-admin not installed. Only seeding PostgreSQL.")
    print("   To also seed Firebase run:  pip install firebase-admin --break-system-packages")

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG — edit these to match your setup
# ══════════════════════════════════════════════════════════════════════════════

DB_CONFIG = {
    "dbname":   os.getenv("DB_NAME",     "Test2"),
    "user":     os.getenv("DB_USER",     "postgres"),
    "password": os.getenv("DB_PASSWORD", "1234"),
    "host":     os.getenv("DB_HOST",     "localhost"),
    "port":     os.getenv("DB_PORT",     "5432"),
}

FIREBASE_KEY_PATH = "firebase_key.json"   # put your service account JSON here

# ══════════════════════════════════════════════════════════════════════════════
# DATA — 40 places + 20 services covering all of Jordan
# ══════════════════════════════════════════════════════════════════════════════

TAGS = [
    (1,  "Adventure"),    (2,  "Relaxing"),       (3,  "Cultural"),
    (4,  "Historical"),   (5,  "Nature"),          (6,  "Food"),
    (7,  "Shopping"),     (8,  "Hiking"),          (9,  "Swimming"),
    (10, "Sightseeing"),  (11, "Photography"),     (12, "Nightlife"),
    (13, "Romantic"),     (14, "Family Friendly"), (15, "Local Experience"),
    (16, "Religious"),    (17, "Traditional"),     (18, "Luxury"),
    (19, "Budget Friendly"), (20, "Desert"),       (21, "Marine"),
    (22, "Wellness"),     (23, "Camping"),         (24, "Wildlife"),
]

# Each place: (name, category, description, lat, lng, duration_min, cost_level, rating, image_url, location, hours, tags, emoji, price_per_night, cuisine, phone)

PLACES = [
    # ATTRACTIONS
    ("Petra Treasury","attraction","The iconic rose-red treasury carved into sandstone cliffs, one of the New Seven Wonders of the World. A UNESCO World Heritage Site.",
     30.3285,35.4444,360,"medium",4.9,
     "https://picsum.photos/seed/petra_treasury/800/500",
     "Petra, Ma'an","6 AM - 6 PM",[4,10,11,3],"🏛️",None,None,"+962 3 215 6020"),

    ("Wadi Rum Desert","attraction","Vast red sand desert with dramatic sandstone mountains. UNESCO World Heritage Site used as a film set for The Martian.",
     29.5765,35.4209,480,"low",4.8,
     "https://picsum.photos/seed/wadi_rum_desert/800/500",
     "Aqaba Governorate","All day",[1,5,8,20,23,11],"🏜️",None,None,None),

    ("Dead Sea","attraction","The lowest point on Earth at 430m below sea level. Float effortlessly in ultra-salty waters and cover yourself in mineral-rich mud.",
     31.5590,35.4732,240,"medium",4.7,
     "https://picsum.photos/seed/dead_sea/800/500",
     "Dead Sea Road","All day",[9,22,2,13],"🌊",None,None,None),

    ("Jerash Roman City","attraction","One of the best-preserved Roman cities outside Italy. 2,000-year-old colonnaded streets, temples, theatres, and plazas.",
     32.2750,35.8960,180,"low",4.7,
     "https://picsum.photos/seed/jerash_roman_city/800/500",
     "Jerash","7:30 AM - 6:30 PM",[4,10,3,11],"🏟️",None,None,"+962 2 635 1272"),

    ("Amman Citadel","attraction","Ancient hilltop landmark featuring Roman, Byzantine, and Umayyad ruins with panoramic city views over Amman.",
     31.9552,35.9356,120,"low",4.6,
     "https://picsum.photos/seed/amman_citadel/800/500",
     "Amman","8 AM - 7 PM",[4,10,3,11,26],"🏯",None,None,"+962 6 463 8795"),

    ("Aqaba Coral Reefs","attraction","Stunning coral ecosystems in the Red Sea home to hundreds of fish species. World-class snorkeling and diving.",
     29.5107,34.9907,300,"medium",4.8,
     "https://picsum.photos/seed/aqaba_coral_reefs/800/500",
     "Aqaba","All day",[9,21,1,11,27],"🐠",None,None,None),

    ("Madaba Mosaic Map","attraction","A 6th-century Byzantine mosaic map of the Holy Land inside St. George's Church.",
     31.7163,35.7931,90,"low",4.5,
     "https://picsum.photos/seed/madaba_mosaic/800/500",
     "Madaba","8 AM - 5 PM",[4,16,3,10],"🗺️",None,None,"+962 5 324 2770"),

    ("Dana Biosphere Reserve","attraction","Jordan's largest nature reserve with stunning biodiversity and dramatic landscapes.",
     30.6960,35.6050,360,"low",4.7,
     "https://picsum.photos/seed/dana_reserve/800/500",
     "Dana, Tafilah","All day",[5,8,24,1,11],"🌿",None,None,"+962 3 227 0497"),

    ("Ajloun Castle","attraction","12th-century Islamic castle with panoramic views over the Jordan Valley.",
     32.3321,35.7508,120,"low",4.5,
     "https://picsum.photos/seed/ajloun_castle/800/500",
     "Ajloun","8 AM - 5 PM",[4,10,16,3,26],"🏰",None,None,"+962 2 642 1290"),

    ("Wadi Mujib","attraction","Dramatic canyon adventure through rushing water in a natural gorge.",
     31.4675,35.5660,300,"low",4.7,
     "https://picsum.photos/seed/wadi_mujib/800/500",
     "Madaba Governorate","Apr-Oct 8 AM - 3 PM",[1,8,5,9,28],"🏞️",None,None,"+962 6 464 4523"),

    # HOTELS
    ("Movenpick Resort Petra","hotel","Luxury resort at the entrance of Petra with canyon views and spa.",
     30.3300,35.4480,0,"high",4.8,
     "https://picsum.photos/seed/movenpick_petra_hotel/800/500",
     "Petra","24 hrs",[18,2,13],"🏨",250.0,None,"+962 3 215 7111"),

    ("Kempinski Dead Sea","hotel","Luxury Dead Sea resort with infinity pools and spa.",
     31.5525,35.5814,0,"high",4.9,
     "https://picsum.photos/seed/kempinski_dead_sea/800/500",
     "Dead Sea","24 hrs",[18,9,2,22],"🏨",350.0,None,"+962 5 356 8888"),

    # RESTAURANTS
    ("Hashem Restaurant","restaurant","Famous traditional falafel and hummus restaurant in Amman.",
     31.9538,35.9313,45,"low",4.8,
     "https://picsum.photos/seed/hashem_restaurant/800/500",
     "Amman","8 AM - 3 AM",[6,19,15,17],"🧆",None,"Street Food","+962 6 464 1300"),

    ("Sufra Restaurant","restaurant","Authentic Jordanian cuisine in a traditional villa setting.",
     31.9681,35.9239,90,"medium",4.8,
     "https://picsum.photos/seed/sufra_restaurant/800/500",
     "Amman","12 PM - 11 PM",[6,15,17,3],"🍽️",None,"Jordanian","+962 6 461 1468"),
]
# Each service: (name, category, description, lat, lng, price_from, price_unit, location, hours, tags, emoji, phone, whatsapp, website)
[
("Wadi Rum Jeep and Camel Tours","experience","Full and half-day 4x4 jeep tours through Wadi Rum's red desert. Sunset camel rides and Bedouin camp dinners included.",29.5765,35.4209,25.0,"per person","Wadi Rum Village","6 AM - 8 PM",[1,20,15,23],"🚙","+962 7 7742 5566","+962 7 7742 5566","https://picsum.photos/seed/wadi_rum_jeep_camel/1600/900"),

("Aqaba Diving and Snorkeling Center","experience","PADI-certified dive center offering reef dives beginner courses and snorkeling trips to Aqaba's pristine coral reefs.",29.5107,34.9907,35.0,"per dive","Aqaba Beach","7 AM - 6 PM",[9,21,1,11,27],"🤿","+962 3 203 1771","+962 7 9611 3344","https://picsum.photos/seed/aqaba_diving_snorkeling/1600/900"),

("Petra Horse and Carriage Rides","experience","Traditional horse rides through the Siq to Petra's Treasury. Licensed guides with gentle horses for all ages.",30.3285,35.4444,15.0,"per person","Petra Visitor Centre","6 AM - 5 PM",[4,14,15,10],"🐎","+962 7 7715 8899","+962 7 7715 8899","https://picsum.photos/seed/petra_horse_carriage/1600/900"),

("Dead Sea Mud Spa Treatment","wellness","Full Dead Sea mineral mud wrap salt scrub and floating experience at a private beach spa. Includes towels and showers.",31.5525,35.5814,40.0,"per person","Dead Sea Resorts Area","8 AM - 6 PM",[22,2,9,18],"🧖","+962 5 356 1234","+962 5 356 1234","https://picsum.photos/seed/dead_sea_spa_mud/1600/900"),

("Amman City Food Tour","experience","3-hour walking food tour through Downtown Amman. Visit 8 legendary eateries including falafel knafeh mansaf and kunafa.",31.9538,35.9313,30.0,"per person","Downtown Amman","9 AM - 12 PM",[6,15,17,14],"🥙","+962 7 9000 1234","+962 7 9000 1234","https://picsum.photos/seed/amman_food_tour/1600/900"),

("Dana to Petra Trek 2 days","adventure","Epic guided 2-day trekking route through Dana Biosphere Reserve ending at Petra's back door via Little Petra.",30.6960,35.6050,120.0,"per person","Dana Village","7 AM start",[8,5,1,23,24],"🥾","+962 3 227 0497","+962 7 9512 3456","https://picsum.photos/seed/dana_petra_trek/1600/900"),

("Jerash Audio Guide Tour","experience","Self-guided audio tour of Jerash with expert commentary at 40 sites. Available in 12 languages on your phone.",32.2750,35.8960,8.0,"per person","Jerash","7:30 AM - 6 PM",[4,10,3,14],"🎧",None,None,"https://picsum.photos/seed/jerash_ruins/1600/900"),

("Wadi Mujib Canyoning Adventure","adventure","Guided slot canyon adventure swim wade and scramble through the dramatic Wadi Mujib gorge. All equipment provided.",31.4675,35.5660,21.0,"per person","Wadi Mujib Reserve","Apr-Oct 8 AM - 3 PM",[1,8,9,5,28],"🧗","+962 6 464 4523","+962 7 9876 5432","https://picsum.photos/seed/wadi_mujib_canyon/1600/900"),

("Jordan Photography Tours","experience","Sunrise and sunset photography workshops at Jordan's most scenic locations led by professional landscape photographers.",31.9552,35.9175,75.0,"per person","Various locations","Varies",[11,1,5,20],"📷","+962 7 9500 7788","+962 7 9500 7788","https://picsum.photos/seed/jordan_photography_tour/1600/900"),

("Azraq Birdwatching Tour","wildlife","Guided birdwatching at Azraq Wetland Reserve with 250 species recorded. Peak migration season Oct-April.",31.8268,36.8125,15.0,"per person","Azraq Wetland Reserve","7 AM - 4 PM",[24,5,11,19,29],"🦅","+962 5 383 5017",None,"https://picsum.photos/seed/azraq_birdwatching/1600/900"),

("Aqaba Glass-Bottom Boat Tour","experience","See Aqaba's coral reefs without getting wet. 90-minute glass-bottom boat tour over the most colorful reefs.",29.5107,34.9907,18.0,"per person","Aqaba Marina","9 AM - 4 PM",[21,9,14,11],"⛵","+962 3 201 4455","+962 7 9988 7766","https://picsum.photos/seed/aqaba_boat_coral/1600/900")
]
# ══════════════════════════════════════════════════════════════════════════════
# DATABASE FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

def connect():
    return psycopg2.connect(**DB_CONFIG)


def seed_tags(conn):
    print("\n📌 Seeding tags...")
    with conn.cursor() as cur:
        # Ensure tags table exists
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tags (
                tag_id   SERIAL PRIMARY KEY,
                tag_name VARCHAR(100) UNIQUE NOT NULL
            );
        """)
        for tag_id, tag_name in TAGS:
            cur.execute("""
                INSERT INTO tags (tag_id, tag_name)
                VALUES (%s, %s)
                ON CONFLICT (tag_name) DO NOTHING;
            """, (tag_id, tag_name))
    conn.commit()
    print(f"   ✅ {len(TAGS)} tags ready")


def seed_places_postgres(conn):
    print("\n🏛️  Seeding places into PostgreSQL...")
    inserted = 0
    skipped  = 0
    with conn.cursor() as cur:
        for (name, category, description, lat, lng, duration, cost,
             rating, image_url, location, hours, tag_ids, emoji,
             price_per_night, cuisine, phone) in PLACES:
            # Skip if already exists
            cur.execute("SELECT place_id FROM places WHERE name=%s", (name,))
            if cur.fetchone():
                skipped += 1
                continue

            cur.execute("""
                INSERT INTO places
                  (name, category, description, latitude, longitude,
                   duration_minutes, cost_level, rating, image_url,
                   cluster_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING place_id;
            """, (name, category, description, lat, lng,
                  duration, cost, rating, image_url, 1))
            place_id = cur.fetchone()[0]

            for tag_id in tag_ids:
                cur.execute("""
                    INSERT INTO place_tags (place_id, tag_id)
                    VALUES (%s, %s) ON CONFLICT DO NOTHING;
                """, (place_id, tag_id))
            inserted += 1

    conn.commit()
    print(f"   ✅ {inserted} inserted, {skipped} already existed")
    return inserted


def seed_services_postgres(conn):
    """Services don't have a services table in Postgres — they live in Firebase only."""
    print("\n🔧 Services are Firebase-only (no services table in PostgreSQL)")


# ══════════════════════════════════════════════════════════════════════════════
# FIREBASE FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

def init_firebase():
    if not FIREBASE_AVAILABLE:
        return None
    if not os.path.exists(FIREBASE_KEY_PATH):
        print(f"\n⚠️  Firebase key not found at '{FIREBASE_KEY_PATH}'")
        print("   Skipping Firebase seeding. To enable:")
        print("   1. Firebase Console → Project Settings → Service accounts")
        print("   2. Generate new private key → save as 'firebase_key.json'")
        print("   3. Place it next to this script and re-run")
        return None
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(FIREBASE_KEY_PATH)
            firebase_admin.initialize_app(cred)
        return fb_firestore.client()
    except Exception as e:
        print(f"\n❌ Firebase init failed: {e}")
        return None


def seed_places_firebase(db):
    print("\n🔥 Seeding places into Firestore...")
    col     = db.collection('places')
    inserted = 0
    skipped  = 0

    for (name, category, description, lat, lng, duration, cost,
         rating, image_url, location, hours, tag_ids, emoji,
         price_per_night, cuisine, phone) in PLACES:

        # Check duplicate by name
        existing = col.where('name', '==', name).limit(1).get()
        if list(existing):
            skipped += 1
            continue

        # Map tag IDs to tag names
        tag_name_map = {tid: tname for tid, tname in TAGS}
        tag_names = [tag_name_map[tid] for tid in tag_ids if tid in tag_name_map]

        doc = {
            'name':            name,
            'description':     description,
            'category':        category,
            'lat':             lat,
            'lng':             lng,
            'rating':          rating,
            'reviewCount':     0,
            'imageEmoji':      emoji,
            'location':        location,
            'hours':           hours,
            'phone':           phone,
            'tags':            tag_names,
            'photoUrls':       [image_url] if image_url else [],
            'listingStatus':   'approved',
            'ownerId':         None,
            'ownerName':       None,
            'pricePerNight':   price_per_night,
            'cuisine':         cuisine,
            'submittedAt':     datetime.utcnow(),
        }
        col.add(doc)
        inserted += 1
        print(f"   + {name}")

    print(f"   ✅ {inserted} inserted, {skipped} already existed")


def seed_services_firebase(db):
    print("\n🔧 Seeding services into Firestore...")
    col      = db.collection('services')
    inserted = 0
    skipped  = 0

    for (name, category, description, lat, lng, price_from, price_unit,
         location, hours, tag_ids, emoji, phone, whatsapp, website) in SERVICES:

        existing = col.where('name', '==', name).limit(1).get()
        if list(existing):
            skipped += 1
            continue

        tag_name_map = {tid: tname for tid, tname in TAGS}
        tag_names = [tag_name_map[tid] for tid in tag_ids if tid in tag_name_map]

        doc = {
            'name':          name,
            'description':   description,
            'category':      category,
            'lat':           lat,
            'lng':           lng,
            'priceFrom':     price_from,
            'priceUnit':     price_unit,
            'location':      location,
            'hours':         hours,
            'tags':          tag_names,
            'imageEmoji':    emoji,
            'phone':         phone,
            'whatsapp':      whatsapp,
            'website':       website,
            'photoUrls':     [],
            'ownerId':       'seeder',
            'ownerName':     'Gojo Team',
            'listingStatus': 'approved',
            'rating':        0.0,
            'reviewCount':   0,
            'submittedAt':   datetime.utcnow(),
        }
        col.add(doc)
        inserted += 1
        print(f"   + {name}")

    print(f"   ✅ {inserted} inserted, {skipped} already existed")


def seed_users_firebase(db):
    """Create the default admin user document in Firestore."""
    print("\n👤 Setting up admin user in Firestore...")
    print("   ℹ️  Sign up with any email in the app first, then run this to promote to admin.")
    print("   Or: Firebase Console → Firestore → users → {your-uid} → role: 'admin'")


# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

def main():
    print("╔══════════════════════════════════════════════════════╗")
    print("║           GOJO DATA SEEDER                          ║")
    print("╚══════════════════════════════════════════════════════╝")
    print(f"  Places  : {len(PLACES)}")
    print(f"  Services: {len(SERVICES)}")
    print(f"  Tags    : {len(TAGS)}")
    print("║           GOJO DATA SEEDER                          ║")
    print("╚══════════════════════════════════════════════════════╝")
  
    # ── PostgreSQL ─────────────────────────────────────────────────────────
    print("\n── PostgreSQL ─────────────────────────────────────────")
    try:
        conn = connect()
        print("   ✅ Connected to PostgreSQL")
        seed_tags(conn)
        seed_places_postgres(conn)
        seed_services_postgres(conn)
        conn.close()
        print("   ✅ PostgreSQL seeding complete")
    except Exception as e:
        print(f"   ❌ PostgreSQL error: {e}")
        print("   Make sure PostgreSQL is running and DB_CONFIG is correct")

    # ── Firebase ────────────────────────────────────────────────────────────
    print("\n── Firebase Firestore ─────────────────────────────────")
    db = init_firebase()
    if db:
        print("   ✅ Connected to Firebase")
        seed_places_firebase(db)
        seed_services_firebase(db)
        seed_users_firebase(db)
        print("   ✅ Firebase seeding complete")

    print("\n╔══════════════════════════════════════════════════════╗")
    print("║  ✅  SEEDING DONE                                    ║")
    print("║                                                      ║")
    print("║  Next steps:                                         ║")
    print("║  1. Restart your backend:                            ║")
    print("║     uvicorn api:app --reload --host 0.0.0.0 --port 8001║")
    print("║  2. flutter run                                      ║")
    print("║  3. All places + services now visible to tourists    ║")
    print("╚══════════════════════════════════════════════════════╝")


if __name__ == "__main__":
    main()
def fix_image_urls_firebase(db):
    print("\n🔧 Fixing image URLs in existing Firestore places...")
    col = db.collection('places')
    docs = col.get()
    fixed = 0
    for doc in docs:
        d = doc.to_dict()
        old_urls = d.get('photoUrls', [])
        if not old_urls:
            continue
        url = old_urls[0]
        # Fix Wikimedia thumb URLs
        if '/thumb/' in url:
            import re
            new_url = re.sub(
                r'https://upload\.wikimedia\.org/wikipedia/commons/thumb/([^/]+/[^/]+)/[^/]+',
                r'https://upload.wikimedia.org/wikipedia/commons/\1',
                url
            )
            col.document(doc.id).update({'photoUrls': [new_url]})
            print(f"   Fixed: {d['name']}")
            fixed += 1
        # Fix Unsplash bare ?w=800
        elif 'unsplash.com' in url and 'auto=format' not in url:
            new_url = url.replace('?w=800', '?w=800&auto=format&fit=crop')
            col.document(doc.id).update({'photoUrls': [new_url]})
            print(f"   Fixed: {d['name']}")
            fixed += 1
    print(f"   ✅ {fixed} documents updated")