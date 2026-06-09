import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationSearchResult {
  final String displayName;
  final double lat;
  final double lon;
  final String type;
  final String category;
  final String? importance;

  LocationSearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.type,
    required this.category,
    this.importance,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      displayName: json['display_name'] ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lon: double.tryParse(json['lon']?.toString() ?? '0') ?? 0,
      type: json['type'] ?? 'place',
      category: json['class'] ?? 'place',
      importance: json['importance']?.toString(),
    );
  }
}

class RouteInformation {
  final double distance;
  final double duration;
  final List<LatLng> coordinates;
  final double elevationGain;
  final double maxElevation;
  final double averageElevation;

  RouteInformation({
    required this.distance,
    required this.duration,
    required this.coordinates,
    this.elevationGain = 0,
    this.maxElevation = 0,
    this.averageElevation = 0,
  });
}

class RoutingService {
  static const String _userAgent = 'RotaPlusMountaineeringApp/1.0';

  // ─── SADECE İZİN VERİLEN TİPLER ─────────────────────────────────────────
  // Dağ & Zirve
  static const Set<String> _mountainTypes = {
    'peak', 'mountain', 'hill', 'ridge', 'volcano', 'cliff', 'rock',
    'scree', 'glacier', 'plateau', 'saddle', 'valley', 'cave_entrance',
  };

  // Yürüyüş & Doğa
  static const Set<String> _hikingTypes = {
    'track',           // arazi yolu (toprak)
    'path',            // yürüyüş patikası
    'footway',         // yaya yolu
    'steps',           // merdiven/yokuş
    'bridleway',       // at/yaya yolu
    'hiking',
    'national_park',
    'nature_reserve',
    'protected_area',
    'forest', 'wood',
    'camp_site', 'alpine_hut', 'wilderness_hut',
    'viewpoint',
    'lake', 'river', 'stream', 'waterfall', 'spring',
  };

  // Yerleşim (sadece idari birimler - il, ilçe, köy)
  static const Set<String> _settlementTypes = {
    'city',          // şehir/büyükşehir
    'town',          // kasaba
    'village',       // köy
    'hamlet',        // mezra/belde
    'neighborhood',  // mahalle
    'municipality',  // belediye
    'county',        // ilçe
    'state',         // il
    'region',        // bölge
    'district',      // ilçe/mahalle
    'suburb',        // semt
    'residential',   // yerleşim alanı
    'allotments',    // bahçeler/yerleşim
  };

  // ─── KESİNLİKLE YASAK ────────────────────────────────────────────────────
  static const Set<String> _blockedClasses = {
    'building', 'office', 'shop', 'craft', 'aerialway', 'aeroway', 
    'railway',
  };

  static const Set<String> _blockedTypes = {
    'house', 'apartments', 'apartment', 'garage', 'detached',
    'terrace', 'semidetached_house', 'warehouse', 'factory',
    'construction', 'ruins',
  };

  /// Yer Araması — Mapbox, Google, Yandex ve Nominatim hibrit arama
  static Future<List<LocationSearchResult>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    
    // 1. ÖNCE MAPBOX (Türkiye köyleri ve yerel detaylar için en iyisi)
    final mapboxResults = await _searchMapbox(query);
    if (mapboxResults.isNotEmpty) return mapboxResults;

    // 2. GOOGLE (İşletmeler ve genel mekanlar için kaliteli veri)
    final googleResults = await _searchGoogle(query);
    if (googleResults.isNotEmpty) return googleResults;

    // 3. YANDEX (Yedek kaliteli veri)
    final yandexResults = await _searchYandex(query);
    if (yandexResults.isNotEmpty) return yandexResults;

