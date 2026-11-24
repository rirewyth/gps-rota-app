import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_state.dart';
import '../services/cloud_sync_service.dart';
import '../storage_helper.dart';
import '../services/background_sms_service.dart';
import '../database_helper.dart';
import '../data/mountain_database.dart';
import '../services/tactical_styles.dart';

import '../services/morse_service.dart';
import 'map_screen.dart';
import 'survival_guide_screen.dart';
import 'dm_list_screen.dart';
import 'ar_compass_screen.dart';
import 'mesh_network_screen.dart';
import 'avalanche_module_screen.dart';
import '../services/weather_service.dart';
import '../services/radar_service.dart';
import '../services/offline_map_manager.dart';
import 'users_screen.dart';
import 'first_aid_screen.dart';
import 'emergency_id_card_screen.dart';
import 'incident_report_screen.dart';
import 'notification_screen.dart';
import 'weather_screen.dart';
import 'earthquake_module_screen.dart';
import 'earthquake_feed_screen.dart';
import 'peak_ar_screen.dart';
import 'package:mountaineering_app/services/earthquake_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/night_ops_service.dart';
import '../services/premium_service.dart';
import '../services/safety_service.dart';
import '../services/voice_sos_service.dart';
import '../services/ai_advisor_service.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import '../services/ad_service.dart';

