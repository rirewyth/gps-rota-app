import 'dart:async';
import 'dart:convert';
import 'package:sensors_plus/sensors_plus.dart';
import '../storage_helper.dart';

class BarometerService {
  static final BarometerService _instance = BarometerService._internal();
  factory BarometerService() => _instance;
  BarometerService._internal();

  StreamSubscription? _pressureSub;
  double _currentPressure = 0.0;
  
  // Callback for warnings
  Function(String title, String desc)? onStormWarning;

  double get currentPressure => _currentPressure;

  void startMonitoring() {
    _pressureSub?.cancel();
    try {
      _pressureSub = barometerEventStream().listen((BarometerEvent event) {
        _currentPressure = event.pressure;
        _checkPressureTrend(event.pressure);
      }, onError: (e) {
        print("Barometer Error: $e");
      });
    } catch(e) {
      print("Barometer Stream Error: $e");
    }
  }

  void stopMonitoring() {
    _pressureSub?.cancel();
  }

  Future<void> _checkPressureTrend(double current) async {
    final now = DateTime.now();
    final historyStr = await StorageHelper.getPressureHistory();
    List<dynamic> history = historyStr != null ? json.decode(historyStr) : [];

    // Add current reading: [timestamp, value]
    history.add([now.millisecondsSinceEpoch, current]);

    // Keep only last 24 hours
    final oneDayAgo = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    history.removeWhere((item) => item[0] < oneDayAgo);

    // Save back
    await StorageHelper.setPressureHistory(json.encode(history));

    // Check for 3h drop
    final threeHoursAgo = now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch;
    // Find reading closest to 3 hours ago
    if (history.length > 5) { // Minimum data points to check trend
      final oldReading = history.firstWhere((item) => item[0] >= threeHoursAgo, orElse: () => null);

      if (oldReading != null) {
        double diff = current - oldReading[1];
        if (diff <= -3.0) { // 3 hPa drop in 3 hours is a classic storm warning
          onStormWarning?.call(
            'FIRTINA YAKLAŞIYOR!', 
            'Basınç son 3 saatte ${diff.toStringAsFixed(1)} hPa düştü. Hava bozabilir, dikkatli olun!'
          );
        }
      }
    }
  }
}
