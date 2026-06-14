import 'dart:async';
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

class BackgroundMonitorService {
  static const String notificationChannelId = 'rota_plus_foreground';
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    // Request battery optimization exemption first
    await _requestBatteryOptimizationExemption();

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Rota+ Arka Plan Servisi',
      description: 'Uygulamanın arka planda çalışmasını sağlar.',
      importance: Importance.max, // Increased importance
    );

    const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
      'background_notifications',
      'Rota+ Bildirimleri',
      description: 'Mesaj ve takip bildirimleri.',
      importance: Importance.max,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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
        // Android 14 requirements
        foregroundServiceTypes: [
          AndroidForegroundType.specialUse,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
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
    
    // Set as foreground immediately to prevent OS from killing it
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
    
    // Ensure Firebase is initialized for this isolate
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Firebase Background Init Error: $e");
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // BOOT_COMPLETED veya arkada başlatıldığında kanalın var olduğundan emin ol!
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Rota+ Arka Plan Servisi',
      description: 'Uygulamanın arka planda çalışmasını sağlar.',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('ic_notification');
    const InitializationSettings initSettings = InitializationSettings(android: initAndroid);
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

    // Initialize Earthquake Service in Background
    final eqService = EarthquakeService();
    
    // Listen for Firestore notifications in background
    // FCM will handle notifications, so no Firestore listener here.

    DateTime? lastWeatherCheck;
    DateTime? lastNotificationCheck;

    // Give the isolate some time to breathe before starting the heavy periodic loop
    await Future.delayed(const Duration(seconds: 5));

    // Periodically update foreground notification or check status
    // Increased interval to 45s to reduce pressure on background isolate
    Timer.periodic(const Duration(seconds: 45), (timer) async {
      try {
        debugPrint("BackgroundMonitor: Heartbeat - Checking systems...");
        
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "Erken Uyarı Sistemi Aktif",
              content: "Uygulama arka planda dinleniyor...",
            );
          }
        }

        // 1. ROBUST NOTIFICATION POLLING (Bypasses Doze Mode WebSocket Freezes)
        try {
          final String? uid = await StorageHelper.getUserUid();
          if (uid != null && uid.isNotEmpty) {
            Query query = FirebaseFirestore.instance
                .collection('notifications')
                .doc(uid)
                .collection('items')
                .where('isRead', isEqualTo: false);
            
            if (lastNotificationCheck != null) {
              query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(lastNotificationCheck!));
            }

            // Using .get() instead of .snapshots() to force an active network request 
            // which works better when Android Doze mode briefly opens maintenance windows.
            final snap = await query.orderBy('timestamp', descending: true).get();
            
            if (snap.docs.isNotEmpty) {
              lastNotificationCheck = DateTime.now(); // Update checkpoint
              
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

                _showGenericNotification(flutterLocalNotificationsPlugin, title, '$fromUserName $text');
              }
            } else if (lastNotificationCheck == null) {
              lastNotificationCheck = DateTime.now(); // Init
            }
          }
        } catch (e) {
          debugPrint("BackgroundMonitor: Notification Poll Error: $e");
        }

        // 2. EARLY WARNING SYSTEM (GPS & Weather/EQ)
        // Check if monitoring should be active
        final enabled = await StorageHelper.getEarlyWarningEnabled();
        if (!enabled) {
           debugPrint("BackgroundMonitor: Monitoring disabled in settings.");
           return;
        }

        Position? pos;
        try {
          // Use very low accuracy and short timeout for background heartbeat
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.lowest,
              timeLimit: Duration(seconds: 5),
            )
          ).timeout(const Duration(seconds: 6));
        } catch (e) {
          debugPrint("BackgroundMonitor: GPS Error, trying last known... $e");
          pos = await Geolocator.getLastKnownPosition();
        }

        if (pos != null) {
          debugPrint("BackgroundMonitor: Position obtained. Fetching EQ data...");
          
          // --- WEATHER CHECK ---
          try {
            if (lastWeatherCheck == null || DateTime.now().difference(lastWeatherCheck!).inMinutes >= 30) {
              lastWeatherCheck = DateTime.now();
              final fullData = await WeatherService.getFullWeatherData(pos.latitude, pos.longitude);
              if (fullData != null) {
                // Main hazard
                if (fullData.current.isHazardous) {
                  debugPrint("BackgroundMonitor: CRITICAL WEATHER DETECTED! Showing notification.");
                  await _showGenericNotification(
                    flutterLocalNotificationsPlugin,
                    'AŞIRI HAVA DURUMU UYARISI',
                    '${fullData.current.title}: ${fullData.current.description}',
                  );
                }
                // Advanced alerts (Trend analysis: Snow, Frost, CB, etc.)
                for (var alert in fullData.advancedAlerts) {
                  debugPrint("BackgroundMonitor: ADVANCED WEATHER ALERT! ${alert.title}");
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
          // ---------------------

          final quakes = await eqService.getRecentEarthquakes().timeout(const Duration(seconds: 10), onTimeout: () => []);
          final aprs = await eqService.getAprsTacticalFeed().timeout(const Duration(seconds: 10), onTimeout: () => []);
          final all = [...quakes, ...aprs];

          if (all.isNotEmpty) {
            final latest = all.first;
            final double minMag = await StorageHelper.getEqMinMag();
            final double maxDist = await StorageHelper.getEqMaxDist();

            if (latest.mag >= minMag) {
              double dist = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, latest.lat, latest.lng
              ) / 1000;
              
              if (dist < maxDist) {
                double arrivalTime = dist / 3.5;
                debugPrint("BackgroundMonitor: CRITICAL EQ DETECTED! Showing notification.");
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
        } else {
          debugPrint("BackgroundMonitor: Could not obtain location.");
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
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
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
    
    // We pass data in the payload to handle navigation if app is opened from notification
    await notifications.show(
      999,
      '🚨 DEPREM UYARISI: $location',
      'M${mag.toStringAsFixed(1)} - ${seconds.toInt()} sn kaldı!',
      details,
      payload: 'critical_alert|$mag|$seconds|$location|$lat|$lng',
    );
  }
}
