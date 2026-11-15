import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tactical_styles.dart';

class WaterShelterScreen extends StatefulWidget {
  const WaterShelterScreen({super.key});

  @override
  State<WaterShelterScreen> createState() => _WaterShelterScreenState();
}

class _WaterShelterScreenState extends State<WaterShelterScreen> {
  static const String _cacheKey = 'free_water_shelter_cache_v1';

  bool _loading = true;
  bool _fromCache = false;
  LatLng _myPos = const LatLng(39.92, 32.85);
  List<Map<String, dynamic>> _places = [];
  String _filter = 'all'; // all | water | shelter | rescue

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 6));
      _myPos = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    try {
      final query = '''
[out:json][timeout:12];
(
  node["amenity"="drinking_water"](around:6000,${_myPos.latitude},${_myPos.longitude});
  node["natural"="spring"](around:6000,${_myPos.latitude},${_myPos.longitude});
  node["amenity"="shelter"](around:8000,${_myPos.latitude},${_myPos.longitude});
  node["tourism"="alpine_hut"](around:10000,${_myPos.latitude},${_myPos.longitude});
  node["tourism"="wilderness_hut"](around:10000,${_myPos.latitude},${_myPos.longitude});
  node["aeroway"="helipad"](around:10000,${_myPos.latitude},${_myPos.longitude});
  node["amenity"="police"](around:10000,${_myPos.latitude},${_myPos.longitude});
);
out center 50;
''';
      final res = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final List elems = data['elements'] ?? [];
        final parsed = <Map<String, dynamic>>[];

        for (final el in elems) {
          final lat = (el['lat'] as num?)?.toDouble();
          final lon = (el['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          final tags = Map<String, dynamic>.from(el['tags'] ?? {});

          String cat = 'water';
          String defaultTitle = 'Su Kaynağı / Çeşme';
          if (tags['amenity'] == 'shelter' ||
              tags['tourism'] == 'alpine_hut' ||
              tags['tourism'] == 'wilderness_hut') {
            cat = 'shelter';
            defaultTitle = 'Sığınak / Dağ Evi';
          } else if (tags['aeroway'] == 'helipad' || tags['amenity'] == 'police') {
            cat = 'rescue';
            defaultTitle = tags['aeroway'] == 'helipad' ? 'Helikopter İniş Alanı' : 'Güvenlik / Jandarma';
          }

          parsed.add({
            'name': (tags['name'] ?? defaultTitle).toString(),
            'cat': cat,
            'lat': lat,
            'lng': lon,
          });
        }

        _places = parsed;
        _fromCache = false;
        await prefs.setString(_cacheKey, jsonEncode(_places));
      } else {
        throw Exception('Overpass ${res.statusCode}');
      }
    } catch (_) {
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        try {
          final List cached = jsonDecode(raw);
          _places = cached.map((e) => Map<String, dynamic>.from(e)).toList();
          _fromCache = true;
        } catch (_) {}
      }
    }

    _sortPlaces();
    if (mounted) setState(() => _loading = false);
  }

  void _sortPlaces() {
    const calc = Distance();
    for (final p in _places) {
      final pt = LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
      p['dist'] = calc.as(LengthUnit.Meter, _myPos, pt);
      p['brg'] = _bearingTo(_myPos, pt);
    }
    _places.sort((a, b) => ((a['dist'] ?? 0) as num).compareTo((b['dist'] ?? 0) as num));
  }

  double _bearingTo(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  String _cardinal(double deg) {
    const dirs = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    return dirs[((deg + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _places
        : _places.where((p) => p['cat'] == _filter).toList();

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.water_drop_rounded, color: TacticalStyles.kSecondaryContainer, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'SU, SIĞINAK & İNİŞ NOKTALARI',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: TacticalStyles.kOnSurfaceVariant),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_fromCache)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.amber.withOpacity(0.15),
              child: const Text(
                'ÇEVRİMDIŞI ÖNBELLEK GÖSTERİLİYOR',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                _chip('Tümü', 'all'),
                const SizedBox(width: 6),
                _chip('Su/Çeşme', 'water'),
                const SizedBox(width: 6),
                _chip('Sığınak', 'shelter'),
                const SizedBox(width: 6),
                _chip('Helipad/Güv.', 'rescue'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TacticalStyles.kSecondaryContainer))
                : filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Bu bölgede (6-10 km yarıçap) kayıtlı su veya sığınak noktası bulunamadı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          final cat = p['cat'] ?? 'water';
                          final distM = ((p['dist'] ?? 0) as num).toDouble();
                          final brg = ((p['brg'] ?? 0) as num).toDouble();
                          final IconData icon = cat == 'shelter'
                              ? Icons.cabin_rounded
                              : (cat == 'rescue' ? Icons.local_hospital_rounded : Icons.water_drop_rounded);
                          final Color color = cat == 'shelter'
                              ? Colors.amber
                              : (cat == 'rescue' ? Colors.redAccent : TacticalStyles.kSecondaryContainer);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: TacticalStyles.glassCardDecoration(radius: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.15),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(
                                p['name'] ?? '',
                                style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${distM >= 1000 ? '${(distM / 1000).toStringAsFixed(2)} km' : '${distM.toInt()} m'} • ${brg.toInt()}° ${_cardinal(brg)}',
                                style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.directions_rounded, color: TacticalStyles.kTertiary),
                                onPressed: () {
                                  final url = Uri.parse('https://maps.google.com/?q=${p['lat']},${p['lng']}');
                                  launchUrl(url, mode: LaunchMode.externalApplication);
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String val) {
    final sel = _filter == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? TacticalStyles.kSecondaryContainer.withOpacity(0.2) : TacticalStyles.kSurfaceLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? TacticalStyles.kSecondaryContainer : TacticalStyles.kOutlineVariant),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sel ? TacticalStyles.kSecondaryContainer : TacticalStyles.kOnSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