    // 4. OSM (Son çare ücretsiz veri)
    return _searchNominatim(query);
  }

  static Future<List<LocationSearchResult>> _searchMapbox(String query) async {
    try {
      const String mapboxToken = 'pk.eyJ1Ijoic2VyY2Fub3JhbGwiLCJhIjoiY21vdGxneTR1MDZkNjJ1czl5OG4xZGRtNSJ9.aZd3CyiISCcxlcR0hXkhhQ';
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json'
        '?access_token=$mapboxToken'
        '&country=tr'
        '&language=tr'
        '&limit=10'
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final List<dynamic> features = data['features'] ?? [];
      
      final List<LocationSearchResult> items = [];
      for (final f in features) {
        final center = f['center']; // [lng, lat]
        items.add(LocationSearchResult(
          displayName: f['place_name'] ?? '',
          lat: (center[1] as num).toDouble(),
          lon: (center[0] as num).toDouble(),
          type: (f['place_type'] as List).isNotEmpty ? f['place_type'][0] : 'place',
          category: 'mapbox',
        ));
      }
      return items;
    } catch (e) {
      debugPrint('Mapbox search error: $e');
      return [];
    }
  }

  static Future<List<LocationSearchResult>> _searchGoogle(String query) async {
    try {
      // TODO: Kendi API Key'inizi buraya yapıştırın
      const String googleApiKey = 'AIzaSyB3BaXHXe2md4ljgrFL2b2fZRrhChfyl1o';
      if (googleApiKey == 'YOUR_GOOGLE_API_KEY_HERE') return [];

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(query)}'
        '&language=tr'
        '&key=$googleApiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      
      final List<LocationSearchResult> items = [];
      for (final r in results) {
        final loc = r['geometry']['location'];
        items.add(LocationSearchResult(
          displayName: r['formatted_address'] ?? r['name'] ?? '',
          lat: (loc['lat'] as num).toDouble(),
          lon: (loc['lng'] as num).toDouble(),
          type: (r['types'] as List).isNotEmpty ? r['types'][0] : 'place',
          category: 'google',
        ));
      }
      return items;
    } catch (e) {
      debugPrint('Google search error: $e');
      return [];
    }
  }

  static Future<List<LocationSearchResult>> _searchYandex(String query) async {
    try {
      // Not: Kullanıcı kendi API Key'ini alana kadar sınırlı çalışabilir veya hata verebilir.
      const String yandexApiKey = '7ecf8473-10e8-4228-a472-881273934301'; // Örnek/Public key denemesi
      final uri = Uri.parse(
        'https://geocode-maps.yandex.ru/1.x/'
        '?apikey=$yandexApiKey'
        '&geocode=${Uri.encodeComponent(query)}'
        '&format=json'
        '&lang=tr_TR'
        '&results=20',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final List<dynamic> members = data['response']['GeoObjectCollection']['featureMember'] ?? [];
      
      final List<LocationSearchResult> items = [];
      for (final m in members) {
        final obj = m['GeoObject'];
        final pos = obj['Point']['pos'].toString().split(' '); // "lon lat"
        final lon = double.tryParse(pos[0]) ?? 0;
        final lat = double.tryParse(pos[1]) ?? 0;
        
        items.add(LocationSearchResult(
          displayName: obj['metaDataProperty']['GeocoderMetaData']['text'] ?? '',
          lat: lat,
          lon: lon,
          type: obj['metaDataProperty']['GeocoderMetaData']['kind'] ?? 'place',
          category: 'yandex',
        ));
      }
      return items;
    } catch (e) {
      debugPrint('Yandex search error: $e');
      return [];
    }
  }

  static Future<List<LocationSearchResult>> _searchNominatim(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&countrycodes=tr'
        '&format=jsonv2'
        '&addressdetails=1'
        '&extratags=1'
        '&namedetails=1'
        '&limit=80',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'tr',
      });

      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body);
      final List<LocationSearchResult> items = [];

      for (final raw in data) {
        final String osmClass = (raw['class'] ?? '').toString().toLowerCase();
        final String osmType  = (raw['type']  ?? '').toString().toLowerCase();

        // Filtreleme yapmıyoruz, tüm sonuçları (mekan, bina, sokak vb.) gösteriyoruz
        // Acil durum uygulaması olduğu için kullanıcı her yeri arayabilmeli
        items.add(LocationSearchResult.fromJson(raw));
      }

      // Sıralama: Arama sorgusuyla eşleşme > Önem (Importance)
      items.sort((a, b) {
        final q = query.toLowerCase();
        bool aMatchesView = q.length > 2 && a.displayName.toLowerCase().contains(q);
        bool bMatchesView = q.length > 2 && b.displayName.toLowerCase().contains(q);
        if (aMatchesView != bMatchesView) return aMatchesView ? -1 : 1;

        final ia = double.tryParse(a.importance ?? '0') ?? 0;
        final ib = double.tryParse(b.importance ?? '0') ?? 0;
        return ib.compareTo(ia);
      });

      return items.take(40).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ters Coğrafi Kodlama (Koordinattan Adres Bulma)
  static Future<String> getAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=jsonv2');
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Genelde 'name' veya 'display_name' kısmının başını alalım
        String? name = data['name'];
        if (name == null || name.isEmpty) {
          final address = data['address'];
          name = address['road'] ?? address['suburb'] ?? address['village'] ?? address['town'] ?? 'Bilinmeyen Bölge';
        }
        return name ?? 'Bilinmeyen Bölge';
      }
    } catch (_) {}
    return 'Bilinmeyen Bölge';
  }

  /// BRouter hiking-mountain profili (gerçek dağ patikası ve off-road yürüyüş yolları)
  /// Ücretsiz public endpoint — kayıt gerekmez.
  static Future<RouteInformation?> getRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    // 📍 1. Deneme: BRouter hiking-mountain 📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍
    final result = await _brouterHiking(waypoints);
    if (result != null) return _forceSnapToWaypoints(result, waypoints);

    // 📍 2. Fallback: Valhalla pedestrian 📍📍📍📍📍📍📍📍📍📍📍📍📍📍
    final fallback = await _valhallaHiking(waypoints);
    if (fallback != null) return _forceSnapToWaypoints(fallback, waypoints);

    // 📍 3. Son Çare: OSRM foot routing 📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍📍
    final osrm = await _osrmFoot(waypoints);
    if (osrm != null) return _forceSnapToWaypoints(osrm, waypoints);

    return null;
  }

  static RouteInformation? _forceSnapToWaypoints(RouteInformation? route, List<LatLng> waypoints) {
    if (route == null || waypoints.isEmpty) return null;
    final List<LatLng> coords = List.from(route.coordinates);
    double extraDist = 0.0;
    
    // Rota motorları bazen zirvelere patika olmadığı için tam zirvede bitmez. 
    // Kullanıcının dokunduğu yere kadar rotayı uzatırız ("Serbest Çizim" son nokta).
    final startDistance = const Distance().distance(coords.first, waypoints.first);
    if (startDistance > 5) {
      coords.insert(0, waypoints.first);
      extraDist += startDistance;
    }
    
    final endDistance = const Distance().distance(coords.last, waypoints.last);
    if (endDistance > 5) {
      coords.add(waypoints.last);
      extraDist += endDistance;
    }
    
    return RouteInformation(
      distance: route.distance + extraDist,
      duration: route.duration, // Basitlik için süreyi değiştirmedik
      coordinates: coords,
      elevationGain: route.elevationGain,
      maxElevation: route.maxElevation,
      averageElevation: route.averageElevation,
    );
  }

  /// BRouter — hiking-mountain profili
  static Future<RouteInformation?> _brouterHiking(List<LatLng> waypoints) async {
    try {
      final coordsString = waypoints.map((p) => '${p.longitude},${p.latitude}').join('|');
      final url = Uri.parse('https://brouter.de/brouter?lonlats=$coordsString&profile=hiking-mountain&alternativeidx=0&format=geojson');
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final properties = features[0]['properties'];
          
          double totalDistance = double.tryParse(properties['track-length']?.toString() ?? '0') ?? 0;
          double totalDuration = double.tryParse(properties['total-time']?.toString() ?? '0') ?? 0;
          double elevationGain = double.tryParse(properties['filtered ascend']?.toString() ?? '0') ?? 0;
          
          final coords = features[0]['geometry']['coordinates'] as List<dynamic>;
          
          double maxElevation = 0;
          double sumElevation = 0;
          int eleCount = 0;

          final latLngList = coords.map((c) {
            final double lon = (c[0] as num).toDouble();
            final double lat = (c[1] as num).toDouble();
            if (c.length > 2) {
               final double ele = (c[2] as num).toDouble();
               if (ele > maxElevation) maxElevation = ele;
               sumElevation += ele;
               eleCount++;
            }
            return LatLng(lat, lon);
          }).toList();

          double avgElevation = eleCount > 0 ? sumElevation / eleCount : 0;

          return RouteInformation(
            distance: totalDistance,
            duration: totalDuration,
            coordinates: latLngList,
            elevationGain: elevationGain,
            maxElevation: maxElevation,
            averageElevation: avgElevation,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Valhalla public endpoint — ücretsiz, yaya/doğa modu
  static Future<RouteInformation?> _valhallaHiking(List<LatLng> waypoints) async {
    try {
      final url = Uri.parse('https://valhalla1.openstreetmap.de/route');
      final body = json.encode({
        'locations': waypoints.map((p) => {'lon': p.longitude, 'lat': p.latitude}).toList(),
        'costing': 'pedestrian',
        'costing_options': {
          'pedestrian': {
            'use_ferry': 0.0,
            'use_hills': 1.0,
            'walkway_factor': 0.8,
          }
        },
        'shape_format': 'geojson',
        'directions_options': {'units': 'km'},
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trip = data['trip'];
        if (trip == null) return null;

        final legs = trip['legs'] as List?;
        if (legs == null || legs.isEmpty) return null;

        double totalDist = 0;
        double totalTime = 0;
        final List<LatLng> allPoints = [];

        for (final leg in legs) {
          totalDist += ((leg['summary']?['length'] as num?) ?? 0) * 1000; // km→m
          totalTime += ((leg['summary']?['time'] as num?) ?? 0).toDouble();
          final shape = leg['shape'];
          if (shape is List) {
            for (final pt in shape) {
              allPoints.add(LatLng(
                (pt['lat'] as num).toDouble(),
                (pt['lon'] as num).toDouble(),
              ));
            }
          }
        }

        if (allPoints.isEmpty) return null;

        return RouteInformation(
          distance: totalDist,
          duration: totalTime,
          coordinates: allPoints,
        );
      }
    } catch (_) {}
    return null;
  }

  /// OSRM — foot routing (project-osrm.org public, hizli ve karali)
  static Future<RouteInformation?> _osrmFoot(List<LatLng> waypoints) async {
    try {
      final coords = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/$coords'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes == null || routes.isEmpty) return null;

        final route = routes[0];
        final double distanceM = ((route['distance'] as num?) ?? 0).toDouble();
        final double durationSec = ((route['duration'] as num?) ?? 0).toDouble();

        final geometry = route['geometry'];
        if (geometry == null) return null;

        final List<dynamic> coords2 = geometry['coordinates'] as List<dynamic>? ?? [];
        if (coords2.isEmpty) return null;

        double maxEle = 0;
        double sumEle = 0;
        int eleCount = 0;

        final latLngs = coords2.map((c) {
          final double lon = (c[0] as num).toDouble();
          final double lat = (c[1] as num).toDouble();
          if (c is List && c.length > 2) {
            final double ele = (c[2] as num).toDouble();
            if (ele > maxEle) maxEle = ele;
            sumEle += ele;
            eleCount++;
          }
          return LatLng(lat, lon);
        }).toList();

        return RouteInformation(
          distance: distanceM,
          duration: durationSec,
          coordinates: latLngs,
          maxElevation: maxEle,
          averageElevation: eleCount > 0 ? sumEle / eleCount : 0,
        );
      }
    } catch (_) {}
    return null;
  }
}
