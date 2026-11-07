import requests
import csv
from io import StringIO
import datetime
from sqlalchemy.orm import Session
import models
import schemas
import requests

FIRMS_API_KEY = "6N5gxUYZ7qnNxTrox89kCwaZQ5NCmyirJJsGg3uuVeUX"
FIRMS_SOURCE = "VIIRS_SNPP_NRT"
COUNTRY_CODE = "TUR"
DAY_RANGE = "1"

def fetch_active_fires():
    urls = [
        ("NOAA-20 VIIRS", "https://firms.modaps.eosdis.nasa.gov/data/active_fire/noaa-20-viirs-c2/csv/J1_VIIRS_C2_Global_24h.csv"),
        ("Suomi-NPP VIIRS", "https://firms.modaps.eosdis.nasa.gov/data/active_fire/suomi-npp-viirs-c2/csv/SUOMI_NPP_VIIRS_C2_Global_24h.csv"),
        ("MODIS", "https://firms.modaps.eosdis.nasa.gov/data/active_fire/modis-c6.1/csv/MODIS_C6_1_Global_24h.csv")
    ]
    
    all_data = []
    
    for sensor_name, url in urls:
        print(f"Fetching from: {url}")
        response = requests.get(url)
        
        if response.status_code != 200:
            print(f"Failed to fetch data from {url}. Status code: {response.status_code}")
            continue

        csv_reader = csv.DictReader(StringIO(response.text))
        for row in csv_reader:
            lat = float(row['latitude'])
            lon = float(row['longitude'])
            
            # Filter for Turkey bounding box (approx: lat 35-43, lon 25-45)
            if not (35.0 <= lat <= 43.0 and 25.0 <= lon <= 45.0):
                continue
            
            try:
                # MODIS uses 'brightness', VIIRS uses 'bright_ti4'
                brightness = float(row.get('bright_ti4', row.get('brightness', 0.0)))
                # MODIS uses 'confidence' as 0-100, VIIRS uses l/n/h
                conf_val = row.get('confidence', 'n')
                if str(conf_val).isdigit():
                    conf_val = int(conf_val)
                else:
                    conf_map = {'h': 100, 'n': 50, 'l': 20}
                    conf_val = conf_map.get(conf_val, 50)
                
                # 'acq_date' and 'acq_time' are common
                external_id = f"TR-{row['acq_date']}-{row['acq_time']}-{lat}-{lon}"
                
                fire_data = {
                    "external_id": external_id,
                    "satellite": row.get('satellite', 'Unknown'),
                    "sensor": sensor_name,
                    "latitude": lat,
                    "longitude": lon,
                    "fire_metric": float(row.get('frp', 0.0)),
                    "brightness_temperature": brightness,
                    "confidence": conf_val,
                    "status": "ACTIVE"
                }
                all_data.append(fire_data)
            except Exception as e:
                print(f"Error parsing row: {e}")
                
    return all_data

def process_and_save_fires(db: Session):
    fires = fetch_active_fires()
    new_fires_count = 0
    for f in fires:
        # Check clustering / already exists
        existing = db.query(models.FireEvent).filter(models.FireEvent.external_id == f["external_id"]).first()
        if not existing:
            # TODO: Reverse Geocoding (Nominatim API)
            # For now we'll just save it without province
            
            # 10 MW Threshold Check
            if f["fire_metric"] >= 10.0:
                new_fire = models.FireEvent(**f)
                db.add(new_fire)
                new_fires_count += 1
                
    db.commit()
    return new_fires_count
