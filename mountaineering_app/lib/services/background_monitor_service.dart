import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'earthquake_service.dart';
import 'weather_service.dart';
import '../storage_helper.dart';

/// iOS-safe background monitor service.
/// flutter_background_service paketini KULLANMAZ.
/// Bunun yerine ana isolate içinde Timer.periodic ile çalışır.
/// iOS'ta ikinci Flutter motoru açılmaz, dolayısıyla SIGSEGV çökmesi yaşanmaz.
class BackgroundMonitorService {
  static const String notificationChannelId = 'rota_plus_foreground';
  static const int notificationId = 888;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Timer? _heartbeatTimer;
  static DateTime? _lastWeatherCheck;
  static DateTime? _lastNotificationCheck;

  static Future<void> initializeService() async {
    // Android'de bildirim kanallarını oluştur
    if (!Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              notificationChannelId,
              'Rota+ Arka Plan Servisi',
              description: 'Uygulamanın arka planda çalışmasını sağlar.',
              importance: Importance.max,
            ),
          );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'background_notifications',
              'Rota+ Bildirimleri',
              description: 'Mesaj ve takip bildirimleri.',
              importance: Importance.max,
            ),
          );
    }

    // Bildirimleri başlat
    const initAndroid = AndroidInitializationSettings('ic_notification');
    const initDarwin = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
    );
    await _notifications.initialize(initSettings);

    // Periyodik kontrol başlat (45 saniyede bir, ana isolate'te)
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _runHeartbeat();
    });

    debugPrint('BackgroundMonitorService: Başlatıldı (iOS-safe Timer modu).');
  }

  static Future<void> stopService() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> _runHeartbeat() async {
    try {
      debugPrint('BackgroundMonitor: Heartbeat - sistemler kontrol ediliyor...');

      // 1. Bildirim Polling
      try {
        final String? uid = await StorageHelper.getUserUid();
        if (uid != null && uid.isNotEmpty) {
          Query query = FirebaseFirestore.instance
              .collection('notifications')
              .doc(uid)
              .collection('items')
              .where('isRead', isEqualTo: false);

          if (_lastNotificationCheck != null) {
            query = query.where('timestamp',
                isGreaterThan:
                    Timestamp.fromDate(_lastNotificationCheck!));
          }

          final snap = await query
              .orderBy('timestamp', descending: true)
              .get();

          if (snap.docs.isNotEmpty) {
            _lastNotificationCheck = DateTime.now();
            for (var doc in snap.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] ?? '';
              final fromUserName = data['fromUserName'] ?? 'Biri';
              final text = data['text'] ?? 'Yeni bir bildiriminiz var.';

              String title = 'Rota+ Bildirim';
              if (type == 'follow') title = 'Yeni Takip';
              else if (type == 'message') title = 'Yeni Mesaj';
              else if (type == 'like') title = 'Yeni Beğeni';
              else if (type == 'team_sos') title = '🚨 EKİP SOS!';

              await _showGenericNotification(title, '$fromUserName $text');
            }
          } else {
            _lastNotificationCheck ??= DateTime.now();
          }
        }
      } catch (e) {
        debugPrint('BackgroundMonitor: Bildirim Polling Hatası: $e');
      }

      // 2. Erken Uyarı Sistemi
      final enabled = await StorageHelper.getEarlyWarningEnabled();
      if (!enabled) {
        debugPrint('BackgroundMonitor: İzleme kapalı, atlanıyor.');
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.lowest,
            timeLimit: Duration(seconds: 5),
          ),
        ).timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('BackgroundMonitor: GPS hatası, son konum deneniyor... $e');
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        debugPrint('BackgroundMonitor: Konum alınamadı.');
        return;
      }

      // Hava Durumu Kontrolü (30 dakikada bir)
      try {
        if (_lastWeatherCheck == null ||
            DateTime.now()
                    .difference(_lastWeatherCheck!)
                    .inMinutes >=
                30) {
          _lastWeatherCheck = DateTime.now();
          final fullData = await WeatherService.getFullWeatherData(
              pos.latitude, pos.longitude);
          if (fullData != null) {
            if (fullData.current.isHazardous) {
              await _showGenericNotification(
                'AŞIRI HAVA DURUMU UYARISI',
                '${fullData.current.title}: ${fullData.current.description}',
              );
            }
            for (var alert in fullData.advancedAlerts) {
              await _showGenericNotification(
                'HAVA DURUMU: ${alert.title}',
                alert.message,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('BackgroundMonitor: Hava durumu hatası: $e');
      }

      // Deprem Kontrolü
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
          final double minMag = await StorageHelper.getEqMinMag();
          final double maxDist = await StorageHelper.getEqMaxDist();

          if (latest.mag >= minMag) {
            double dist = Geolocator.distanceBetween(
                    pos.latitude, pos.longitude, latest.lat, latest.lng) /
                1000;
            if (dist < maxDist) {
              double arrivalTime = dist / 3.5;
              await _showCriticalEqNotification(
                  latest.mag, arrivalTime, latest.location, latest.lat, latest.lng);
            }
          }
        }
      } catch (e) {
        debugPrint('BackgroundMonitor: Deprem kontrol hatası: $e');
      }
    } catch (e, stack) {
      debugPrint('BackgroundMonitor: KRİTİK DÖNGÜ HATASI: $e\n$stack');
    }
  }

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
    const details =
        NotificationDetails(android: androidDetails, iOS: darwinDetails);
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
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

    final details =
        NotificationDetails(android: androidDetails, iOS: darwinDetails);

    await _notifications.show(
      999,
      '🚨 DEPREM UYARISI: $location',
      'M${mag.toStringAsFixed(1)} - ${seconds.toInt()} sn kaldı!',
      details,
      payload: 'critical_alert|$mag|$seconds|$location|$lat|$lng',
    );
  }
}
