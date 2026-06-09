import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/peak_model.dart';
import 'package:flutter/foundation.dart';

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  /// Verilen merkez etrafındaki [radius] metrelik alan içerisindeki dağ/tepeleri getirir.
  static Future<List<PeakModel>> getNearbyPeaks(double lat, double lon, {double radius = 50000}) async {
    // 50000 = 50 km yarıçap
    final query = '''
      [out:json][timeout:25];
      node["natural"="peak"](around:$radius,$lat,$lon);
      out body;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: {'data': query},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'] ?? [];
        
        List<PeakModel> peaks = elements
            .where((e) => e['tags'] != null && e['tags']['name'] != null) // Sadece ismi olanları al
            .map((e) => PeakModel.fromJson(e))
            .toList();
            
        // Rakıma göre sırala (en yüksekler önce)
        peaks.sort((a, b) => b.elevation.compareTo(a.elevation));
        
        // Çok fazla sonuç varsa sadece en yüksek 100 tanesini gösterelim (ekran dolmasın)
        if (peaks.length > 100) {
          peaks = peaks.sublist(0, 100);
        }
        
        return peaks;
      } else {
        debugPrint('Overpass API Hatası: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Overpass İstek Hatası: $e');
      return [];
    }
  }
}
