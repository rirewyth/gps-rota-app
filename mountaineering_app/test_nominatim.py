import requests
import json

def test_nominatim(query):
    user_agent = 'RotaPlusMountaineeringApp/1.0'
    url = f'https://nominatim.openstreetmap.org/search?q={query}&countrycodes=tr&format=jsonv2&addressdetails=1&limit=40'
    headers = {'User-Agent': user_agent}
    
    print(f"Searching for: {query}")
    response = requests.get(url, headers=headers)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"Total results from API: {len(data)}")
        
        items = []
        for jsonResult in data:
            osmClass = jsonResult.get('class', '')
            osmType = jsonResult.get('type', '')
            display_name = jsonResult.get('display_name', '')
            
            # FILTERS from routing_service.dart
            is_excluded = (osmClass == 'building' or osmClass == 'highway' or osmClass == 'amenity' or
                          osmType == 'house' or osmType == 'apartment' or osmType == 'residential')
            
            isSettlement = osmClass == 'place' and \
                (osmType in ['city', 'town', 'village', 'hamlet', 'suburb', 'quarter'])
            
            isMountain = osmClass == 'natural' and \
                (osmType in ['peak', 'volcano', 'mountain_range'])
            
            if isSettlement or isMountain:
                items.append({
                    'display_name': display_name,
                    'class': osmClass,
                    'type': osmType,
                    'status': 'INCLUDED'
                })
            else:
                items.append({
                    'display_name': display_name,
                    'class': osmClass,
                    'type': osmType,
                    'status': 'EXCLUDED' + (' (Filter)' if is_excluded else ' (Not Settlement/Mountain)')
                })
        
        for item in items:
            print(f"- [{item['status']}] {item['class']}/{item['type']}: {item['display_name'][:100]}")
            
test_nominatim('Ankara')
test_nominatim('Erciyes')
test_nominatim('Kayseri')
test_nominatim('İstanbul')
