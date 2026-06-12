import 'dart:async';
import 'dart:math' as math;
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
import 'package:audioplayers/audioplayers.dart';
import '../services/morse_service.dart';
import 'map_screen.dart';
import 'survival_guide_screen.dart';
import 'dm_list_screen.dart';
import 'ar_compass_screen.dart';
import 'mesh_network_screen.dart';
import '../services/weather_service.dart';
import '../services/radar_service.dart';
import '../services/offline_map_manager.dart';
import 'users_screen.dart';
import 'first_aid_screen.dart';
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

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);
const Color kGreen = Color(0xFF62FF4C);

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

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isTorchOn = false;
  bool _isStrobeOn = false;
  bool _isSosFlashOn = false;
  Timer? _strobeTimer;

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
    _audioPlayer.dispose();
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
                ];
                if (!isIOS) {
                  permsToRequest.add(Permission.sms);
                }
                
                Map<Permission, PermissionStatus> statuses = await permsToRequest.request();
                bool allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);
                if (!allGranted && mounted) {
                  _showMandatoryPermissionsDialog();
                }
              },
              child: const Text('KABUL ET', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  void _showMandatoryPermissionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('ZORUNLU İZİNLER EKSİK',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: const Text(
          'Uygulamanın çalışması için Konum ve Bildirim izinleri zorunludur. Lütfen ayarlardan tüm izinleri verin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await openAppSettings();
            },
            child: const Text('AYARLARI AÇ',
                style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              _checkAndRequestPermissions();
              Navigator.pop(context);
            },
            child: const Text('TEKRAR DENE',
                style: TextStyle(color: kGreen)),
          ),
        ],
      ),
    );
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
      if (mounted) setState(() => _heading = event.heading);
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
      locationSettings: AndroidSettings(
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
      backgroundColor: _extremePowerSaving ? Colors.black : kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ROTA+',
                style: TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic, letterSpacing: 2),
              ),
            ],
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: NightOpsService(),
            builder: (context, _) => IconButton(
              icon: Icon(
                Icons.track_changes,
                color: NightOpsService().isEnabled ? Colors.red : Colors.white54,
              ),
              onPressed: () async {
                final isPrem = await PremiumService.isPremium();
                if (isPrem) {
                  NightOpsService().toggle();
                } else {
                  if (mounted) {
                    PremiumService.showPremiumRequired(context, 'Night Ops (Taktiksel Kırmızı)');
                  }
                }
              },
              tooltip: 'Night Ops (Taktiksel)',
            ),
          ),
          IconButton(
            icon: Icon(
              _extremePowerSaving ? Icons.battery_charging_full : Icons.battery_saver,
              color: _extremePowerSaving ? kGreen : Colors.white38,
            ),
            onPressed: () => _togglePowerSaving(!_extremePowerSaving),
            tooltip: 'Güç Tasarrufu',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
            },
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

  // ─── ANA DASHBOARD (Görseldeki tasarım) ──────────────────────────────────
  Widget _buildMainDashboard() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppState.tr('ACİL DURUM APP'),
                        style: GoogleFonts.shareTechMono(
                          color: kOrange,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kGreen,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: kGreen, blurRadius: 4, spreadRadius: 1)],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_activeUserCount OPERATÖR AKTİF',
                            style: GoogleFonts.shareTechMono(
                              color: kGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_isPremium)
                        const Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: PulsingStatusIndicator(),
                        ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
                        },
                        child: const Icon(Icons.person_search, color: kOrange, size: 24),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DmListScreen()));
                        },
                        child: const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                           // log out or other actions
                        },
                        child: const Icon(Icons.logout, color: Colors.white38, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            
            // ── WEATHER ALERT (METEOROLOGY WARNING) ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildWeatherSection(),
            ),
            
            // ── RAKIM / İSTİKAMET KARTLARI ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildInfoCard(
                    label: AppState.tr('RAKIM'),
                    value: (_currentPosition != null && _currentPosition!.altitude.abs() > 1)
                        ? '${_currentPosition!.altitude.toInt()}'
                        : '--',
                    unit: 'M',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(
                    label: AppState.tr('İSTİKAMET'),
                    value: _heading != null
                        ? '${_heading!.toInt()}°'
                        : '--°',
                    unit: _yonKisa(_heading),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── TACTICAL TOOLS (Inactivity Sensor Toggle) ─────────────────────────
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: GestureDetector(
                 onTap: _toggleInactivitySensor,
                 child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _inactivitySensorEnabled ? kOrange.withOpacity(0.1) : kCardBg,
                      border: Border.all(color: _inactivitySensorEnabled ? kOrange : Colors.white10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _inactivitySensorEnabled ? Icons.motion_photos_on : Icons.motion_photos_off,
                          color: _inactivitySensorEnabled ? kOrange : Colors.white24,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppState.tr('HAREKETSİZLİK SENSÖRÜ'),
                                style: GoogleFonts.shareTechMono(
                                  color: _inactivitySensorEnabled ? kOrange : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                _inactivitySensorEnabled ? AppState.tr('Aktif (15 dk hareketsizlikte SOS tetikler)') : AppState.tr('Devre dışı bırakıldı'),
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _inactivitySensorEnabled,
                          activeColor: kOrange,
                          onChanged: (_) => _toggleInactivitySensor(),
                        ),
                      ],
                    ),
                 ),
               ),
            ),

            // ── CANLI HARİTA ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      if (_isPremium)
                        mbx.MapWidget(
                          key: const ValueKey("home_mapbox"),
                          onMapCreated: _onMapCreated,
                          styleUri: _isTacticalMap ? mbx.MapboxStyles.DARK : mbx.MapboxStyles.OUTDOORS,
                          cameraOptions: mbx.CameraOptions(
                            center: _currentPosition != null
                                ? mbx.Point(coordinates: mbx.Position(_currentPosition!.longitude, _currentPosition!.latitude))
                                : mbx.Point(coordinates: mbx.Position(35.0, 39.0)),
                            zoom: 14.0,
                          ),
                        )
                      else
                        fm.FlutterMap(
                          mapController: _mapController,
                          options: fm.MapOptions(
                            initialCenter: _currentPosition != null ? ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const ll.LatLng(39.0, 35.0),
                            initialZoom: 14.0,
                            onMapReady: () {
                              setState(() => _mapReady = true);
                              if (_currentPosition != null) {
                                try { _mapController.move(ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14.0); } catch (_) {}
                              }
                            },
                          ),
                          children: [
                            fm.TileLayer(
                              urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                              maxZoom: 17,
                              userAgentPackageName: 'RotaPlus_Tactical_v1.0',
                            ),
                            if (_aktifRotaPoints.isNotEmpty)
                              fm.PolylineLayer(
                                polylines: [
                                  fm.Polyline(
                                    points: _aktifRotaPoints,
                                    color: Colors.blueAccent.withOpacity(0.8),
                                    strokeWidth: 4.5,
                                    pattern: fm.StrokePattern.dashed(segments: [15, 15]),
                                  ),
                                ],
                              ),
                            if (_currentPosition != null)
                              fm.MarkerLayer(
                                markers: [
                                  fm.Marker(
                                    point: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                    width: 20,
                                    height: 20,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: kOrange,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      // CANLI TAKİP badge + AR & MESH buttons
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final isPrem = await PremiumService.isPremium();
                                if (isPrem) {
                                  setState(() => _isTacticalMap = !_isTacticalMap);
                                  _notify(_isTacticalMap ? 'TAKTİKSEL KATMAN AKTİF' : 'STANDART KATMAN');
                                } else {
                                  PremiumService.showPremiumRequired(context, 'Taktiksel Harita Katmanı');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _isTacticalMap ? kOrange : Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(Icons.layers_outlined, color: _isTacticalMap ? Colors.black : Colors.white70, size: 18),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: Colors.black87,
                              child: Text(
                                _teammates.isEmpty ? AppState.tr('CANLI TAKİP') : 'RADAR: ${_teammates.length} OP.',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArCompassScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                color: Colors.black87,
                                child: const Icon(Icons.camera_enhance, color: kOrange, size: 18),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeakARScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                color: Colors.black87,
                                child: const Icon(Icons.terrain, color: Colors.greenAccent, size: 18),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeshNetworkScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                color: Colors.black87,
                                child: const Icon(Icons.wifi_tethering, color: Colors.blueAccent, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Koordinat overlay

                      if (_currentPosition != null)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            color: Colors.black54,
                            child: Text(
                              '${_currentPosition!.latitude.toStringAsFixed(4)}N  ${_currentPosition!.longitude.toStringAsFixed(4)}E',
                              style: GoogleFonts.shareTechMono(
                                  color: kOrange, fontSize: 9),
                            ),
                          ),
                        ),
                      // Rota adı
                      if (_aktifRota != null)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            color: kCardBg.withOpacity(0.85),
                            child: Row(
                              children: [
                                const Icon(Icons.flag,
                                    color: kOrange, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  _aktifRota!['isim']
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _rotayiTemizle,
                                  child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── AD BANNER (Moved below Map) ──────────────────────────────────
            if (!_isPremium && _bannerAd != null && _isBannerAdLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  alignment: Alignment.center,
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),

            const SizedBox(height: 10),

            // ── ANLK KOORDİNAT KARTI ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(4),
                  border: const Border(
                    left: BorderSide(color: kGreen, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: kGreen, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CANLI KONUM',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(height: 3),
                          _currentPosition != null
                              ? RichText(
                                  text: TextSpan(children: [
                                    TextSpan(
                                      text: '${_currentPosition!.latitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                          color: kGreen,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace'),
                                    ),
                                    const TextSpan(
                                      text: '° N   ',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    TextSpan(
                                      text: '${_currentPosition!.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                          color: kGreen,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace'),
                                    ),
                                    const TextSpan(
                                      text: '° E',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ]),
                                )
                              : const Text('GPS SİNYALİ BEKLENİYOR...',
                                  style: TextStyle(color: Colors.white24, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Anlık Yön
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('YÖN', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                          _heading != null ? '${_heading!.toInt()}°' : '---',
                          style: const TextStyle(
                              color: kOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace'),
                        ),
                        Text(
                          _yonKisa(_heading),
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── PİL DURUMU KARTI ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    // Pil ikonu
                    Icon(
                      _isCharging
                          ? Icons.battery_charging_full
                          : Icons.battery_std,
                      color: _batteryLevel < 20
                          ? Colors.red
                          : _batteryLevel < 50
                              ? kOrange
                              : kGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GÜÇ KAYNAĞI / PİL',
                          style: GoogleFonts.shareTechMono(
                              color: Colors.white38, fontSize: 9),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '%$_batteryLevel',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _batteryLevel < 20
                              ? Colors.red
                              : kGreen.withOpacity(0.6),
                        ),
                      ),
                      child: Text(
                        _batteryLevel < 20
                            ? 'KRİTİK'
                            : _batteryLevel < 50
                                ? 'DÜŞÜK'
                                : 'OPTİMAL',
                        style: GoogleFonts.shareTechMono(
                          color: _batteryLevel < 20
                              ? Colors.red
                              : _batteryLevel < 50
                                  ? kOrange
                                  : kGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),



            const SizedBox(height: 16),

            // ── TAKTİKSEL ARAÇLAR (HİBRİT: DOĞA & ENKAZ) ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildToolButton(
                    label: 'FENER',
                    icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    active: _isTorchOn,
                    onTap: _toggleTorch,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    label: 'STROBE',
                    icon: Icons.wb_iridescent_outlined,
                    active: _isStrobeOn,
                    onTap: _toggleStrobe,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    label: 'YARDIM',
                    icon: Icons.light_mode_outlined,
                    active: _isSosFlashOn,
                    onTap: _toggleSosFlash,
                    color: kOrange,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    label: 'DEPREM',
                    icon: Icons.rss_feed,
                    active: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarthquakeFeedScreen())),
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // AI ROTA OPTİMİZASYONU (Geri Dönüş Tavsiyesi)
            if (_isOffRoute && _safeReturnPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _safeReturnPath!['icon'] == 'trending_up' ? Icons.trending_up :
                        _safeReturnPath!['icon'] == 'trending_down' ? Icons.trending_down :
                        Icons.explore,
                        color: Colors.blueAccent, size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YAPAY ZEKA ROTA TAVSİYESİ',
                              style: GoogleFonts.shareTechMono(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _safeReturnPath!['advice'],
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── HAYATTA KALMA REHBERİ GİRİŞİ ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SurvivalGuideScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, color: kOrange, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'DAVRANIŞ PROTOKOLÜ VE REHBERLER',
                        style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── DEPREM / ENKAZ MODU GİRİŞİ ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EarthquakeModuleScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'DEPREM MODU',
                        style: GoogleFonts.shareTechMono(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, color: Colors.redAccent, size: 14),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── FLAŞLI SOS BUTONU ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onLongPress: _onYardimPressed,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: kOrange,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: kOrange.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'SOS_ACİL_DURUM',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.black54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ACİL DURUM\nSOS GÖNDER',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const Text(
                              '✱',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
            Center(
              child: Text(
                'KONUMU YAYINLAMAK İÇİN 3 SANİYE BASILI TUTUN',
                style: GoogleFonts.shareTechMono(
                    color: Colors.white24, fontSize: 9),
              ),
            ),

            const SizedBox(height: 10),

            // ── ACİL DURUM PROTOKOLÜ ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: kOrange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'BİLGİ PAYLAŞIM PROTOKOLÜ',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'BİRİNCİL İLETİŞİM KİŞİSİ',
                      style: GoogleFonts.shareTechMono(
                          color: Colors.white24, fontSize: 9),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '+90 5XX XXX XXXX',
                              hintStyle: TextStyle(color: Colors.white24),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _savePhone,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.save_outlined,
                                color: kOrange, size: 18),
                          ),
                        ),
                      ],
                    ),
                    if (_sosStatusMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _sosStatusMessage,
                        style: TextStyle(
                          color: _sosStatusMessage.contains('✓')
                              ? kGreen
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // TAKTİKSEL İLKYARDIM BUTONU
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FirstAidScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.medical_services, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'TAKTİKSEL İLKYARDIM SİHİRBAZI',
                              style: GoogleFonts.shareTechMono(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
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

  // ── YARDIM AKTİF SAYFASI ─────────────────────────────────────────
  Widget _buildYardimActivePage() {
    return SafeArea(
      child: Container(
        color: kBackground,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // SOS Flaş İkonu
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                      width: 2),
                ),
                child: Center(
                  child: Text(
                    'SOS',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
                  const SizedBox(height: 24),

                  Text(
                    'YARDIM ÇAĞRISI AKTİF',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'GÖZLEMCİYE KONUM İLETİLİYOR',
                    style: GoogleFonts.shareTechMono(
                        color: Colors.white38, fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  if (MorseService.isPulsing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: kOrange),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on, color: kOrange, size: 14),
                          const SizedBox(width: 6),
                          Text('FİZİKSEL SOS_FLAŞ AKTİF',
                              style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 40),

                  // Geri Sayım
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      border: Border.all(
                          color: Colors.red.withOpacity(0.3), width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'OTOMATİK GÜNCELLEME DÖNGÜSÜ',
                          style: GoogleFonts.shareTechMono(
                              color: Colors.white38, fontSize: 10),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_countdown',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 72,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SN',
                              style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // GPS / Konum bilgisi
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(4)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GPS_BAĞLANTISI',
                                  style: GoogleFonts.shareTechMono(
                                      color: Colors.white38, fontSize: 9)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: kGreen,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('KİLİTLENDİ',
                                      style: TextStyle(
                                          color: kGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(4)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VERİ_PAKETİ',
                                  style: GoogleFonts.shareTechMono(
                                      color: Colors.white38, fontSize: 9)),
                              const SizedBox(height: 8),
                              const Text('ŞİFRELİ_SMS',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // SOS İptal Butonu
                  GestureDetector(
                    onTap: _yardimIptal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          'ALARMI SONLANDIR',
                          style: GoogleFonts.outfit(
                              color: Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SADECE GÜVENLİ BÖLGEDE İPTAL EDİN',
                    style: GoogleFonts.shareTechMono(
                        color: Colors.white12, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  // ─── YARDIMCI WİDGETLER ───────────────────────────────────────────────────

  Widget _buildInfoCard({
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          left: BorderSide(color: kOrange, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.shareTechMono(
                color: Colors.white38, fontSize: 9, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _yonKisa(double? head) {
    if (head == null) return 'GD';
    if (head > 337.5 || head <= 22.5) return 'K';
    if (head > 22.5 && head <= 67.5) return 'KD';
    if (head > 67.5 && head <= 112.5) return 'D';
    if (head > 112.5 && head <= 157.5) return 'GD';
    if (head > 157.5 && head <= 202.5) return 'G';
    if (head > 202.5 && head <= 247.5) return 'GB';
    if (head > 247.5 && head <= 292.5) return 'B';
    if (head > 292.5 && head <= 337.5) return 'KB';
    return '---';
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

  Widget _buildWeatherSection() {
    if (_weatherAlert == null || _weatherAlert!.isLoading) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardBg,
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: kOrange),
              ),
              const SizedBox(width: 16),
              Text(
                'HAVA DURUMU SENKRONİZE EDİLİYOR...',
                style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _weatherAlert!.isHazardous ? Colors.redAccent.withOpacity(0.15) : kCardBg,
          border: Border.all(color: _weatherAlert!.isHazardous ? Colors.redAccent : Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _weatherAlert!.isHazardous ? Icons.warning_amber_rounded : Icons.cloud_queue, 
                  color: _weatherAlert!.isHazardous ? Colors.redAccent : kGreen, 
                  size: 26
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weatherAlert!.title,
                        style: GoogleFonts.shareTechMono(
                          color: _weatherAlert!.isHazardous ? Colors.redAccent : kGreen, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 13
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _weatherAlert!.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Transform.rotate(
                      angle: (_weatherAlert!.windDirection * math.pi / 180),
                      child: const Icon(Icons.arrow_upward_rounded, color: kOrange, size: 18),
                    ),
                    Text('${_weatherAlert!.windDirection.toInt()}°', style: const TextStyle(color: kOrange, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            
            // PREMIUM RADAR DATA
            if (_isPremium) ...[
              const Divider(color: Colors.white10, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRadarMiniStat(Icons.speed, '${_weatherAlert!.pressure?.toInt() ?? 1013} hPa', 'BASINÇ'),
                  _buildRadarMiniStat(Icons.water_drop, '%${_weatherAlert!.humidity?.toInt() ?? 50}', 'NEM'),
                  _buildRadarMiniStat(Icons.wind_power, '${_weatherAlert!.windSpeed.toInt()} km/h', 'RÜZGAR'),
                ],
              ),
              if (_weatherAlert!.hazardProximity != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar, color: kOrange, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'RADAR TESPİTİ: ${_weatherAlert!.hazardProximity}',
                          style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color color = const Color(0xFFFF6B00),
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.2) : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? color : Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? color : Colors.white38, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.shareTechMono(
                  color: active ? color : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
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
          Icon(icon, color: color.withOpacity(0.7), size: 14),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarMiniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white30, size: 14),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.white10);
  }
}
