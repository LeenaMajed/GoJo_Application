import math
import os

import numpy as np
import pandas as pd
from haversine import haversine, Unit
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sqlalchemy import create_engine
from sqlalchemy.engine import URL


class TourismRecommender:
    def __init__(self, db_config):
        self.db_config = db_config
        self.df = None

    def load_data(self):
        query = """
            SELECT p.*, STRING_AGG(t.tag_name, ' ') as all_tags
            FROM places p
            LEFT JOIN place_tags pt ON p.place_id = pt.place_id
            LEFT JOIN tags t ON pt.tag_id = t.tag_id
            GROUP BY p.place_id;
        """
        user = (self.db_config.get('user') or '').strip()
        pw = self.db_config.get('password') or ''
        host = (self.db_config.get('host') or '').strip()
        db = (self.db_config.get('dbname') or '').strip()
        port = int(self.db_config.get('port', 5432))
        sslmode = self.db_config.get('sslmode')

        connection_url = URL.create(
            drivername="postgresql+psycopg2",
            username=user,
            password=pw,
            host=host,
            port=port,
            database=db,
            query={"sslmode": sslmode} if sslmode else None,
        )
        engine = create_engine(connection_url)

        try:
            print(f"Connecting to DB host: {host}:{port}")
            self.df = pd.read_sql(query, engine)

            self.df['all_tags'] = self.df['all_tags'].fillna('')
            self.df['category'] = self.df['category'].fillna('')
            self.df['description'] = self.df['description'].fillna('')
            self.df['metadata'] = (
                self.df['category'] + " " +
                self.df['all_tags'] + " " +
                self.df['description']
            ).str.lower()

            print(f"✅ Successfully loaded {len(self.df)} places from database.")

        except Exception as e:
            print(f"❌ Error loading data: {e}")
            raise RuntimeError(f"Failed to load data: {e}")

    def _normalize_text(self, text):
        cleaned = ''.join(ch.lower() if ch.isalnum() else ' ' for ch in str(text))
        return ' '.join(cleaned.split())

    def _extract_favorite_names(self, user_preferences):
        names = set()
        raw = user_preferences.get('favorites', user_preferences.get('favorite_places', []))

        if isinstance(raw, str):
            for item in raw.split(','):
                normalized = self._normalize_text(item)
                if normalized:
                    names.add(normalized)
            return names

        if isinstance(raw, dict):
            for key in ('names', 'place_names', 'favorite_places', 'favorites'):
                values = raw.get(key, [])
                if isinstance(values, str):
                    values = values.split(',')
                if isinstance(values, (list, tuple, set)):
                    for item in values:
                        normalized = self._normalize_text(item)
                        if normalized:
                            names.add(normalized)
            return names

        if isinstance(raw, (list, tuple, set)):
            for item in raw:
                normalized = self._normalize_text(
                    item.get('name', '') if isinstance(item, dict) else item
                )
                if normalized:
                    names.add(normalized)

        return names

    def recommend_hybrid(self, user_prefs, top_n=10):
        if self.df is None or self.df.empty:
            raise RuntimeError("No data loaded. Call load_data() first.")

        user_input = f"{user_prefs.get('category', '')} {user_prefs.get('tags', '')}".lower()
        tfidf = TfidfVectorizer(stop_words='english')
        tfidf_matrix = tfidf.fit_transform(self.df['metadata'].tolist() + [user_input])
        cb_scores = cosine_similarity(tfidf_matrix[-1], tfidf_matrix[:-1]).flatten()

        favorite_names = self._extract_favorite_names(user_prefs)

        def kb_score(row):
            score = 0
            if row['category'] == user_prefs.get('category'):
                score += 5
            if row['cost_level'] == user_prefs.get('budget'):
                score += 3
            score += (row['rating'] or 0) * 0.5
            row_name = self._normalize_text(row.get('name', ''))
            if row_name and any(
                fav == row_name or fav in row_name or row_name in fav
                for fav in favorite_names
            ):
                score += 6
            return score

        kb_scores = self.df.apply(kb_score, axis=1)

        results = self.df.copy()
        results['cb_norm'] = cb_scores / (cb_scores.max() + 1e-9)
        results['kb_norm'] = kb_scores / (kb_scores.max() + 1e-9)
        results['final_score'] = (results['cb_norm'] * 0.5) + (results['kb_norm'] * 0.5)

        def build_reason(row):
            reasons = []
            if row['category'] == user_prefs.get('category'):
                reasons.append(f"matches your {user_prefs.get('category')} preference")
            if row['cost_level'] == user_prefs.get('budget'):
                reasons.append(f"fits your {user_prefs.get('budget')} budget")
            if (row['rating'] or 0) >= 4:
                reasons.append(f"highly rated {row['rating']}/5")
            if row['cb_norm'] >= 0.35:
                reasons.append("aligns well with your tags")
            row_name = self._normalize_text(row.get('name', ''))
            if row_name and any(
                fav == row_name or fav in row_name or row_name in fav
                for fav in favorite_names
            ):
                reasons.append("matches one of your favorite places")
            return "; ".join(reasons) if reasons else "ranked highly from your preferences"

        results['reason_why'] = results.apply(build_reason, axis=1)
        return results.sort_values('final_score', ascending=False).head(top_n)

    def generate_itinerary_geospatial(self, recommended_df, days, max_minutes_per_day=480):
        remaining_places = recommended_df.to_dict(orient='records')
        itinerary = {f"Day {i+1}": [] for i in range(days)}
        day_durations = {f"Day {i+1}": 0 for i in range(days)}

        for d in range(1, days + 1):
            day_key = f"Day {d}"

            if not remaining_places:
                break

            current_stop = remaining_places.pop(0)
            itinerary[day_key].append(current_stop)
            day_durations[day_key] += current_stop['duration_minutes']

            while day_durations[day_key] < max_minutes_per_day:
                nearest_idx = -1
                min_dist = float('inf')

                for i, candidate in enumerate(remaining_places):
                    dist = haversine(
                        (current_stop['latitude'], current_stop['longitude']),
                        (candidate['latitude'], candidate['longitude']),
                        unit=Unit.KILOMETERS
                    )
                    if day_durations[day_key] + candidate['duration_minutes'] <= max_minutes_per_day:
                        if dist < min_dist:
                            min_dist = dist
                            nearest_idx = i

                if nearest_idx != -1:
                    current_stop = remaining_places.pop(nearest_idx)
                    itinerary[day_key].append(current_stop)
                    day_durations[day_key] += (current_stop['duration_minutes'] + 30)
                else:
                    break

        return itinerary, day_durations


if __name__ == "__main__":
    db_params = {
        "dbname": "Test2",
        "user": "postgres",
        "password": "1234",
        "host": "localhost"
    }

    recommender = TourismRecommender(db_params)
    recommender.load_data()

    user_preferences = {
        "category": "nature",
        "tags": "hiking",
        "budget": "low",
        "favorites": []
    }

    top_places = recommender.recommend_hybrid(user_preferences, top_n=10)
    plan, totals = recommender.generate_itinerary_geospatial(top_places, days=2)

    print("\n✨ YOUR CUSTOM TRAVEL PLAN ✨")
    for day, activities in plan.items():
        print(f"\n📅 {day.upper()} (Total Time: {totals[day]/60:.1f} hrs)")
        print("-" * 30)
        if not activities:
            print("  No activities fit today's schedule.")
        for act in activities:
            print(f"📍 {act['name']}")
            print(f"   📝 {act['description']}")
            if act.get('reason_why'):
                print(f"   💡 {act['reason_why']}")
            print(f"   ⏳ {act['duration_minutes']/60:.1f} hrs")
            print("-" * 15)

            