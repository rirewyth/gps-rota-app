import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'earthquake_service.dart';
import 'weather_service.dart';
import '../storage_helper.dart';

/// Çapraz platform arka plan monitör servisi.
///
/// - Android  → flutter_background_service ile gerçek foreground servisi (eski davranış)
/// - iOS      → Timer.periodic ile ana isolate'te güvenli çalışma
///              (flutter_background_service_ios ikinci motor açıp SIGSEGV ürettiği için kullanılmaz)
class BackgroundMonitorService {
  static const String notificationChannelId = 'rota_plus_foreground';
  static const int notificationId = 888;

  // ── iOS-only Timer alanları ───────────────────────────────────────────────
  static final FlutterLocalNotificationsPlugin _iosNotifications =
      FlutterLocalNotificationsPlugin();
  static Timer? _iosTimer;
  static DateTime? _lastWeatherCheck;
  static DateTime? _lastNotificationCheck;
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> initializeService() async {
    if (Platform.isIOS) {
      await _initIOS();
    } else {
      await _initAndroid();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  iOS — Timer tabanlı, ikinci Flutter motoru açılmaz
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _initIOS() async {
    const initDarwin = DarwinInitializationSettings();
    const initSettings = InitializationSettings(iOS: initDarwin);
    await _iosNotifications.initialize(initSettings);

    _iosTimer?.cancel();
    _iosTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _iosHeartbeat());

    debugPrint('BackgroundMonitorService: iOS Timer modu başlatıldı.');
  }

  static Future<void> _iosHeartbeat() async {
    try {
      // Bildirim Polling
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
                isGreaterThan: Timestamp.fromDate(_lastNotificationCheck!));
          }

          final snap =
              await query.orderBy('timestamp', descending: true).get();

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
              await _iosShowNotification(title, '$fromUserName $text');
            }
          } else {
            _lastNotificationCheck ??= DateTime.now();
          }
        }
      } catch (e) {
        debugPrint('iOS Bildirim Polling Hatası: $e');
      }

      // Erken Uyarı Sistemi
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
          final fullData = await WeatherService.getFullWeatherData(
              pos.latitude, pos.longitude);
          if (fullData != null) {
            if (fullData.current.isHazardous) {
              await _iosShowNotification('AŞIRI HAVA DURUMU UYARISI',
                  '${fullData.current.title}: ${fullData.current.description}');
            }
            for (var alert in fullData.advancedAlerts) {
              await _iosShowNotification(
                  'HAVA DURUMU: ${alert.title}', alert.message);
            }
          }
        }
      } catch (e) {
        debugPrint('iOS Hava hatası: $e');
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
          final double minMag = await StorageHelper.getEqMinMag();
          final double maxDist = await StorageHelper.getEqMaxDist();
          if (latest.mag >= minMag) {
            double dist = Geolocator.distanceBetween(
                    pos.latitude, pos.longitude, latest.lat, latest.lng) /
                1000;
            if (dist < maxDist) {
              double arrivalTime = dist / 3.5;
              await _iosShowCritical(
                  latest.mag, arrivalTime, latest.location, latest.lat, latest.lng);
            }
          }
        }
      } catch (e) {
        debugPrint('iOS Deprem hatası: $e');
      }
    } catch (e, stack) {
      debugPrint('iOS Heartbeat KRİTİK HATA: $e\n$stack');
    }
  }

  static Future<void> _iosShowNotification(String title, String body) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(),
    );
    await _iosNotifications.show(
        DateTime.now().millisecond, title, body, details);
  }

  static Future<void> _iosShowCritical(double mag, double seconds,
      String location, double lat, double lng) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.critical),
    );
    await _iosNotifications.show(
      999,
      '🚨 DEPREM UYARISI: $location',
      'M${mag.toStringAsFixed(1)} - ${seconds.toInt()} sn kaldı!',
      details,
      payload: 'critical_alert|$mag|$seconds|$location|$lat|$lng',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Android — flutter_background_service ile gerçek foreground servisi
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _initAndroid() async {
    await _requestBatteryOptimizationExemption();

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Rota+ Arka Plan Servisi',
      description: 'Uygulamanın arka planda çalışmasını sağlar.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel backgroundChannel =
        AndroidNotificationChannel(
      'background_notifications',
      'Rota+ Bildirimleri',
      description: 'Mesaj ve takip bildirimleri.',
      importance: Importance.max,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(backgroundChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Erken Uyarı Sistemi Aktif',
        initialNotificationContent: 'Deprem ve hava durumu taranıyor...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false, // iOS'ta hiçbir zaman başlatma
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  static Future<void> _requestBatteryOptimizationExemption() async {
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // iOS'ta bu callback çağrılmaz (autoStart: false)
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      DartPluginRegistrant.ensureInitialized();
    } catch (e) {
      debugPrint("DartPluginRegistrant Error: $e");
    }

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Firebase Background Init Error: $e");
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Rota+ Arka Plan Servisi',
      description: 'Uygulamanın arka planda çalışmasını sağlar.',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings initSettings =
        InitializationSettings(android: initAndroid);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final eqService = EarthquakeService();
    DateTime? lastWeatherCheck;
    DateTime? lastNotificationCheck;

    await Future.delayed(const Duration(seconds: 5));

    Timer.periodic(const Duration(seconds: 45), (timer) async {
      try {
        debugPrint("BackgroundMonitor: Heartbeat...");

        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "Erken Uyarı Sistemi Aktif",
              content: "Uygulama arka planda dinleniyor...",
            );
          }
        }

        // Bildirim Polling
        try {
          final String? uid = await StorageHelper.getUserUid();
          if (uid != null && uid.isNotEmpty) {
            Query query = FirebaseFirestore.instance
                .collection('notifications')
                .doc(uid)
                .collection('items')
                .where('isRead', isEqualTo: false);

            if (lastNotificationCheck != null) {
              query = query.where('timestamp',
                  isGreaterThan: Timestamp.fromDate(lastNotificationCheck!));
            }

            final snap =
                await query.orderBy('timestamp', descending: true).get();

            if (snap.docs.isNotEmpty) {
              lastNotificationCheck = DateTime.now();
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
                _showGenericNotification(
                    flutterLocalNotificationsPlugin, title, '$fromUserName $text');
              }
            } else {
              lastNotificationCheck ??= DateTime.now();
            }
          }
        } catch (e) {
          debugPrint("BackgroundMonitor: Notification Poll Error: $e");
        }

        // Erken Uyarı Sistemi
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
        } catch (e) {
          pos = await Geolocator.getLastKnownPosition();
        }

        if (pos != null) {
          // Hava Durumu
          try {
            if (lastWeatherCheck == null ||
                DateTime.now().difference(lastWeatherCheck!).inMinutes >= 30) {
              lastWeatherCheck = DateTime.now();
              final fullData = await WeatherService.getFullWeatherData(
                  pos.latitude, pos.longitude);
              if (fullData != null) {
                if (fullData.current.isHazardous) {
                  await _showGenericNotification(
                    flutterLocalNotificationsPlugin,
                    'AŞIRI HAVA DURUMU UYARISI',
                    '${fullData.current.title}: ${fullData.current.description}',
                  );
                }
                for (var alert in fullData.advancedAlerts) {
                  await _showGenericNotification(
                    flutterLocalNotificationsPlugin,
                    'HAVA DURUMU: ${alert.title}',
                    alert.message,
                  );
                }
              }
            }
          } catch (e) {
            debugPrint('Background weather check failed: $e');
          }

          // Deprem
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
                await _showCriticalNotification(
                  flutterLocalNotificationsPlugin,
                  latest.mag,
                  arrivalTime,
                  latest.location,
                  latest.lat,
                  latest.lng,
                );
              }
            }
          }
        }
      } catch (e, stack) {
        debugPrint("BackgroundMonitor: CRITICAL LOOP ERROR: $e\n$stack");
      }
    });
  }

  static Future<void> _showGenericNotification(
    FlutterLocalNotificationsPlugin notifications,
    String title,
    String body,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'background_notifications',
      'Arka Plan Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const details = NotificationDetails(android: androidDetails);
    await notifications.show(
        DateTime.now().millisecond, title, body, details);
  }

  static Future<void> _showCriticalNotification(
    FlutterLocalNotificationsPlugin notifications,
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
    final details = NotificationDetails(android: androidDetails);
    await notifications.show(
      999,
      '🚨 DEPREM UYARISI: $location',
      'M${mag.toStringAsFixed(1)} - ${seconds.toInt()} sn kaldı!',
      details,
      payload: 'critical_alert|$mag|$seconds|$location|$lat|$lng',
    );
  }
}