const Color kOrange = TacticalStyles.kPrimaryContainer;
const Color kBackground = TacticalStyles.kSurface;
const Color kCardBg = TacticalStyles.kSurfaceLow;
const Color kGreen = TacticalStyles.kTertiary;

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({Key? key}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSosActive = false;
  bool _isSending = false;
  String _sosStatusMessage = '';
  String _userName = '';
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  int _countdown = 0;
  Timer? _countdownTimer;
  int _batteryLevel = 100;
  bool _isCharging = false;
  StreamSubscription<CompassEvent>? _compassStream;
  double? _heading;
  fm.MapController _mapController = fm.MapController();
  mbx.MapboxMap? _mapboxMap;
  mbx.PolylineAnnotationManager? _polylineAnnotationManager;
  mbx.CircleAnnotationManager? _pointAnnotationManager;
  bool _mapReady = false;
  Map<String, dynamic>? _aktifRota;
  List<ll.LatLng> _aktifRotaPoints = [];

  int _inactivitySeconds = 0;
  Timer? _inactivityCheckTimer;
  bool _showInactivityWarning = false;
  bool _inactivitySensorEnabled = true;
  Timer? _weatherTimer;

  bool _isOffRoute = false;
  bool _isSurvivalMode = false;
  bool _isPremium = false;
  double _distanceToRoute = 0;
  double _altitudeGoal = 3917;
  WeatherAlertInfo? _weatherAlert;
  bool _extremePowerSaving = false;


  bool _isTorchOn = false;
  bool _isStrobeOn = false;
  bool _isSosFlashOn = false;
  Timer? _strobeTimer;
  bool _fireWarningShown = false;

  // Radar variables
  List<TeammateLocation> _teammates = [];
  StreamSubscription<List<TeammateLocation>>? _radarStream;

  Position? _oncekiKonum;
  bool _isTacticalMap = false;

  Map<String, dynamic>? _safeReturnPath;
  StreamSubscription<String>? _safetyAlertsStream;
  bool _isMapCentered = false;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  Timer? _presenceTimer;
  Timer? _activeUserTimer;
  int _activeUserCount = 1;
  final int _nearbyMeshCount = 0;

  void _updatePresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'last_active': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Presence update error: $e");
      }
    }
  }

  Future<void> _fetchActiveUsers() async {
    try {
      final activeWindow = DateTime.now().subtract(const Duration(minutes: 5));
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('last_active', isGreaterThanOrEqualTo: Timestamp.fromDate(activeWindow))
          .count()
          .get();
      if (mounted) {
        setState(() {
          _activeUserCount = snapshot.count ?? 1;
        });
      }
    } catch (e) {
      debugPrint("Active users fetch error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _loadSettings();
    _startGps();
    _startCompass();
    _aktifRotayiYukle();
    _initBattery();
    _startInactivityTimer();
    _startRadar();
    _initSafetyServices();
    _loadBannerAd();
    DatabaseHelper.rotaUpdateNotifier.addListener(_aktifRotayiYukle);
    _checkAffiliation();
    _initFCMToken();

    _updatePresence();
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) => _updatePresence());
    
    _fetchActiveUsers();
    _activeUserTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchActiveUsers());
  }

  Future<void> _initFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
        }, SetOptions(merge: true));
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("FCM Token Error: $e");
    }
  }

  void _checkAffiliation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('affiliationType')) {
          // Gerekli veriyi iste
          if (!mounted) return;
          Future.delayed(const Duration(seconds: 2), () {
            _showAffiliationDialog(user.uid);
          });
        }
      }
    } catch (e) {
      debugPrint("Affiliation check failed: $e");
    }
  }

  void _showAffiliationDialog(String uid) {
    String selectedType = 'Bireysel';
    final TextEditingController nameCtrl = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141414),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFF6B00), width: 1)),
              title: const Text('Kurum / Kuruluş Bilgisi', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Değerli sporcularımız, Dağcılık Kulübüne veya Spor Kulübüne bağlı iseniz Kulüp sekmesinden bağlı olduğunuz kulüp isminizi, Arama Kurtarma Derneğine bağlı iseniz Dernek sekmesinden bağlı olduğunuz Dernek isminizi, Bağlı olduğunuz kurum kuruluş yok ise Bireysel seçerek kaydetmeyi unutmayınız.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        dropdownColor: Colors.black,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: ['Bireysel', 'Spor Kulübü', 'Dernek'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedType = val);
                        },
                      ),
                    ),
                  ),
                  if (selectedType != 'Bireysel') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Kurum / Kulüp Adı',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6B00))),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                  onPressed: () async {
                    if (selectedType != 'Bireysel' && nameCtrl.text.trim().isEmpty) return;
                    await FirebaseFirestore.instance.collection('users').doc(uid).set({
                      'affiliationType': selectedType,
                      'affiliationName': selectedType == 'Bireysel' ? '' : nameCtrl.text.trim(),
                    }, SetOptions(merge: true));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _onMapCreated(mbx.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polylineAnnotationManager = await _mapboxMap?.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager = await _mapboxMap?.annotations.createCircleAnnotationManager();
    
    try {
      await _mapboxMap?.style.setProjection(mbx.StyleProjection(name: mbx.StyleProjectionName.globe));
      // Terrain Kaynağını Ekle
      await _mapboxMap?.style.addSource(mbx.RasterDemSource(id: "mapbox-dem", url: "mapbox://mapbox.mapbox-terrain-dem-v1"));
      await _mapboxMap?.style.setStyleTerrainProperty("source", "mapbox-dem");
      await _mapboxMap?.style.setStyleTerrainProperty("exaggeration", 1.2);
    } catch (_) {}

    if (mounted) {
      setState(() => _mapReady = true);
      _updateMapboxRadar();
    }
  }

  void _updateMapboxRadar() async {
    if (_pointAnnotationManager == null || !mounted) return;
    
    // Rota Çizimi
    if (_polylineAnnotationManager != null) {
       await _polylineAnnotationManager?.deleteAll();
       if (_aktifRotaPoints.isNotEmpty) {
          final line = mbx.PolylineAnnotationOptions(
           geometry: mbx.LineString(coordinates: _aktifRotaPoints.map((p) => mbx.Position(p.longitude, p.latitude)).toList()),
           lineColor: Colors.blueAccent.value,
            lineWidth: 3.0,
          );
          await _polylineAnnotationManager?.create(line);
       }
    }

    // Takım Arkadaşları
    await _pointAnnotationManager?.deleteAll();
    for (var t in _teammates) {
       await _pointAnnotationManager?.create(mbx.CircleAnnotationOptions(
         geometry: mbx.Point(coordinates: mbx.Position(t.lng, t.lat)),
         circleRadius: 6.0,
         circleColor: Colors.blueAccent.value,
         circleStrokeWidth: 2.0,
         circleStrokeColor: Colors.white.value,
       ));
    }
    
    // Kendi Konumum (Opsiyonel: Eğer MarkerLayer yerine annotation kullanmak istersek)
    if (_currentPosition != null) {
       await _pointAnnotationManager?.create(mbx.CircleAnnotationOptions(
         geometry: mbx.Point(coordinates: mbx.Position(_currentPosition!.longitude, _currentPosition!.latitude)),
         circleRadius: 8.0,
         circleColor: kOrange.value,
         circleStrokeWidth: 2.0,
         circleStrokeColor: Colors.white.value,
       ));
    }
  }

  void _loadBannerAd() async {
    final isPrem = await AdService.checkPremiumStatus();
    if (mounted) setState(() => _isPremium = isPrem);
    if (!isPrem) {
      if (mounted) {
        setState(() {
          _bannerAd = BannerAd(
            adUnitId: AdService().bannerAdUnitId,
            size: AdSize.banner,
            request: const AdRequest(),
            listener: BannerAdListener(
              onAdLoaded: (ad) {
                if (mounted) setState(() => _isBannerAdLoaded = true);
              },
              onAdFailedToLoad: (ad, error) {
                ad.dispose();
                if (mounted) setState(() => _isBannerAdLoaded = false);
              },
            ),
          )..load();
        });
      }
    }
  }

  void _initSafetyServices() async {
    // 1. Sesle SOS
    if (await StorageHelper.getVoiceSos()) {
      await VoiceSosService.init();
      VoiceSosService.onSosTriggered = (msg) {
        if (mounted) setState(() => _sosStatusMessage = msg);
        _onYardimPressed();
      };
      VoiceSosService.start();
    }

    // 2. Mesafe Takibi
    if (await StorageHelper.getGeofencing()) {
      SafetyService.startMonitoring();
      _safetyAlertsStream = SafetyService.alerts.listen((alert) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(alert, style: const TextStyle(fontWeight: FontWeight.bold)),
               backgroundColor: Colors.redAccent,
               duration: const Duration(seconds: 5),
             )
           );
        }
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _countdownTimer?.cancel();
    _inactivityCheckTimer?.cancel();
    _weatherTimer?.cancel();
    _radarStream?.cancel();
    _strobeTimer?.cancel();

    _safetyAlertsStream?.cancel();
    _presenceTimer?.cancel();
    _activeUserTimer?.cancel();
    _phoneController.dispose();
    _bannerAd?.dispose();
    SafetyService.stopMonitoring();
    VoiceSosService.stop();
    DatabaseHelper.rotaUpdateNotifier.removeListener(_aktifRotayiYukle);
    super.dispose();
  }

  void _startRadar() {
    _radarStream = RadarService.getTeammateLocations().listen((liste) {
      if (mounted) {
        setState(() => _teammates = liste);
        _updateMapboxRadar();
      }
    });
  }

  void _checkAndRequestPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      bool smsGranted = isIOS ? true : await Permission.sms.isGranted;
      bool locGranted = await Permission.location.isGranted;
      
      if (smsGranted && locGranted) return;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('İZİN GEREKSİNİMLERİ', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
          content: const SingleChildScrollView(
            child: Text(
              'Rota+ uygulamasının temel acil durum (SOS) işlevlerini yerine getirebilmesi için aşağıdaki izinlere ihtiyacı vardır:\n\n'
              '• SMS İzni: Acil bir durumda (SOS butonuna bastığınızda) veya uzun süreli hareketsizlik tespit edildiğinde konumunuzu güvendiğiniz kişilere otomatik olarak arka planda SMS gönderebilmek için.\n\n'
              '• Konum İzni: Acil durumlarda tam yerinizi tespit etmek ve arama kurtarma ekiplerine (veya belirlediğiniz kişilere) doğru konum iletmek için.\n\n'
              'Lütfen sonraki adımlarda bu izinlere onay verin.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
                
                List<Permission> permsToRequest = [
                  Permission.location,
                  Permission.notification,
                  Permission.microphone,
                  Permission.speech,
                ];
                if (!isIOS) {
                  permsToRequest.add(Permission.sms);
                }
                
                await permsToRequest.request();
                // Removed the blocking _showMandatoryPermissionsDialog entirely
              },
              child: const Text('Devam Et', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  void _startInactivityTimer() {
    _inactivityCheckTimer?.cancel();
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPosition == null || _isSosActive || !_inactivitySensorEnabled) return;
      _inactivitySeconds++;
      if (_inactivitySeconds >= 900 && !_showInactivityWarning) {
        _triggerInactivityWarning();
      }
    });
  }

  void _triggerInactivityWarning() {
    setState(() => _showInactivityWarning = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('HAREKETSİZLİK TESPİT EDİLDİ',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: const Text(
          'Uzun süredir hareket etmiyorsunuz. İyi misiniz? Yanıt vermezseniz 1 dakika içinde ACİL SOS gönderilecektir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _inactivitySeconds = 0;
                _showInactivityWarning = false;
              });
              Navigator.pop(context);
            },
            child: const Text('İYİYİM',
                style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 60), () {
      if (_showInactivityWarning && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _onYardimPressed();
      }
    });
  }

  void _startCompass() {
    _compassStream = FlutterCompass.events?.listen((event) {
      final raw = event.heading;
      final normalized = raw != null ? ((raw % 360) + 360) % 360 : null;
      if (mounted) setState(() => _heading = normalized);
    });
  }

  Future<void> _initBattery() async {
    final battery = Battery();
    _batteryLevel = await battery.batteryLevel;
    battery.onBatteryStateChanged.listen((state) {
      if (mounted) setState(() => _isCharging = state == BatteryState.charging);
    });

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      int lvl = await battery.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = lvl);
        if (lvl < 15 && !_extremePowerSaving && !_isCharging) {
          _promptExtremePowerSaving();
        }
      }
    });
  }

  void _promptExtremePowerSaving() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('GÜÇ KRİTİK', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Batarya %15 altına düştü. Ekstrem Güç Tasarrufu (OLED-Safe) aktif edilsin mi? Bu mod arayüzü basitleştirir ve GPS hassasiyetini düşürür.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white24))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              Navigator.pop(ctx);
              _togglePowerSaving(true);
            },
            child: const Text('AKTİF ET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _togglePowerSaving(bool active) {
    setState(() => _extremePowerSaving = active);
    
    if (active) {
      // Smart Power Guard: Reduce GPS sampling and disable non-essential streams
      _positionStream?.cancel();
      _startGps(lowPower: true); // Slower polling / lower accuracy
      _compassStream?.cancel();
      _weatherTimer?.cancel();
    } else {
      _startGps(lowPower: false); // Default
      _startCompass();
      // Re-trigger weather check
      if (_currentPosition != null) _fetchWeather(_currentPosition!);
    }
    
    _notify(active ? 'EKSTREM GÜÇ TASARRUFU (OLED-SAFE) AKTİF' : 'GÜÇ MODU: STANDART');
  }


  void _notify(String msg, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: hata ? Colors.red : const Color(0xFF43A047),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startGps({bool lowPower = false}) {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: Platform.isIOS
          ? AppleSettings(
              accuracy: lowPower
                  ? LocationAccuracy.medium
                  : LocationAccuracy.bestForNavigation,
              distanceFilter: lowPower ? 50 : 5,
              allowBackgroundLocationUpdates: true,
            )
          : AndroidSettings(
              accuracy: lowPower
                  ? LocationAccuracy.medium
                  : LocationAccuracy.bestForNavigation,
              distanceFilter: lowPower ? 50 : 5,      // Reduce frequency in low power
              intervalDuration: Duration(seconds: lowPower ? 30 : 5),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: "Rota+ Güvenlik Takibi",
                notificationText: "Radar ve Güvenlik servisleri arka planda çalışıyor.",
                notificationIcon: AndroidResource(name: 'ic_notification'),
          enableWakeLock: true,
        ),
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          if (_currentPosition != null) {
            double dist = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              pos.latitude,
              pos.longitude,
            );
            if (dist > 5) _inactivitySeconds = 0;


          }
          _currentPosition = pos;
          _oncekiKonum = pos;

          // Broadcast location to Radar
          RadarService.broadcastLocation(pos.latitude, pos.longitude);

          // Fetch weather periodically only when we have position
          if (_weatherTimer == null) {
              _fetchWeather(pos);
              _weatherTimer = Timer.periodic(const Duration(minutes: 15), (_) => _fetchWeather(pos));
          }

          if (_isPremium &&
              _aktifRota != null &&
              _aktifRota!['noktalar'] != null) {
            final noktalar = _aktifRota!['noktalar'] as List;
            if (noktalar.isNotEmpty) {
              double minDistance = double.infinity;
              for (var n in noktalar) {
                double d = Geolocator.distanceBetween(
                  pos.latitude,
                  pos.longitude,
                  (n['lat'] as num).toDouble(),
                  (n['lng'] as num).toDouble(),
                );
                if (d < minDistance) minDistance = d;
              }
              _distanceToRoute = minDistance;
              _isOffRoute = minDistance > 75;

              if (_isOffRoute) {
                _safeReturnPath = AIAdvisorService.getSafeReturnPath(
                  lat: pos.latitude,
                  lng: pos.longitude,
                  currentAlt: pos.altitude,
                  routePoints: noktalar,
                );
              } else {
                _safeReturnPath = null;
              }
            }
          }
        });
        if (!_isMapCentered) {
          if (_isPremium && _mapboxMap != null) {
            _mapboxMap?.setCamera(mbx.CameraOptions(
              center: mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude)),
              zoom: 14.0,
            ));
            _isMapCentered = true;
          } else if (!_isPremium && _mapReady) {
            try { _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 14.0); } catch (_) {}
            _isMapCentered = true;
          }
        }
        _updateMapboxRadar();
      }
    });
  }

  Future<void> _fetchWeather(Position pos) async {
    final alert = await WeatherService.checkStormRisk(pos.latitude, pos.longitude);
    if (mounted) {
      setState(() => _weatherAlert = alert);

      // Yangın modülü kapatıldı (Devre dışı bırakıldı)
      // Yangın uyarıları gösterilmez
    }
  }

  Future<void> _aktifRotayiYukle() async {
    final rota = await DatabaseHelper.instance.aktifRotaGetir();
    if (rota != null && mounted) {
      final noktalar = (rota['noktalar'] as List).map((n) =>
        ll.LatLng((n['lat'] as num).toDouble(), (n['lng'] as num).toDouble())
      ).toList();
      setState(() {
        _aktifRota = rota;
        _aktifRotaPoints = noktalar;
      });
      _updateMapboxRadar();
    } else if (mounted) {
      setState(() {
        _aktifRota = null;
        _aktifRotaPoints = [];
      });
      _updateMapboxRadar();
    }
  }

  void _rotayiTemizle() async {
    await DatabaseHelper.instance.rotayiTemizle();
    
    // Firestore senkronizasyonu: Paylaşılan rotayı temizle
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'planned_route': FieldValue.delete(),
        'following_uid': FieldValue.delete(),
        'following_name': FieldValue.delete(),
      });
    }

    if (mounted) {
      setState(() {
        _aktifRota = null;
        _aktifRotaPoints = [];
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Rota İptal Edildi ✓'),
      backgroundColor: Colors.blueAccent,
    ));
  }

  Future<void> _loadSettings() async {
    final phone = await StorageHelper.getObserverPhone();
    final name = await StorageHelper.getUserName();
    final active = await StorageHelper.isSosActive();
    final premium = await PremiumService.isPremium();
    final sensor = await StorageHelper.getInactivitySensor();
    if (mounted) {
      setState(() {
        _phoneController.text = phone ?? '';
        _userName = name ?? 'OPERATIVE';
        _isSosActive = active;
        _isPremium = premium;
        _inactivitySensorEnabled = sensor;
      });
    }
  }

  void _toggleInactivitySensor() async {
      final newVal = !_inactivitySensorEnabled;
      await StorageHelper.setInactivitySensor(newVal);
      setState(() {
          _inactivitySensorEnabled = newVal;
          if (!newVal) {
              _inactivitySeconds = 0;
              _showInactivityWarning = false;
          }
      });
      _notify(newVal ? 'HAREKETSİZLİK SENSÖRÜ AKTİF' : 'HAREKETSİZLİK SENSÖRÜ DEVRE DIŞI');
  }

  Future<void> _savePhone() async {
    FocusScope.of(context).unfocus();
    await StorageHelper.setObserverPhone(_phoneController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ GÖZLEMCİ NOKTASI GÜNCELLENDİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF43A047),
      ),
    );
  }

  void _onYardimPressed() async {
    final savedPhone = await StorageHelper.getObserverPhone();
    if (_phoneController.text.isEmpty && (savedPhone == null || savedPhone.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Önce acil iletişim numarasını kaydedin!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_phoneController.text.isEmpty && savedPhone != null) {
      _phoneController.text = savedPhone;
    }
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _sosStatusMessage = 'GPS konumu alınıyor...';
    });
    await StorageHelper.setSosActive(true);
    setState(() => _sosStatusMessage = 'Durum iletiliyor...');
    await _aktifRotayiYukle();
    
    // Ekibi bilgilendir (Firestore)
    BackgroundSmsService.sosDurumunuGuncelle(true);

    final sonuc = await BackgroundSmsService.sosMesajiGonder();
    if (!mounted) return;
    if (sonuc['basarili'] == true) {
      setState(() {
        _isSosActive = true;
        _isSending = false;
        _sosStatusMessage = 'DURUM İLETİLDİ ✓';
      });
      BackgroundSmsService.sosMesajiGonder(); // Ignore wait
      _yardimGeriSayimBaslat();
    } else {
      await StorageHelper.setSosActive(false);
      setState(() {
        _isSosActive = false;
        _isSending = false;
        _sosStatusMessage = sonuc['hata'] ?? 'İLETİM BAŞARISIZ';
      });
    }
  }

  void _yardimGeriSayimBaslat() {
    _countdown = 120;
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        final sonuc = await BackgroundSmsService.sosMesajiGonder();
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (sonuc['basarili'] == true) {
          setState(() {
            _countdown = 120;
            _sosStatusMessage = 'OTOMATİK BİLGİLENDİRME GÖNDERİLDİ';
          });
        } else {
          timer.cancel();
          setState(() => _sosStatusMessage = 'OTOMATİK GÖNDERİM BAŞARISIZ');
        }
      }
    });
  }

  void _yardimIptal() async {
    _countdownTimer?.cancel();
    await StorageHelper.setSosActive(false);
    BackgroundSmsService.sosDurumunuGuncelle(false); // Ekibi bilgilendir (İptal)
    MorseService.stop(); // Fiziksel flaş durdur
    if (mounted) {
      setState(() {
        _isSosActive = false;
        _isSending = false;
        _sosStatusMessage = '';
        _isSosFlashOn = false;
        _isTorchOn = false;
        _isStrobeOn = false;
      });
    }
  }

  void _toggleSosFlash() async {
    setState(() => _isSosFlashOn = !_isSosFlashOn);
    if (_isSosFlashOn) {
      _isTorchOn = false;
      _isStrobeOn = false;
      _strobeTimer?.cancel();
      await MorseService.playSos();
    } else {
      await MorseService.stop();
    }
  }

  void _toggleTorch() async {
    setState(() => _isTorchOn = !_isTorchOn);
    if (_isTorchOn) {
      _isStrobeOn = false;
      _isSosFlashOn = false;
      _strobeTimer?.cancel();
      await MorseService.torchOn();
    } else {
      await MorseService.stop();
    }
  }

  void _toggleStrobe() async {
    setState(() => _isStrobeOn = !_isStrobeOn);
    if (_isStrobeOn) {
      _isTorchOn = false;
      _isSosFlashOn = false;
      _strobeTimer?.cancel();
      _strobeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (timer.tick % 2 == 0) {
          MorseService.torchOn();
        } else {
          MorseService.stop();
        }
      });
    } else {
      _strobeTimer?.cancel();
      await MorseService.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Scaffold(
      backgroundColor: _extremePowerSaving ? Colors.black : TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: _extremePowerSaving
            ? Colors.black
            : TacticalStyles.kSurfaceLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: TacticalStyles.kOutlineVariant),
          ),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/tactical_logo.png',
                height: 34,
                width: 34,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: TacticalStyles.kPrimaryContainer.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.terrain_rounded, color: TacticalStyles.kPrimary, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'ROTA+',
                      style: TacticalStyles.headline(
                        color: TacticalStyles.kOnSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TacticalStyles.kPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'MIL-SPEC',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kPrimary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isSosActive ? 'SOS Dispatch' : 'Keşfet',
                  style: TacticalStyles.labelCaps(
                    color: TacticalStyles.kOnSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: NightOpsService(),
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () async {
                  final isPrem = await PremiumService.isPremium();
                  if (isPrem) {
                    NightOpsService().toggle();
                  } else {
                    if (mounted) {
                      PremiumService.showPremiumRequired(context, 'Gece Görüş Modu');
                    }
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: NightOpsService().isEnabled
                        ? TacticalStyles.kErrorContainer.withOpacity(0.45)
                        : TacticalStyles.kSurfaceHigh.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NightOpsService().isEnabled
                          ? TacticalStyles.kError
                          : TacticalStyles.kGlassBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.dark_mode_outlined,
                    size: 18,
                    color: NightOpsService().isEnabled
                        ? TacticalStyles.kError
                        : TacticalStyles.kOnSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _togglePowerSaving(!_extremePowerSaving),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _extremePowerSaving
                      ? TacticalStyles.kTertiary.withOpacity(0.18)
                      : TacticalStyles.kSurfaceHigh.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _extremePowerSaving
                        ? TacticalStyles.kTertiary
                        : TacticalStyles.kGlassBorder,
                  ),
                ),
                child: Icon(
                  _extremePowerSaving ? Icons.battery_charging_full_rounded : Icons.battery_saver_rounded,
                  size: 18,
                  color: _extremePowerSaving
                      ? TacticalStyles.kTertiary
                      : TacticalStyles.kOnSurfaceVariant,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TacticalStyles.kSurfaceHigh.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: TacticalStyles.kGlassBorder),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: TacticalStyles.kOnSurfaceVariant,
                      size: 19,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: TacticalStyles.kPrimaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: TacticalStyles.kSurface, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isSosActive ? _buildYardimActivePage() : _buildMainDashboard(),
    );

    if (_extremePowerSaving) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: content,
      );
    }
    return content;
  }

  // ─── ANA DASHBOARD (Tactical Liquid Glass — Stitch Keşfet Paneli) ─────────
  Widget _buildMainDashboard() {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── STATUS & RELAY DISPATCH BAR ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: TacticalStyles.capsuleDecoration(
                            backgroundColor: TacticalStyles.kSurfaceHigh.withOpacity(0.90),
                            borderColor: TacticalStyles.kGlassBorder,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PulsingStatusIndicator(
                                color: TacticalStyles.kTertiary,
                                size: 8,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_activeUserCount OPERATÖR AKTİF',
                                style: TacticalStyles.labelCaps(
                                  color: TacticalStyles.kOnSurface,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: TacticalStyles.capsuleDecoration(
                            backgroundColor: TacticalStyles.kSurfaceContainer.withOpacity(0.65),
                            borderColor: TacticalStyles.kGlassBorder,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.satellite_alt_rounded,
                                color: TacticalStyles.kTertiary,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _currentPosition != null ? 'L-BAND 99.8%' : 'GPS ARANIYOR',
                                style: TacticalStyles.labelMicro(
                                  color: TacticalStyles.kTertiary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── HIZLI İLETİŞİM & ARAMA ÇUBUĞU (Göz Önünde) ──────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickActionPill(
                      icon: Icons.person_search_rounded,
                      label: 'KULLANICI ARA',
                      accentColor: TacticalStyles.kPrimary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickActionPill(
                      icon: Icons.mark_email_unread_rounded,
                      label: 'MESAJLAR',
                      accentColor: const Color(0xFF00E5FF),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DmListScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickActionPill(
                      icon: Icons.notifications_active_rounded,
                      label: 'BİLDİRİM',
                      accentColor: TacticalStyles.kPrimaryContainer,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── HERO TELEMETRY: GÜVENLİ METEOROLOJİ WIDGET ──────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: _buildWeatherSection(),
            ),

            const SizedBox(height: 8),

            // ── DUAL TELEMETRY HUB: RAKIM & İSTİKAMET ──────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      label: 'RAKIM',
                      value: (_currentPosition != null && _currentPosition!.altitude.abs() > 1)
                          ? '${_currentPosition!.altitude.toInt()}'
                          : '--',
                      unit: 'M',
                      isAltitude: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoCard(
                      label: 'İSTİKAMET',
                      value: _heading != null ? '${_heading!.toInt()}°' : '--°',
                      unit: _yonKisa(_heading),
                      isAltitude: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── HAREKETSİZLİK SENSÖRÜ KARTI ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TacticalPressable(
                onTap: _toggleInactivitySensor,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 16,
                    borderColor: _inactivitySensorEnabled
                        ? TacticalStyles.kPrimaryContainer.withOpacity(0.45)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _inactivitySensorEnabled
                              ? TacticalStyles.kPrimaryContainer.withOpacity(0.18)
                              : TacticalStyles.kSurfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.sensors_rounded,
                          color: _inactivitySensorEnabled
                              ? TacticalStyles.kPrimaryContainer
                              : TacticalStyles.kOutline,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HAREKETSİZLİK SENSÖRÜ',
                              style: TacticalStyles.labelCaps(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _inactivitySensorEnabled
                                  ? 'Aktif (15 dk hareketsizlikte durum bildirir)'
                                  : 'Devre dışı bırakıldı (Beklemede)',
                              style: TacticalStyles.body(
                                color: TacticalStyles.kOutline,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 28,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _inactivitySensorEnabled
                              ? TacticalStyles.kPrimaryContainer
                              : TacticalStyles.kSurfaceHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: _inactivitySensorEnabled
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _inactivitySensorEnabled
                                ? TacticalStyles.kOnPrimary
                                : TacticalStyles.kOutlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── TACTICAL SATELLITE INTERACTIVE MAP PREVIEW ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: TacticalStyles.glassCardDecoration(
                  radius: 16,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SizedBox(
                      height: 290,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          if (_isPremium)
                            mbx.MapWidget(
                              key: const ValueKey("home_mapbox"),
                              onMapCreated: _onMapCreated,
                              styleUri: _isTacticalMap
                                  ? mbx.MapboxStyles.DARK
                                  : mbx.MapboxStyles.OUTDOORS,
                              cameraOptions: mbx.CameraOptions(
                                center: _currentPosition != null
                                    ? mbx.Point(
                                        coordinates: mbx.Position(
                                            _currentPosition!.longitude,
                                            _currentPosition!.latitude))
                                    : mbx.Point(coordinates: mbx.Position(35.0, 39.0)),
                                zoom: 14.0,
                              ),
                            )
                          else
                            fm.FlutterMap(
                              mapController: _mapController,
                              options: fm.MapOptions(
                                initialCenter: _currentPosition != null
                                    ? ll.LatLng(_currentPosition!.latitude,
                                        _currentPosition!.longitude)
                                    : const ll.LatLng(39.0, 35.0),
                                initialZoom: 14.0,
                                onMapReady: () {
                                  setState(() => _mapReady = true);
                                  if (_currentPosition != null) {
                                    try {
                                      _mapController.move(
                                          ll.LatLng(_currentPosition!.latitude,
                                              _currentPosition!.longitude),
                                          14.0);
                                    } catch (_) {}
                                  }
                                },
                              ),
                              children: [
                                fm.TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  maxZoom: 17,
                                  userAgentPackageName: 'RotaPlus_Tactical_v1.0',
                                ),
                                if (_aktifRotaPoints.isNotEmpty)
                                  fm.PolylineLayer(
                                    polylines: [
                                      fm.Polyline(
                                        points: _aktifRotaPoints,
                                        color: TacticalStyles.kSecondaryContainer,
                                        strokeWidth: 4.5,
                                        pattern:
                                            fm.StrokePattern.dashed(segments: [15, 15]),
                                      ),
                                    ],
                                  ),
                                if (_currentPosition != null)
                                  fm.MarkerLayer(
                                    markers: [
                                      fm.Marker(
                                        point: ll.LatLng(_currentPosition!.latitude,
                                            _currentPosition!.longitude),
                                        width: 44,
                                        height: 44,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: TacticalStyles.kPrimaryContainer
                                                    .withOpacity(0.22),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: TacticalStyles.kPrimaryContainer,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                          // Top Overlay: Grid Telemetry Coordinates & Scale
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_currentPosition != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: TacticalStyles.kSurfaceLowest.withOpacity(0.84),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: TacticalStyles.kGlassBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const PulsingStatusIndicator(
                                          color: TacticalStyles.kPrimaryContainer,
                                          size: 7,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          '${_currentPosition!.latitude.toStringAsFixed(4)}° N, ${_currentPosition!.longitude.toStringAsFixed(4)}° E',
                                          style: TacticalStyles.telemetry(
                                            color: TacticalStyles.kOnSurface,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TacticalStyles.kSurfaceLowest.withOpacity(0.84),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: TacticalStyles.kGlassBorder),
                                  ),
                                  child: Text(
                                    'ÖLÇEK: 250M',
                                    style: TacticalStyles.labelMicro(
                                      color: TacticalStyles.kOutline,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right Side Tactical Floating Control Rail (Exact same controls!)
                          Positioned(
                            top: 46,
                            right: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final isPrem = await PremiumService.isPremium();
                                    if (isPrem) {
                                      setState(() => _isTacticalMap = !_isTacticalMap);
                                      _notify(_isTacticalMap
                                          ? 'Koyu Harita Katmanı Aktif'
                                          : 'Doğa Harita Katmanı Aktif');
                                    } else {
                                      PremiumService.showPremiumRequired(
                                          context, 'Özel Harita Katmanı');
                                    }
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: _isTacticalMap
                                          ? TacticalStyles.kPrimaryContainer
                                          : TacticalStyles.kSurfaceLowest.withOpacity(0.88),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: TacticalStyles.kGlassBorder),
                                    ),
                                    child: Icon(
                                      Icons.layers_outlined,
                                      color: _isTacticalMap
                                          ? TacticalStyles.kOnPrimaryContainer
                                          : TacticalStyles.kOnSurface,
                                      size: 19,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const ArCompassScreen())),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: TacticalStyles.kPrimaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: TacticalStyles.kPrimaryContainer.withOpacity(0.35),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera_outlined,
                                      color: TacticalStyles.kOnPrimaryContainer,
                                      size: 19,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const PeakARScreen())),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: TacticalStyles.kSurfaceLowest.withOpacity(0.88),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: TacticalStyles.kGlassBorder),
                                    ),
                                    child: const Icon(
                                      Icons.terrain_rounded,
                                      color: TacticalStyles.kTertiary,
                                      size: 19,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const MeshNetworkScreen())),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: TacticalStyles.kSurfaceLowest.withOpacity(0.88),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: TacticalStyles.kGlassBorder),
                                    ),
                                    child: const Icon(
                                      Icons.radar_rounded,
                                      color: TacticalStyles.kSecondary,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom Over-Map Capsule: Canlı Takip Status Pill
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: TacticalStyles.kSurfaceLowest.withOpacity(0.88),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: TacticalStyles.kGlassBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.my_location_rounded,
                                        color: TacticalStyles.kTertiary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _teammates.isEmpty
                                            ? 'CANLI TAKİP AKTİF'
                                            : 'EKİP RADARI: ${_teammates.length} AKTİF',
                                        style: TacticalStyles.labelCaps(
                                          color: TacticalStyles.kOnSurface,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_aktifRota != null)
                                  Flexible(
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: TacticalStyles.kSurfaceHigh.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                            color: TacticalStyles.kPrimaryContainer
                                                .withOpacity(0.45)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.flag_rounded,
                                              color: TacticalStyles.kPrimaryContainer, size: 13),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _aktifRota!['isim'].toString(),
                                              style: TacticalStyles.labelCaps(
                                                color: TacticalStyles.kOnSurface,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: _rotayiTemizle,
                                            child: const Icon(Icons.close_rounded,
                                                color: TacticalStyles.kError, size: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map Telemetry Footer: Canlı Konum Bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: TacticalStyles.kSurfaceLow,
                        border: Border(
                          top: BorderSide(color: Colors.white.withOpacity(0.06)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: TacticalStyles.kTertiary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.near_me_rounded,
                              color: TacticalStyles.kTertiary,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CANLI GPS KONUMU',
                                  style: TacticalStyles.labelMicro(
                                    color: TacticalStyles.kOutline,
                                    fontSize: 9,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _currentPosition != null
                                    ? Text(
                                        '${_currentPosition!.latitude.toStringAsFixed(6)}°N ${_currentPosition!.longitude.toStringAsFixed(6)}°E',
                                        style: TacticalStyles.telemetry(
                                          color: TacticalStyles.kTertiary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : Text(
                                        'GPS SİNYALİ BEKLENİYOR...',
                                        style: TacticalStyles.telemetry(
                                          color: TacticalStyles.kOutline,
                                          fontSize: 12,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'YÖN',
                                style: TacticalStyles.labelMicro(
                                  color: TacticalStyles.kOutline,
                                  fontSize: 9,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _heading != null ? '${_heading!.toInt()}°' : '--',
                                    style: TacticalStyles.headline(
                                      color: TacticalStyles.kPrimaryContainer,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _yonKisa(_heading),
                                    style: TacticalStyles.labelCaps(
                                      color: TacticalStyles.kOnSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── AD BANNER ──────────────────────────────
            if (!_isPremium && _bannerAd != null && _isBannerAdLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  alignment: Alignment.center,
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),

            const SizedBox(height: 8),

            // ── OPERATIONAL FIELD QUICK CARDS: MESH & BATARYA TAHMİNİ ───────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TacticalPressable(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MeshNetworkScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: TacticalStyles.glassCardDecoration(radius: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.wifi_tethering_rounded,
                                  color: TacticalStyles.kSecondary,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'MESH AĞI',
                                  style: TacticalStyles.labelMicro(
                                    color: TacticalStyles.kOutline,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_nearbyMeshCount CİHAZ',
                              style: TacticalStyles.headline(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _nearbyMeshCount > 0
                                  ? 'Çevre arama menzili 1.4 km'
                                  : 'Yakında cihaz yok • Tarama için dokun',
                              style: TacticalStyles.body(
                                color: TacticalStyles.kOnSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: TacticalStyles.glassCardDecoration(radius: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isCharging
                                    ? Icons.battery_charging_full_rounded
                                    : Icons.battery_std_rounded,
                                color: _batteryLevel < 20
                                    ? TacticalStyles.kError
                                    : TacticalStyles.kPrimary,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'BATARYA TAHMİNİ',
                                style: TacticalStyles.labelMicro(
                                  color: TacticalStyles.kOutline,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '%$_batteryLevel • ${(_batteryLevel * 0.16).clamp(1, 18).toInt()} SAAT',
                            style: TacticalStyles.headline(
                              color: _batteryLevel < 20
                                  ? TacticalStyles.kError
                                  : TacticalStyles.kPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _extremePowerSaving
                                ? 'Düşük güç modunda aktif'
                                : (_isCharging ? 'Şarj bağlantısı aktif' : 'Standart operasyon modu'),
                            style: TacticalStyles.body(
                              color: TacticalStyles.kOnSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── SAHA ARAÇLARI ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildToolButton(
                    label: 'FENER',
                    icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    active: _isTorchOn,
                    onTap: _toggleTorch,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    label: 'ÇAKAR',
                    icon: Icons.wb_iridescent_outlined,
                    active: _isStrobeOn,
                    onTap: _toggleStrobe,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    label: 'SOS FLAŞ',
                    icon: Icons.light_mode_outlined,
                    active: _isSosFlashOn,
                    onTap: _toggleSosFlash,
                    color: TacticalStyles.kPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    label: 'DEPREM',
                    icon: Icons.rss_feed_rounded,
                    active: false,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const EarthquakeFeedScreen())),
                    color: TacticalStyles.kSecondaryContainer,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ROTA DÖNÜŞ TAVSİYESİ
            if (_isOffRoute && _safeReturnPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 16,
                    borderColor: TacticalStyles.kSecondaryContainer.withOpacity(0.45),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: TacticalStyles.kSecondaryContainer.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _safeReturnPath!['icon'] == 'trending_up'
                              ? Icons.trending_up_rounded
                              : _safeReturnPath!['icon'] == 'trending_down'
                                  ? Icons.trending_down_rounded
                                  : Icons.explore_rounded,
                          color: TacticalStyles.kSecondaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ROTA DÖNÜŞ ÖNERİSİ',
                              style: TacticalStyles.labelCaps(
                                color: TacticalStyles.kSecondaryContainer,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _safeReturnPath!['advice'],
                              style: TacticalStyles.body(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── HAYATTA KALMA REHBERİ GİRİŞİ ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SurvivalGuideScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  decoration: TacticalStyles.glassCardDecoration(radius: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: TacticalStyles.kPrimaryContainer.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_rounded,
                            color: TacticalStyles.kPrimary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Doğa & Hayatta Kalma Rehberi',
                          style: TacticalStyles.headline(
                            color: TacticalStyles.kOnSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: TacticalStyles.kOutline, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── DEPREM / ENKAZ MODU GİRİŞİ ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EarthquakeModuleScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 14,
                    borderColor: TacticalStyles.kError.withOpacity(0.30),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: TacticalStyles.kErrorContainer.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: TacticalStyles.kError, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Deprem & Enkaz Modu',
                          style: TacticalStyles.headline(
                            color: TacticalStyles.kOnSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: TacticalStyles.kOutline, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── AFET & OLAY İHBARI KARTI ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TacticalPressable(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const IncidentReportScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 14,
                    borderColor:
                        TacticalStyles.kPrimaryContainer.withOpacity(0.45),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color:
                              TacticalStyles.kPrimaryContainer.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: TacticalStyles.kPrimaryContainer,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Afet & Olay İhbarı Bildir',
                              style: TacticalStyles.headline(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Deprem, sel, yangın fotoğraf & özet gönder',
                              style: TacticalStyles.body(
                                color: TacticalStyles.kOnSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: TacticalStyles.kOutline, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── DESTEK & HATA BİLDİRİMİ ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _showSupportTicketDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: TacticalStyles.glassCardDecoration(radius: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TacticalStyles.kPrimary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: TacticalStyles.kPrimary,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Destek & Hata Bildir',
                              style: TacticalStyles.headline(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Yöneticiye öneri, hata veya destek talebi gönder',
                              style: TacticalStyles.body(
                                color: TacticalStyles.kOnSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: TacticalStyles.kOutline, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── ÇIĞ GÜVENLİK VE ARVA MODÜLÜ ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AvalancheModuleScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 14,
                    borderColor: TacticalStyles.kSecondaryContainer.withOpacity(0.30),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: TacticalStyles.kSecondaryContainer.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.ac_unit_rounded,
                            color: TacticalStyles.kSecondaryContainer,
                            size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Çığ Güvenliği & ARVA Modülü',
                          style: TacticalStyles.headline(
                            color: TacticalStyles.kOnSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: TacticalStyles.kOutline, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── SOS BUTONU (EXACT SAME POSITION, TACTICAL LIQUID GLASS SAFETY AMBER) ────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onLongPress: _onYardimPressed,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        TacticalStyles.kPrimaryContainer,
                        TacticalStyles.kPrimaryContainer.withOpacity(0.86),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: TacticalStyles.kPrimary.withOpacity(0.45),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TacticalStyles.kPrimaryContainer.withOpacity(0.32),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.crisis_alert_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    'ACİL YARDIM ÇAĞRISI',
                                    style: TacticalStyles.labelMicro(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SOS ACİL GÖNDER',
                              style: TacticalStyles.headline(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Konumu ve acil çağrıyı iletmek için basılı tutun',
                              style: TacticalStyles.body(
                                color: Colors.white.withOpacity(0.90),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.26),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.sos_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── ACİL DURUM İLETİŞİM & İLKYARDIM KARTI ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: TacticalStyles.glassCardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: TacticalStyles.kPrimaryContainer
                                .withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.contact_phone_outlined,
                              color: TacticalStyles.kPrimary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACİL DURUM İLETİŞİM KİŞİSİ',
                                style: TacticalStyles.labelCaps(
                                  color: TacticalStyles.kOnSurface,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SOS durumunda otomatik SMS gönderilecek numara',
                                style: TacticalStyles.body(
                                  color: TacticalStyles.kOnSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: TacticalStyles.recessedDecoration(radius: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              color: TacticalStyles.kOutline, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              style: TacticalStyles.telemetry(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _savePhone(),
                              onTapOutside: (_) => FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                hintText: '+90 5XX XXX XXXX',
                                hintStyle: TacticalStyles.telemetry(
                                  color: TacticalStyles.kOutline.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _savePhone,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: TacticalStyles.kPrimaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_sosStatusMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _sosStatusMessage,
                        style: TacticalStyles.labelCaps(
                          color: _sosStatusMessage.contains('✓')
                              ? TacticalStyles.kTertiary
                              : TacticalStyles.kError,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // İLKYARDIM REHBERİ BUTONU
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const FirstAidScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: TacticalStyles.kSurfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TacticalStyles.kGlassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.medical_services_outlined,
                                color: TacticalStyles.kPrimary, size: 19),
                            const SizedBox(width: 10),
                            Text(
                              'İLKYARDIM REHBERİ',
                              style: TacticalStyles.labelCaps(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmergencyIdCardScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: TacticalStyles.kError.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: TacticalStyles.kError.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2_rounded,
                                color: TacticalStyles.kError, size: 19),
                            const SizedBox(width: 10),
                            Text(
                              'ACİL MEDİKAL KÜNYE (QR)',
                              style: TacticalStyles.labelCaps(
                                color: TacticalStyles.kError,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── YARDIM AKTİF SAYFASI (STITCH: sos_acil_yard_m_a_r_s_aktif) ──────────────
  Widget _buildYardimActivePage() {
    final double countdownProgress = (_countdown / 120.0).clamp(0.05, 1.0);
    return SafeArea(
      child: Container(
        color: TacticalStyles.kSurface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero SOS Pulse Orb Container (Liquid Obsidian Glass Tactical SOS Sphere)
              SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Concentric Atmospheric Wave Ring 1
                    Container(
                      width: 204,
                      height: 204,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TacticalStyles.kPrimary.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                    ),
                    // Outer Refraction Wave Ring 2
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TacticalStyles.kPrimaryContainer.withOpacity(0.08),
                        border: Border.all(
                          color: TacticalStyles.kPrimaryContainer.withOpacity(0.28),
                          width: 1,
                        ),
                      ),
                    ),
                    // Liquid Obsidian Glass Tactical SOS Sphere
                    Container(
                      width: 152,
                      height: 152,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TacticalStyles.kSurfaceLowest.withOpacity(0.88),
                        border: Border.all(
                          color: TacticalStyles.kPrimary.withOpacity(0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TacticalStyles.kPrimaryContainer.withOpacity(0.32),
                            blurRadius: 42,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              TacticalStyles.kPrimaryContainer.withOpacity(0.32),
                              TacticalStyles.kSurfaceHigh.withOpacity(0.45),
                              Colors.black.withOpacity(0.85),
                            ],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Specular Highlight Arc
                            Positioned(
                              top: 8,
                              child: Container(
                                width: 88,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withOpacity(0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SOS',
                                  style: TacticalStyles.displayHero(
                                    color: TacticalStyles.kPrimary,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const PulsingStatusIndicator(
                                      color: TacticalStyles.kPrimaryContainer,
                                      size: 6,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'BEACON TX',
                                      style: TacticalStyles.labelMicro(
                                        color: TacticalStyles.kPrimary,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // KOD: KIRMIZI • ACİL DURUM Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: TacticalStyles.capsuleDecoration(
                  backgroundColor: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulsingStatusIndicator(
                      color: TacticalStyles.kPrimaryContainer,
                      size: 7,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'KOD: KIRMIZI • ACİL DURUM',
                      style: TacticalStyles.labelCaps(
                        color: TacticalStyles.kPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'YARDIM ÇAĞRISI AKTİF',
                textAlign: TextAlign.center,
                style: TacticalStyles.headline(
                  color: TacticalStyles.kOnSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GÖZLEMCİYE KONUM İLETİLİYOR',
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 10.5,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const PulsingStatusIndicator(
                    color: TacticalStyles.kPrimaryContainer,
                    size: 5,
                  ),
                ],
              ),
              if (MorseService.isPulsing) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: TacticalStyles.kPrimaryContainer.withOpacity(0.14),
                    border: Border.all(color: TacticalStyles.kPrimaryContainer.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on_rounded, color: TacticalStyles.kPrimary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'MORS FLAŞ SİNYALİ AKTİF',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kPrimary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Otomatik Güncelleme Döngüsü (Countdown Monolith)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: TacticalStyles.glassCardDecoration(
                  radius: 16,
                  backgroundColor: TacticalStyles.kSurfaceLow.withOpacity(0.82),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sync_rounded,
                              color: TacticalStyles.kPrimary,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'OTOMATİK GÜNCELLEME DÖNGÜSÜ',
                              style: TacticalStyles.labelCaps(
                                color: TacticalStyles.kOnSurfaceVariant,
                                fontSize: 10.5,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: TacticalStyles.kSurfaceHigh.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TX SYNC: 120S',
                            style: TacticalStyles.labelMicro(
                              color: TacticalStyles.kTertiary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$_countdown',
                          style: TacticalStyles.displayHero(
                            color: TacticalStyles.kOnSurface,
                            fontSize: 54,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SN',
                          style: TacticalStyles.headline(
                            color: TacticalStyles.kPrimaryContainer,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: countdownProgress,
                        minHeight: 6,
                        backgroundColor: TacticalStyles.kSurfaceHighest.withOpacity(0.6),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          TacticalStyles.kPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SON İLETİM: AKTİF',
                          style: TacticalStyles.labelMicro(
                            color: TacticalStyles.kOnSurfaceVariant,
                            fontSize: 9.5,
                          ),
                        ),
                        Text(
                          'SONRAKİ PAKET: ${_countdown}s',
                          style: TacticalStyles.labelMicro(
                            color: TacticalStyles.kTertiary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Telemetry & Protocol Status Pair (GPS_BAĞLANTISI & VERİ_PAKETİ)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: TacticalStyles.glassCardDecoration(
                        radius: 16,
                        backgroundColor: TacticalStyles.kSurfaceLow.withOpacity(0.75),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GPS_BAĞLANTISI',
                                style: TacticalStyles.labelMicro(
                                  color: TacticalStyles.kOnSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                              const Icon(
                                Icons.satellite_alt_rounded,
                                color: TacticalStyles.kTertiary,
                                size: 15,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const PulsingStatusIndicator(
                                color: TacticalStyles.kTertiary,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentPosition != null ? 'KİLİTLENDİ' : 'ARANIYOR',
                                style: TacticalStyles.telemetry(
                                  color: TacticalStyles.kTertiary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white.withOpacity(0.06)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _currentPosition != null
                                      ? 'DOĞRULUK: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m'
                                      : 'DOĞRULUK: --',
                                  style: TacticalStyles.labelMicro(
                                    color: TacticalStyles.kOnSurfaceVariant,
                                    fontSize: 8.5,
                                  ),
                                ),
                                Text(
                                  'GPS',
                                  style: TacticalStyles.labelMicro(
                                    color: TacticalStyles.kOnSurface,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: TacticalStyles.glassCardDecoration(
                        radius: 16,
                        backgroundColor: TacticalStyles.kSurfaceLow.withOpacity(0.75),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'VERİ_PAKETİ',
                                style: TacticalStyles.labelMicro(
                                  color: TacticalStyles.kOnSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                              const Icon(
                                Icons.shield_outlined,
                                color: TacticalStyles.kSecondaryContainer,
                                size: 15,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.vpn_key_rounded,
                                color: TacticalStyles.kSecondaryContainer,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'ŞİFRELİ_SMS',
                                  style: TacticalStyles.telemetry(
                                    color: TacticalStyles.kOnSurface,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white.withOpacity(0.06)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SMS FALLBACK',
                                  style: TacticalStyles.labelMicro(
                                    color: TacticalStyles.kOnSurfaceVariant,
                                    fontSize: 8.5,
                                  ),
                                ),
                                Text(
                                  'AKTİF',
                                  style: TacticalStyles.labelMicro(
                                    color: TacticalStyles.kSecondary,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ALARMI SONLANDIR Button
              GestureDetector(
                onTap: _yardimIptal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 16,
                    backgroundColor: TacticalStyles.kSurfaceHigh.withOpacity(0.75),
                    borderColor: TacticalStyles.kError.withOpacity(0.35),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: TacticalStyles.kErrorContainer.withOpacity(0.85),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: TacticalStyles.kOnError,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ALARMI SONLANDIR',
                            style: TacticalStyles.headline(
                              color: TacticalStyles.kError,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'GÜVENDEYSENİZ ÇAĞRIYI İPTAL ETMEK İÇİN DOKUNUN',
                            style: TacticalStyles.labelMicro(
                              color: TacticalStyles.kOnSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── YARDIMCI WİDGETLER ───────────────────────────────────────────────────

  Widget _buildQuickActionPill({
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return TacticalPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: TacticalStyles.glassCardDecoration(
          radius: 12,
          borderColor: accentColor.withOpacity(0.38),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentColor, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TacticalStyles.labelCaps(
                  color: TacticalStyles.kOnSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required String unit,
    bool isAltitude = true,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.all(15),
      decoration: TacticalStyles.glassCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TacticalStyles.labelCaps(
                  color: TacticalStyles.kOutline,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              if (isAltitude)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _currentPosition != null ? 'GPS AKTİF' : 'BEKLEMEDE',
                    style: TacticalStyles.labelMicro(
                      color: TacticalStyles.kTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.explore_outlined,
                  color: TacticalStyles.kPrimaryContainer,
                  size: 16,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          style: TacticalStyles.displayHero(
                            color: TacticalStyles.kOnSurface,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          maxLines: 1,
                          style: TacticalStyles.headline(
                            color: isAltitude
                                ? TacticalStyles.kPrimary
                                : TacticalStyles.kPrimaryContainer,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isAltitude) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF1F222A),
                          Color(0xFF111217),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.14),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TacticalStyles.kPrimaryContainer.withOpacity(0.14),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sabit dış derece halkası + üst kerteriz üçgeni
                        const CustomPaint(
                          size: Size(52, 52),
                          painter: _CompassBezelPainter(),
                        ),
                        // Yön açısına göre dönen taktik pusula iğnesi
                        Transform.rotate(
                          angle: -((_heading ?? 0) * math.pi / 180.0),
                          child: const CustomPaint(
                            size: Size(52, 52),
                            painter: _MiniGyroRingPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAltitude)
            SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(
                painter: _MiniSparklinePainter(
                  color: TacticalStyles.kPrimary.withOpacity(0.85),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: TacticalStyles.kPrimaryContainer,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: TacticalStyles.kPrimaryContainer.withOpacity(0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _yonUzun(_heading),
                            style: TacticalStyles.labelMicro(
                              color: TacticalStyles.kOnSurface,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PUSULA',
                    style: TacticalStyles.labelMicro(
                      color: TacticalStyles.kOutline,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _yonKisa(double? head) {
    if (head == null) return 'K';
    if (head > 337.5 || head <= 22.5) return 'K';
    if (head > 22.5 && head <= 67.5) return 'KD';
    if (head > 67.5 && head <= 112.5) return 'D';
    if (head > 112.5 && head <= 157.5) return 'GD';
    if (head > 157.5 && head <= 202.5) return 'G';
    if (head > 202.5 && head <= 247.5) return 'GB';
    if (head > 247.5 && head <= 292.5) return 'B';
    if (head > 292.5 && head <= 337.5) return 'KB';
    return 'K';
  }

  String _yonUzun(double? head) {
    if (head == null) return 'KALİBRE EDİLİYOR';
    if (head > 337.5 || head <= 22.5) return 'KUZEY';
    if (head > 22.5 && head <= 67.5) return 'KUZEYDOĞU';
    if (head > 67.5 && head <= 112.5) return 'DOĞU';
    if (head > 112.5 && head <= 157.5) return 'GÜNEYDOĞU';
    if (head > 157.5 && head <= 202.5) return 'GÜNEY';
    if (head > 202.5 && head <= 247.5) return 'GÜNEYBATI';
    if (head > 247.5 && head <= 292.5) return 'BATI';
    if (head > 292.5 && head <= 337.5) return 'KUZEYBATI';
    return 'KUZEY';
  }

  Future<void> _seferiBaslat(Mountain dag) async {
    await DatabaseHelper.instance.rotaKaydet(
      dag.name,
      [
        {'lat': dag.lat, 'lng': dag.lng}
      ],
    );
    await _aktifRotayiYukle();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ROTA: ${dag.name.toUpperCase()} BAŞLATILDI'),
          backgroundColor: const Color(0xFF1A3A1A),
        ),
      );
    }
  }

  int _hesaplaIlerlemeYuzdesi() {
    if (_currentPosition == null ||
        _aktifRota == null ||
        (_aktifRota!['noktalar'] as List).isEmpty) return 0;
    final noktalar = _aktifRota!['noktalar'] as List;
    final start = noktalar.first;
    final end = noktalar.last;
    double total = Geolocator.distanceBetween(
      (start['lat'] as num).toDouble(),
      (start['lng'] as num).toDouble(),
      (end['lat'] as num).toDouble(),
      (end['lng'] as num).toDouble(),
    );
    double remaining = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (end['lat'] as num).toDouble(),
      (end['lng'] as num).toDouble(),
    );
    int p = (100 - (remaining / total * 100)).round();
    return p.clamp(0, 100);
  }

  // ── HERO TELEMETRY: GÜVENLİ METEOROLOJİ WIDGET (Stitch Referanslı) ────────
  Widget _buildWeatherSection() {
    final bool isLoading = _weatherAlert == null || _weatherAlert!.isLoading;
    final bool hazardous = !isLoading && _weatherAlert!.isHazardous;
    final Color statusColor = isLoading
        ? TacticalStyles.kSecondaryContainer
        : (hazardous ? TacticalStyles.kPrimaryContainer : TacticalStyles.kTertiary);

    final String titleText = isLoading
        ? 'METEOROLOJİ VERİSİ'
        : (hazardous ? 'RİSKLİ METEOROLOJİ' : 'GÜVENLİ METEOROLOJİ');
    final String badgeText = isLoading
        ? 'BEKLENİYOR'
        : (hazardous ? 'DİKKAT' : 'OPTIMAL');
    final String subtitleText = isLoading
        ? 'Canlı atmosferik telemetri verisi alınıyor...'
        : (_weatherAlert!.description.isNotEmpty
            ? _weatherAlert!.description
            : (hazardous
                ? 'Saha koşulları operasyon için dikkat gerektiriyor'
                : 'Hava yürüyüş ve operasyon için uygun'));

    final int? pressureVal = !isLoading ? _weatherAlert!.pressure?.toInt() : null;
    final int? humidityVal = !isLoading ? _weatherAlert!.humidity?.toInt() : null;
    final int? windVal = !isLoading ? _weatherAlert!.windSpeed.toInt() : null;

    final double pressureFactor = pressureVal != null
        ? ((pressureVal - 960) / 80.0).clamp(0.12, 1.0)
        : 0.0;
    final double humidityFactor = humidityVal != null
        ? (humidityVal / 100.0).clamp(0.08, 1.0)
        : 0.0;
    final double windFactor = windVal != null
        ? (windVal / 60.0).clamp(0.10, 1.0)
        : 0.0;

    return TacticalPressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WeatherScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: TacticalStyles.glassCardDecoration(
          radius: 16,
          borderColor: hazardous
              ? TacticalStyles.kPrimaryContainer.withOpacity(0.45)
              : null,
          glowColor: statusColor,
        ),
        child: Column(
          children: [
            // Top Specular Highlight Refraction Strip
            Container(
              height: 1.2,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.26),
                    statusColor.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLoading
                        ? Icons.cloud_sync_outlined
                        : (hazardous
                            ? Icons.thunderstorm_outlined
                            : Icons.cloud_done_outlined),
                    color: statusColor,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            titleText,
                            style: TacticalStyles.headline(
                              color: TacticalStyles.kOnSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText,
                              style: TacticalStyles.labelMicro(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: TacticalStyles.body(
                          color: TacticalStyles.kOnSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.north_east_rounded,
                          color: TacticalStyles.kPrimaryContainer,
                          size: 17,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isLoading
                              ? '--°'
                              : '${_weatherAlert!.temperature.toInt()}°',
                          style: TacticalStyles.headline(
                            color: TacticalStyles.kPrimaryContainer,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'ISI İNDEKSİ',
                      style: TacticalStyles.labelMicro(
                        color: TacticalStyles.kOutline,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Weather Vector Telemetry Strips (Basınç / Nem / Rüzgar)
            Row(
              children: [
                Expanded(
                  child: _buildWeatherVectorStrip(
                    label: 'BASINÇ',
                    icon: Icons.speed_rounded,
                    iconColor: TacticalStyles.kTertiary,
                    value: pressureVal != null ? '$pressureVal' : '--',
                    unit: 'hPa',
                    progress: pressureFactor,
                    barColor: TacticalStyles.kTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWeatherVectorStrip(
                    label: 'NEM',
                    icon: Icons.water_drop_outlined,
                    iconColor: TacticalStyles.kSecondary,
                    value: humidityVal != null ? '$humidityVal' : '--',
                    unit: '%',
                    progress: humidityFactor,
                    barColor: TacticalStyles.kSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWeatherVectorStrip(
                    label: 'RÜZGAR',
                    icon: Icons.air_rounded,
                    iconColor: TacticalStyles.kPrimary,
                    value: windVal != null ? '$windVal' : '--',
                    unit: 'km/h',
                    progress: windFactor,
                    barColor: TacticalStyles.kPrimary,
                  ),
                ),
              ],
            ),
            if (!isLoading && _weatherAlert!.hazardProximity != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: TacticalStyles.kPrimaryContainer.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: TacticalStyles.kPrimaryContainer.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      color: TacticalStyles.kPrimaryContainer,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'YAKIN BÖLGE UYARISI: ${_weatherAlert!.hazardProximity}',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kPrimary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherVectorStrip({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required double progress,
    required Color barColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TacticalStyles.labelMicro(
                  color: TacticalStyles.kOutline,
                  fontSize: 9,
                ),
              ),
              Icon(icon, color: iconColor, size: 14),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TacticalStyles.headline(
                  color: TacticalStyles.kOnSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  unit,
                  style: TacticalStyles.labelMicro(
                    color: TacticalStyles.kOutline,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TacticalAnimatedBar(
            factor: progress,
            color: barColor,
            height: 4.5,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color color = TacticalStyles.kPrimaryContainer,
  }) {
    return Expanded(
      child: TacticalPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.18)
                : TacticalStyles.kSurfaceContainer.withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? color : TacticalStyles.kGlassBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? color : TacticalStyles.kOnSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TacticalStyles.labelMicro(
                  color: active ? TacticalStyles.kOnSurface : TacticalStyles.kOnSurfaceVariant,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterCell({
    required IconData icon,
    required String label,
    required String value,
    Color color = Colors.white,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withOpacity(0.75), size: 14),
          const SizedBox(height: 4),
          Text(
            value,
            style: TacticalStyles.telemetry(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TacticalStyles.labelMicro(
              color: TacticalStyles.kOnSurfaceVariant,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.white10);
  }

  void _showSupportTicketDialog() {
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'Hata Bildirimi';
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: TacticalStyles.kSurfaceLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Destek & Hata Bildir', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: TacticalStyles.kSurfaceLowest,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'Hata Bildirimi', child: Text('Hata Bildirimi')),
                    DropdownMenuItem(value: 'Öneri / İstek', child: Text('Öneri / İstek')),
                    DropdownMenuItem(value: 'Hesap / Destek', child: Text('Hesap / Destek')),
                  ],
                  onChanged: (v) => setD(() => category = v ?? 'Hata Bildirimi'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: TacticalStyles.kSurfaceLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subjectCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Konu başlığı...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: TacticalStyles.kSurfaceLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Detaylı açıklama yazın...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: TacticalStyles.kSurfaceLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TacticalStyles.kPrimaryContainer),
              onPressed: sending
                  ? null
                  : () async {
                      final subj = subjectCtrl.text.trim();
                      final msg = msgCtrl.text.trim();
                      if (subj.isEmpty || msg.isEmpty) return;
                      setD(() => sending = true);
                      try {
                        final u = FirebaseAuth.instance.currentUser;
                        final uName = (await StorageHelper.getUserName() ?? u?.displayName ?? 'Operatör').trim();
                        await FirebaseFirestore.instance.collection('support_tickets').add({
                          'userId': u?.uid ?? '',
                          'userName': uName,
                          'userEmail': u?.email ?? '',
                          'category': category,
                          'subject': subj,
                          'message': msg,
                          'status': 'AÇIK',
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ Destek talebiniz yöneticiye iletildi.'), backgroundColor: Color(0xFF2E7D32)),
                          );
                        }
                      } catch (e) {
                        setD(() => sending = false);
                      }
                    },
              child: Text(sending ? 'GÖNDERİLİYOR...' : 'GÖNDER', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  const _MiniSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double endX = size.width - 4;
    final double endY = size.height * 0.18;
    final path = Path()
      ..moveTo(0, size.height * 0.85)
      ..quadraticBezierTo(
          size.width * 0.25, size.height * 0.75, size.width * 0.45, size.height * 0.42)
      ..quadraticBezierTo(
          size.width * 0.72, size.height * 0.15, endX, endY);

    final fillPath = Path.from(path)
      ..lineTo(endX, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.26),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Live Telemetry Beacon Node at the tip of the elevation curve
    final glowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(endX, endY), 6.0, glowPaint);

    final corePaint = Paint()..color = TacticalStyles.kOnSurface;
    canvas.drawCircle(Offset(endX, endY), 2.8, corePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CompassBezelPainter extends CustomPainter {
  const _CompassBezelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2.5;

    // 24 derece çentiği (her 15°)
    for (int i = 0; i < 24; i++) {
      final angle = i * (2 * math.pi / 24) - math.pi / 2;
      final isCardinal = i % 6 == 0;
      final isMajor = i % 2 == 0;
      final tickLen = isCardinal ? 4.5 : (isMajor ? 3.0 : 1.8);
      final paint = Paint()
        ..color = isCardinal
            ? Colors.white.withOpacity(0.65)
            : Colors.white.withOpacity(isMajor ? 0.28 : 0.14)
        ..strokeWidth = isCardinal ? 1.4 : 0.9
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(
        center.dx + (radius - tickLen) * math.cos(angle),
        center.dy + (radius - tickLen) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, paint);
    }

    // Üst sabit kerteriz işaretçisi (Cyan)
    final lubberPath = Path()
      ..moveTo(center.dx, 1.0)
      ..lineTo(center.dx - 3.0, 5.2)
      ..lineTo(center.dx + 3.0, 5.2)
      ..close();
    canvas.drawPath(
      lubberPath,
      Paint()..color = TacticalStyles.kSecondary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniGyroRingPainter extends CustomPainter {
  const _MiniGyroRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final needleLen = size.width / 2 - 9.5;

    // Kuzey iğnesi (parlak turuncu-kırmızı)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - needleLen)
      ..lineTo(center.dx - 4.2, center.dy)
      ..lineTo(center.dx + 4.2, center.dy)
      ..close();

    // Hafif parlama
    canvas.drawPath(
      northPath,
      Paint()
        ..color = TacticalStyles.kPrimaryContainer.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      northPath,
      Paint()..color = TacticalStyles.kPrimaryContainer,
    );

    // Güney iğnesi (soğuk cam grisi)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + needleLen)
      ..lineTo(center.dx - 3.8, center.dy)
      ..lineTo(center.dx + 3.8, center.dy)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()..color = Colors.white.withOpacity(0.32),
    );

    // Merkez pivot halkası
    canvas.drawCircle(
      center,
      3.4,
      Paint()..color = const Color(0xFF181920),
    );
    canvas.drawCircle(
      center,
      3.4,
      Paint()
        ..color = Colors.white.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      center,
      1.3,
      Paint()..color = TacticalStyles.kPrimaryContainer,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
