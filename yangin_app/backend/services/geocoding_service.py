import requests
import time

def reverse_geocode(lat: float, lon: float):
    url = f"https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat={lat}&lon={lon}&zoom=18&addressdetails=1"
    headers = {
        'User-Agent': 'YanginTakipApp/1.0 (contact@example.com)'
    }
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            address = data.get("address", {})
            
            return {
                "province": address.get("province", address.get("state", "Bilinmiyor")),
                "district": address.get("town", address.get("county", address.get("city_district", "Bilinmiyor"))),
                "village": address.get("village", address.get("suburb", address.get("neighbourhood", "Bilinmiyor"))),
                "locality": address.get("hamlet", address.get("locality", "Bilinmiyor")),
                "country_code": address.get("country_code", "")
            }
        else:
            return None
    except Exception as e:
        print(f"Geocoding error: {e}")
        return None
