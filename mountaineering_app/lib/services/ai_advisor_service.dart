import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../data/mountain_database.dart';
import '../database_helper.dart';

class AIAdvisorService {
  /// Mevcut konuma en yakın POI'yi bulur
  static POI? _findNearestPOI(double lat, double lng) {
    POI? nearest;
    double minDistance = double.infinity;

    for (var poi in MountainDB.pointsOfInterest) {
      double distance = Geolocator.distanceBetween(lat, lng, poi.lat, poi.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = poi;
      }
    }
    
    // Eğer POI 2km'den daha yakınsa döndür
    return minDistance < 2000 ? nearest : null;
  }

  /// Koordinatlara ve rotaya göre bir "Yapay Zeka Notu" oluşturur
  static Future<String> generateInsight({
    required double lat,
    required double lng,
    required double speed,
    Map<String, dynamic>? activeRoute,
  }) async {
    String insight = "";
    
    // 1. En yakın POI'yi bul
    final nearestPoi = _findNearestPOI(lat, lng);
    
    // 2. Rota durumunu kontrol et
    bool isOffRoute = false;
    double rotadanUzaklik = 0;
    
    if (activeRoute != null && activeRoute['noktalar'] != null) {
      final noktalar = activeRoute['noktalar'] as List;
      if (noktalar.isNotEmpty) {
        double minDistance = double.infinity;
        for (var n in noktalar) {
          double d = Geolocator.distanceBetween(
            lat, lng,
            (n['lat'] as num).toDouble(), (n['lng'] as num).toDouble()
          );
          if (d < minDistance) minDistance = d;
        }
        rotadanUzaklik = minDistance;
        isOffRoute = minDistance > 80; // 80 metre sapma
      }
    }

    // 3. Senaryoya göre metin üret
    if (isOffRoute) {
      insight = "Kullanici rotadan ${rotadanUzaklik.toInt()}m sapmis durumda. ";
      
      if (nearestPoi != null) {
        double poiDist = Geolocator.distanceBetween(lat, lng, nearestPoi.lat, nearestPoi.lng);
        if (poiDist < 500) {
          insight += "Su an '${nearestPoi.name}' (${nearestPoi.description}) yakininda olabilir.";
        } else {
          insight += "Yakinindaki '${nearestPoi.name}' noktasina yonelmis olabilir.";
        }
      } else {
        insight += "Kaybolmus veya alternatif bir patika kullaniyor olabilir.";
      }
    } else {
      // Rotada ilerliyor
      if (speed < 0.5) { // 0.5 m/s = ~1.8 km/h (Mola veriyor gibi)
        if (nearestPoi != null) {
          insight = "Su an '${nearestPoi.name}' (${nearestPoi.description}) noktasinda mola veriyor olabilir.";
        } else {
          insight = "Su an rotada mola veriyor veya kamp kuruyor olabilir.";
        }
      } else {
        insight = "Rotada normal hizda seyir halinde.";
        if (nearestPoi != null) {
          insight += " Bir sonraki durak '${nearestPoi.name}' olabilir.";
        }
      }
    }

    return insight;
  }

  /// Rotadan sapan kullanıcı için güvenli geri dönüş tavsiyesi ve hedef nokta döner
  static Map<String, dynamic>? getSafeReturnPath({
    required double lat,
    required double lng,
    required double currentAlt,
    required List<dynamic> routePoints,
  }) {
    if (routePoints.isEmpty) return null;

    double minDistance = double.infinity;
    int nearestIndex = -1;

    for (int i = 0; i < routePoints.length; i++) {
      final p = routePoints[i];
      double d = Geolocator.distanceBetween(
        lat, lng, 
        (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()
      );
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }

    if (nearestIndex == -1) return null;

    final targetPoint = routePoints[nearestIndex];
    final targetLat = (targetPoint['lat'] as num).toDouble();
    final targetLng = (targetPoint['lng'] as num).toDouble();
    final targetAlt = (targetPoint['alt'] as num?)?.toDouble() ?? currentAlt;

    // Basit eğim analizi
    double altDiff = targetAlt - currentAlt;
    String advice = "Rotaya en kısa dönüş yolu: ${minDistance.toInt()}m.";
    String icon = "explore";

    if (altDiff > 30) {
      advice = "DİKKAT: Dik tırmanış (+${altDiff.toInt()}m). Enerji tasarrufu için zikzak (Switchback) yapın.";
      icon = "trending_up";
    } else if (altDiff < -30) {
      advice = "DİKKAT: Dik iniş (${altDiff.toInt()}m). Kayma riskine karşı yan basarak (Side-stepping) ilerleyin.";
      icon = "trending_down";
    } else {
      advice = "Zemin düz görünüyor. Doğrudan rotaya yönelebilirsiniz (${minDistance.toInt()}m).";
      icon = "terrain";
    }

    return {
      'targetLat': targetLat,
      'targetLng': targetLng,
      'advice': advice,
      'icon': icon,
      'distance': minDistance,
    };
  }
}
