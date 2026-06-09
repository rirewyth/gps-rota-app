import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../storage_helper.dart';

class EarthquakeModel {
  final String date;
  final double mag;
  final double lat;
  final double lng;
  final String location;
  final double depth;

  EarthquakeModel({
    required this.date,
    required this.mag,
    required this.lat,
    required this.lng,
    required this.location,
    required this.depth,
  });

  factory EarthquakeModel.fromJson(Map<String, dynamic> json) {
    return EarthquakeModel(
      date: json['date_time'] ?? json['date'] ?? '',
      mag: (json['mag'] as num).toDouble(),
      lat: (json['geojson']['coordinates'][1] as num).toDouble(),
      lng: (json['geojson']['coordinates'][0] as num).toDouble(),
      location: json['title'] ?? json['lokasyon'] ?? '',
      depth: (json['depth'] as num).toDouble(),
    );
  }
}

class EarthquakeService {
  static final EarthquakeService _instance = EarthquakeService._internal();
  factory EarthquakeService() => _instance;
  EarthquakeService._internal() {
    _initNotifications();
  }

  static const String _apiUrl = 'https://api.orhanaydogdu.com.tr/deprem/kandilli/live';
  static const double _waveSpeed = 3.5;

  Timer? _monitorTimer;
  String? _lastNotifiedDate;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  Function(double magnitude, double secondsLeft, String location, double lat, double lng)? onWarning;


  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('ic_notification');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  Future<void> _showNotification(String? title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'earthquake_alerts',
      'Deprem Uyarıları',
      channelDescription: 'Kritik deprem bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Show over lock screen if possible
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await _notifications.show(
      DateTime.now().millisecond, 
      title, 
      body, 
      platformDetails
    );
  }

  Future<List<EarthquakeModel>> getRecentEarthquakes() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final List list = data['result'];
          return list.map((e) => EarthquakeModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print('Earthquake API Error: $e');
    }
    return [];
  }

  void startMonitoring({required Position currentPos, Function(double magnitude, double secondsLeft, String location, double lat, double lng)? onWarning}) {
    if (onWarning != null) this.onWarning = onWarning;
    _monitorTimer?.cancel();
    
    _monitorTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final quakes = await getRecentEarthquakes();
      final aprsQuakes = await getAprsTacticalFeed();
      final allQuakes = [...quakes, ...aprsQuakes];
      
      if (allQuakes.isNotEmpty) {
        final latest = allQuakes.first;
        
        if (_lastNotifiedDate == latest.date) return;
        _lastNotifiedDate = latest.date;

        // 1. General Notification (Optional)
        final bool generalEnabled = await StorageHelper.getEqGeneralNotif();
        if (generalEnabled) {
           _showNotification('Yeni Deprem Verisi', '${latest.location} - M:${latest.mag}');
        }

        // 2. Early Warning (Critical)
        final double minMag = await StorageHelper.getEqMinMag();
        final double maxDist = await StorageHelper.getEqMaxDist();

        if (latest.mag >= minMag) {
          double dist = Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, latest.lat, latest.lng) / 1000;
          double arrivalTime = dist / _waveSpeed;

          if (dist < maxDist) {
             if (!generalEnabled) {
               _showNotification('Kritik Uyarı', 'M${latest.mag.toStringAsFixed(1)}, ${latest.location}');
             }
             onWarning?.call(latest.mag, arrivalTime, latest.location, latest.lat, latest.lng);
          }
        }
      }
    });
  }

  Future<List<EarthquakeModel>> getAprsTacticalFeed() async {
    try {
      final apiKey = await StorageHelper.getAprsApiKey();
      final url = 'https://api.aprs.fi/api/get?name=AFAD,KANDILLI&what=loc&apikey=$apiKey&format=json';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'ok' && data['entries'] != null) {
          final List entries = data['entries'];
          return entries.map((e) {
            String comment = e['comment'] ?? '';
            double mag = 0.0;
            final magMatch = RegExp(r'(?:M|MAG)\s*(\d+\.\d+)').firstMatch(comment.toUpperCase());
            if (magMatch != null) mag = double.tryParse(magMatch.group(1) ?? '0.0') ?? 0.0;

            return EarthquakeModel(
              date: DateTime.fromMillisecondsSinceEpoch(int.parse(e['time']) * 1000).toString(),
              mag: mag,
              lat: double.parse(e['lat']),
              lng: double.parse(e['lng']),
              location: '[APRS] ${e['name']}: $comment',
              depth: 0.0,
            );
          }).toList();
        }
      }
    } catch (e) { print('APRS Error: $e'); }
    return [];
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
  }
}
