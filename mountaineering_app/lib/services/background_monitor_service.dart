import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'earthquake_service.dart';
import 'weather_service.dart';
import '../storage_helper.dart';
import '../firebase_options.dart';

// ─── Android Workmanager callback (top-level, vm:entry-point zorunlu) ────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await BackgroundMonitorService._runCheck();
    } catch (e) {
      debugPrint('Workmanager task error: $e');
    }
    return Future.value(true);
  });
}
// ─────────────────────────────────────────────────────────────────────────────

/// Çapraz platform arka plan monitör servisi.
///
/// - Android  → Workmanager ile periyodik görev (uygulama kapalıyken de çalışır)
/// - iOS      → Timer.periodic ile ana isolate'te güvenli çalışma
///              (flutter_background_service_ios ikinci motor açıp SIGSEGV ürettiğinden KULLANILMAZ)
class BackgroundMonitorService {
  static const String _taskName = 'rotaplus_monitor';
  static const String _taskTag  = 'rotaplus_bg';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // iOS-only timer
  static Timer? _iosTimer;
  static DateTime? _lastWeatherCheck;
  static DateTime? _lastNotificationCheck;

  // ── Başlatma ───────────────────────────────────────────────────────────────

  static Future<void> initializeService() async {
    await _initNotifications();

    if (Platform.isAndroid) {
      await _initAndroid();
    } else {
      await _initIOS();
    }
  }

  static Future<void> _initNotifications() async {
    const initAndroid = AndroidInitializationSettings('ic_notification');
    const initDarwin = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
    );
    await _notifications.initialize(initSettings);

    // Android bildirim kanalları
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'background_notifications',
              'Rota+ Bildirimleri',
              importance: Importance.max,
            ),
          );
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'critical_earthquake_channel',
              'KRİTİK DEPREM UYARISI',
              importance: Importance.max,
            ),
          );
    }
  }

  // ── Android: Workmanager ───────────────────────────────────────────────────

  static Future<void> _initAndroid() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskTag,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    debugPrint('BackgroundMonitorService: Android Workmanager başlatıldı.');
  }

  // ── iOS: Timer ────────────────────────────────────────────────────────────

  static Future<void> _initIOS() async {
    _iosTimer?.cancel();
    _iosTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _runCheck(),
    );
    debugPrint('BackgroundMonitorService: iOS Timer modu başlatıldı.');
  }

  static Future<void> stopService() async {
    _iosTimer?.cancel();
    _iosTimer = null;
    if (Platform.isAndroid) {
      await Workmanager().cancelByTag(_taskTag);
    }
  }

  // ── Ortak kontrol mantığı (hem Android Workmanager hem iOS Timer çağırır) ─

  static Future<void> _runCheck() async {
    try {
      // 1. Bildirim Polling
      final String? uid = await StorageHelper.getUserUid();
      if (uid != null && uid.isNotEmpty) {
        try {
          Query query = FirebaseFirestore.instance
              .collection('notifications')
              .doc(uid)
              .collection('items')
              .where('isRead', isEqualTo: false);

          if (_lastNotificationCheck != null) {
            query = query.where('timestamp',
                isGreaterThan: Timestamp.fromDate(_lastNotificationCheck!));
          }

          final snap = await query
              .orderBy('timestamp', descending: true)
              .get()
              .timeout(const Duration(seconds: 8));

          if (snap.docs.isNotEmpty) {
            _lastNotificationCheck = DateTime.now();
            for (var doc in snap.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] ?? '';
              final from = data['fromUserName'] ?? 'Biri';
              final text = data['text'] ?? 'Yeni bir bildiriminiz var.';
              String title = 'Rota+ Bildirim';
              if (type == 'follow') title = 'Yeni Takip';
              else if (type == 'message') title = 'Yeni Mesaj';
              else if (type == 'like') title = 'Yeni Beğeni';
              else if (type == 'team_sos') title = '🚨 EKİP SOS!';
              await _showGenericNotification(title, '$from $text');
            }
          } else {
            _lastNotificationCheck ??= DateTime.now();
          }
        } catch (e) {
          debugPrint('Bildirim polling hatası: $e');
        }
      }

      // 2. Erken Uyarı Sistemi
      final enabled = await StorageHelper.getEarlyWarningEnabled();
      if (!enabled) return;

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.lowest,
            timeLimit: Duration(seconds: 5),
          ),
        ).timeout(const Duration(seconds: 6));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return;

      // Hava Durumu (30 dakikada bir)
      try {
        if (_lastWeatherCheck == null ||
            DateTime.now().difference(_lastWeatherCheck!).inMinutes >= 30) {
          _lastWeatherCheck = DateTime.now();
          final data = await WeatherService.getFullWeatherData(
              pos.latitude, pos.longitude);
          if (data != null) {
            if (data.current.isHazardous) {
              await _showGenericNotification('AŞIRI HAVA DURUMU UYARISI',
                  '${data.current.title}: ${data.current.description}');
            }
            for (var alert in data.advancedAlerts) {
              await _showGenericNotification(
                  'HAVA DURUMU: ${alert.title}', alert.message);
            }
          }
        }
      } catch (e) {
        debugPrint('Hava durumu kontrol hatası: $e');
      }

      // Deprem
      try {
        final eqService = EarthquakeService();
        final quakes = await eqService
            .getRecentEarthquakes()
            .timeout(const Duration(seconds: 10), onTimeout: () => []);
        final aprs = await eqService
            .getAprsTacticalFeed()
            .timeout(const Duration(seconds: 10), onTimeout: () => []);
        final all = [...quakes, ...aprs];

        if (all.isNotEmpty) {
          final latest = all.first;
          final minMag = await StorageHelper.getEqMinMag();
          final maxDist = await StorageHelper.getEqMaxDist();
          if (latest.mag >= minMag) {
            final dist = Geolocator.distanceBetween(
                    pos.latitude, pos.longitude, latest.lat, latest.lng) /
                1000;
            if (dist < maxDist) {
              await _showCriticalEqNotification(
                  latest.mag, dist / 3.5, latest.location, latest.lat, latest.lng);
            }
          }
        }
      } catch (e) {
        debugPrint('Deprem kontrol hatası: $e');
      }
    } catch (e, stack) {
      debugPrint('BackgroundMonitor _runCheck KRİTİK HATA: $e\n$stack');
    }
  }

  // ── Bildirim yardımcıları ─────────────────────────────────────────────────

  static Future<void> _showGenericNotification(
      String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'background_notifications',
      'Rota+ Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
        android: androidDetails, iOS: darwinDetails);
    await _notifications.show(
        DateTime.now().millisecond, title, body, details);
  }

  static Future<void> _showCriticalEqNotification(
    double mag,
    double seconds,
    String location,
    double lat,
    double lng,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'critical_earthquake_channel',
      'KRİTİK DEPREM UYARISI',
      channelDescription: 'Hayat kurtaran acil durum bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true,
      styleInformation: BigTextStyleInformation(
        'M${mag.toStringAsFixed(1)} şiddetinde deprem! ${seconds.toInt()} saniye içinde dalgalar ulaşabilir.',
        contentTitle: '🚨 DEPREM UYARISI: $location',
      ),
    );
    const darwinDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.critical,
    );
    final details = NotificationDetails(
        android: androidDetails, iOS: darwinDetails);
    await _notifications.show(
      999,
      '🚨 DEPREM UYARISI: $location',
      'M${mag.toStringAsFixed(1)} - ${seconds.toInt()} sn kaldı!',
      details,
      payload: 'critical_alert|$mag|$seconds|$location|$lat|$lng',
    );
  }
}
