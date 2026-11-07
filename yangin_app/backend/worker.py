import time
import schedule
from database import SessionLocal
from services.firms_service import process_and_save_fires
from services.geocoding_service import reverse_geocode
import models

def job():
    print("Running FIRMS sync job...")
    db = SessionLocal()
    try:
        # We need to update firms_service to use geocoding
        from services.firms_service import fetch_active_fires
        fires = fetch_active_fires()
        new_fires_count = 0
        for f in fires:
            existing = db.query(models.FireEvent).filter(models.FireEvent.external_id == f["external_id"]).first()
            if not existing and f["fire_metric"] >= 10.0:
                print(f"New fire detected at {f['latitude']}, {f['longitude']}")
                
                geo = reverse_geocode(f["latitude"], f["longitude"])
                if geo:
                    if geo.get("country_code") != "tr":
                        time.sleep(1)
                        continue # Skip non-Turkish fires
                    f["province"] = geo["province"]
                    f["district"] = geo["district"]
                    f["village"] = geo["village"]
                    f["locality"] = geo["locality"]
                    
                new_fire = models.FireEvent(**f)
                db.add(new_fire)
                db.commit()
                new_fires_count += 1
                
                # Be kind to Nominatim
                time.sleep(1)
        print(f"Sync complete. Added {new_fires_count} new fires.")
    finally:
        db.close()

if __name__ == "__main__":
    print("Starting background worker...")
    job() # run once immediately
    schedule.every(10).minutes.do(job)
    
    while True:
        schedule.run_pending()
        time.sleep(1)
