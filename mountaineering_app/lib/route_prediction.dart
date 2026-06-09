import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';

Future<String> calculatePredictedRoute() async {
  // Veritabanından son 2 konumu al
  final locations = await DatabaseHelper.instance.getLastLocations(2);

  if (locations.length < 2) {
    return "Yeterli veri yok (Bilinmiyor)";
  }

  // index 0: En son konum, index 1: Bir önceki konum
  final current = locations[0];
  final previous = locations[1];

  double lat1 = (previous['latitude'] as num).toDouble();
  double lon1 = (previous['longitude'] as num).toDouble();
  double lat2 = (current['latitude'] as num).toDouble();
  double lon2 = (current['longitude'] as num).toDouble();

  // İki nokta arasındaki yörünge/yönü hesapla
  double bearing = Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  
  if (bearing < 0) {
    bearing += 360.0;
  }

  return _getDirectionFromBearing(bearing);
}

String _getDirectionFromBearing(double bearing) {
  if (bearing >= 337.5 || bearing < 22.5) return "Kuzey";
  if (bearing >= 22.5 && bearing < 67.5) return "Kuzeydoğu";
  if (bearing >= 67.5 && bearing < 112.5) return "Doğu";
  if (bearing >= 112.5 && bearing < 157.5) return "Güneydoğu";
  if (bearing >= 157.5 && bearing < 202.5) return "Güney";
  if (bearing >= 202.5 && bearing < 247.5) return "Güneybatı";
  if (bearing >= 247.5 && bearing < 292.5) return "Batı";
  if (bearing >= 292.5 && bearing < 337.5) return "Kuzeybatı";
  return "Bilinmiyor";
}
