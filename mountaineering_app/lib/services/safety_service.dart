import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'radar_service.dart';

class SafetyService {
  static StreamSubscription<List<TeammateLocation>>? _geofenceSubscription;
  static bool _isEnabled = false;
  static double _thresholdMeters = 100.0;
  
  static final StreamController<String> _alertController = StreamController<String>.broadcast();
  static Stream<String> get alerts => _alertController.stream;

  static void startMonitoring({double threshold = 100.0}) {
    if (_isEnabled) return;
    _isEnabled = true;
    _thresholdMeters = threshold;

    _geofenceSubscription = RadarService.getTeammateLocations().listen((teammates) async {
      if (teammates.isEmpty) return;

      // Kullanıcının kendi durumunu kontrol et
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      
      final bool isUserRecording = currentUserDoc.data()?['is_recording'] ?? false;
      
      // Eğer kullanıcı tırmanışta (kayıtta) değilse, mesafe uyarısı verme
      if (!isUserRecording) return;

      final currentPos = await Geolocator.getCurrentPosition();
      
      for (var teammate in teammates) {
        // Sadece aktif olarak rota kaydeden (seferde olan) kişileri takip et
        if (!teammate.isRecording) continue;

        double distance = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          teammate.lat,
          teammate.lng,
        );

        if (distance > _thresholdMeters) {
          _triggerAlert(teammate.name, distance);
        }
      }
    });
  }

  static void stopMonitoring() {
    _isEnabled = false;
    _geofenceSubscription?.cancel();
  }

  static void _triggerAlert(String name, double distance) async {
    final message = 'DİKKAT: $name ile mesafe ${distance.toInt()}m oldu!';
    _alertController.add(message);
    
    // Titreşimli uyarı (Mors alfabesine benzer bir desen)
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
  }
}
