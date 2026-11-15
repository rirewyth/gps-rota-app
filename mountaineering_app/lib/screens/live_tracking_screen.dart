import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import '../utils/location_permission_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_sync_service.dart';
import '../services/premium_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'notification_screen.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import '../services/tactical_styles.dart';

const Color kOrange = TacticalStyles.kPrimaryContainer;
const Color kBackground = TacticalStyles.kSurface;
const Color kCardBg = TacticalStyles.kSurfaceLow;
const Color kGreen = TacticalStyles.kTertiary;

class LiveTrackingScreen extends StatefulWidget {
  final bool autoStart;
  const LiveTrackingScreen({Key? key, this.autoStart = false}) : super(key: key);

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  fm.MapController? _mapController;
  mbx.MapboxMap? _mapboxMap;
  mbx.PolylineAnnotationManager? _polylineAnnotationManager;
  mbx.CircleAnnotationManager? _pointAnnotationManager;
  bool _mapReady = false;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isVoiceNavEnabled = true;
  final AudioPlayer _sirenPlayer = AudioPlayer(); // Persistent player for siren

  // Premium Harita Katmanları
  String _selectedMapLayer = 'Topografik';
  String _mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  bool _isPremiumUser = false;
  bool _isHighDetailTerrain = false;
  
  
  bool _isTracking = false;
  bool _isSOS = false;
  List<ll.LatLng> _routePoints = [];
  List<ll.LatLng> _aktifRotaNoktalar = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  Timer? _timer;
  int _secondsElapsed = 0;
  double _totalDistance = 0; // meters
  double _elevationGain = 0; // meters
  double _maxAltitude = 0;
  int _steps = 0;
  
  Position? _lastRecordedPosition;
  DateTime? _lastOffRouteWarningTime;
  
  // Altitude Warnings
  double _lastWarningAltitude = 0;
  bool _criticalWarningGiven = false;

  // Sesli Kilometre & İrtifa Koçu (Audio Pace Coach)
  bool _audioCoachEnabled = true;
  int _lastAnnouncedKm = 0;
  int _lastAnnouncedElevStep = 0;

  void _checkAudioPaceCoach(double altitude) {
    if (!_audioCoachEnabled) return;
    final currentKm = (_totalDistance / 1000).floor();
    if (currentKm >= 1 && currentKm > _lastAnnouncedKm) {
      _lastAnnouncedKm = currentKm;
      _speak(
        '$currentKm kilometre tamamlandı. Mevcut rakım ${altitude.toInt()} metre. Toplam tırmanış ${_elevationGain.toInt()} metre.',
      );
      return;
    }
    final currentElevStep = (_elevationGain / 250).floor();
    if (currentElevStep >= 1 && currentElevStep > _lastAnnouncedElevStep) {
      _lastAnnouncedElevStep = currentElevStep;
      _speak(
        '${currentElevStep * 250} metre tırmanış kazanımı aşıldı. Mevcut rakım ${altitude.toInt()} metre.',
      );
    }
  }

  // New features
  bool _isPaused = false;
  DateTime? _lastSyncTime;
  DateTime? _lastAnnotationUpdate; // Mapbox annotation throttle (iOS bellek tasarrufu)
  bool _isLocationLocked = true; // Konum kilidi
  static const int _maxRoutePoints = 300; // Bellek sınırı (iOS için kritik)

  // Premium: Otomatik Hareketsizlik SOS (Dead Man's Switch)
  bool _deadMansSwitchEnabled = false;
  int _inactivityLimitMinutes = 15;
  DateTime _lastMovementAt = DateTime.now();
  ll.LatLng? _lastMovementAnchor;
  Timer? _inactivityCheckTimer;
  bool _inactivityAlertShowing = false;

  void _recordMovementForDeadMansSwitch(Position pos) {
    if (!_deadMansSwitchEnabled) return;
    final current = ll.LatLng(pos.latitude, pos.longitude);
    if (_lastMovementAnchor == null) {
      _lastMovementAnchor = current;
      _lastMovementAt = DateTime.now();
      return;
    }
    final movedMeters = const ll.Distance().as(
      ll.LengthUnit.Meter,
      _lastMovementAnchor!,
      current,
    );
    if (movedMeters >= 15.0) {
      _lastMovementAnchor = current;
      _lastMovementAt = DateTime.now();
    }
  }

  void _toggleDeadMansSwitch() {
    if (!_isPremiumUser) {
      PremiumService.showPremiumRequired(
        context,
        'Otomatik Hareketsizlik SOS (Dead Man\'s Switch)',
      );
      return;
    }

    if (_deadMansSwitchEnabled) {
      _inactivityCheckTimer?.cancel();
      _inactivityCheckTimer = null;
      setState(() => _deadMansSwitchEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hareketsizlik Koruması (Auto-SOS) kapatıldı.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_moon_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'HAREKETSİZLİK KORUMASI (PRO)',
                    style: TextStyle(
                      color: TacticalStyles.kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Belirlenen süre boyunca 15 metreden fazla hareket algılanmazsa 30 saniyelik onay penceresi açılır; yanıt verilmezse otomatik SOS tetiklenir.',
                style: TextStyle(color: TacticalStyles.kTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [10, 15, 30].map((mins) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TacticalStyles.kPrimaryContainer,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _activateDeadMansSwitch(mins);
                        },
                        child: Text('$mins dk', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _activateDeadMansSwitch(int minutes) {
    _inactivityCheckTimer?.cancel();
    setState(() {
      _inactivityLimitMinutes = minutes;
      _deadMansSwitchEnabled = true;
      _lastMovementAt = DateTime.now();
      if (_currentPosition != null) {
        _lastMovementAnchor = ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      }
    });
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_deadMansSwitchEnabled || !_isTracking || _isPaused || _inactivityAlertShowing) {
        return;
      }
      final idleMinutes = DateTime.now().difference(_lastMovementAt).inMinutes;
      if (idleMinutes >= _inactivityLimitMinutes) {
        _showDeadMansSwitchCountdown();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hareketsizlik Koruması aktif ($minutes dk).'),
        backgroundColor: TacticalStyles.kTertiary,
      ),
    );
  }

  void _showDeadMansSwitchCountdown() {
    _inactivityAlertShowing = true;
    int secondsLeft = 30;
    Timer? countdownTimer;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) {
              t.cancel();
              return;
            }
            if (secondsLeft <= 1) {
              t.cancel();
              Navigator.of(ctx).pop();
              _inactivityAlertShowing = false;
              if (!_isSOS) {
                _toggleSOS();
              }
            } else {
              setDialogState(() => secondsLeft--);
            }
          });
          return AlertDialog(
            backgroundColor: TacticalStyles.kSurfaceLow,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hareketsizlik Tespit Edildi',
                    style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              '$_inactivityLimitMinutes dakikadır hareket algılanmadı.\n$secondsLeft saniye içinde onay verilmezse otomatik SOS başlatılacak.',
              style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: TacticalStyles.kTertiary),
                onPressed: () {
                  countdownTimer?.cancel();
                  _lastMovementAt = DateTime.now();
                  _inactivityAlertShowing = false;
                  Navigator.of(ctx).pop();
                },
                child: const Text('İYİYİM, DEVAM ET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      countdownTimer?.cancel();
      _inactivityAlertShowing = false;
    });
  }

  void _checkAltitudeWarnings(double altitude) {
    if (!_isPremiumUser) return; // AMS Uyarıları sadece Premium üyeler içindir

    if (altitude >= 3200 && !_criticalWarningGiven) {
      _criticalWarningGiven = true;
      _showAltitudeWarning("KRİTİK İRTİFA (3200m+)", "Hava çok inceldi, dinlenmelisin. Oksijen seviyesi azalıyor!");
      _speak("Kritik İrtifa! Oksijen seviyesi azalıyor. Lütfen durumu değerlendirin.");
    }

    int currentLevel = (altitude / 500).floor() * 500;
    if (currentLevel >= 500 && currentLevel > _lastWarningAltitude) {
      _lastWarningAltitude = currentLevel.toDouble();
      _showAltitudeWarning("İRTİFA UYARISI ($currentLevel m)", "Her 100m'de sıcaklık 1 derece düşer. Soğuğa karşı hazırlıklı olun!");
      _speak("İrtifa Uyarısı. Yükseklik $currentLevel metre. Hava sıcaklığı düşebilir.");
    } else if (currentLevel < _lastWarningAltitude) {
      _lastWarningAltitude = currentLevel.toDouble();
    }
  }

  void _showAltitudeWarning(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
      backgroundColor: Colors.redAccent.shade700,
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
  
  @override
  void initState() {
    super.initState();
    _mapController = fm.MapController();
    _initTts();
    _initGps();
    if (mounted) _loadAktifRota();
    _checkPremium();
    if (widget.autoStart) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_isTracking) {
          _startTracking();
        }
      });
    }
    // Rota değişince (silindi/eklendi) canlı haritayı güncelle
    DatabaseHelper.rotaUpdateNotifier.addListener(_onRotaGuncellendi);
    _startCommandListener();
  }

  void _startCommandListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('commands')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final command = doc['command'];
        if (command == 'siren') {
          // SİREN ÇAL - Robust implementation
          try {

            await _sirenPlayer.setLoopMode(LoopMode.one);
            await _sirenPlayer.setAsset('assets/audio/siren.mp3');
            _sirenPlayer.play();
          } catch (e) {
            debugPrint("Siren play error: $e");
          }
          
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(duration: 3000, amplitude: 255); // 3 saniye güçlü titreşim
          }
          
          // Komutu 'completed' yap ki tekrar çalmasın
          doc.reference.update({'status': 'completed'});
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('⚠️ ADMİNDEN SİREN KOMUTU ALINDI!'),
              backgroundColor: Colors.redAccent,
            ));
          }
        }
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    if (!_isVoiceNavEnabled) return;
    if (!_isPremiumUser) return;
    await _flutterTts.speak(text);
  }

  Future<void> _checkPremium() async {
    final isPrem = await PremiumService.isPremium();
    if (mounted) setState(() => _isPremiumUser = isPrem);
  }

  Future<void> _loadAktifRota() async {
    final rota = await DatabaseHelper.instance.aktifRotaGetir();
    if (mounted) {
      setState(() {
        if (rota != null && rota['noktalar'] != null) {
          final List noktalar = rota['noktalar'];
          _aktifRotaNoktalar = noktalar.map((n) => ll.LatLng(n['lat'], n['lng'])).toList();
        } else {
          _aktifRotaNoktalar = [];
        }
      });
      // Eğer harita zaten hazırsa hemen çiz
      if (_mapReady) {
        _updateMapboxAnnotations();
      }
    }
  }

  
  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await LocationPermissionHelper.checkAndRequestLocationPermission(context);
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    
    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = pos);
      if (_isLocationLocked) {
        if (_isPremiumUser && _mapReady && _mapboxMap != null) {
          try {
            _mapboxMap?.setCamera(mbx.CameraOptions(
              center: mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude)),
              zoom: 16.0,
            ));
            _updateMapboxAnnotations();
          } catch (_) {}
        } else if (!_isPremiumUser && _mapController != null) {
          try {
            _mapController?.move(ll.LatLng(pos.latitude, pos.longitude), 16.0);
          } catch (_) {}
        }
      }
    }
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: Platform.isIOS
          ? AppleSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
              pauseLocationUpdatesAutomatically: false,
              showBackgroundLocationIndicator: true,
              activityType: ActivityType.fitness,
              allowBackgroundLocationUpdates: true,
            )
          : AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
              intervalDuration: const Duration(seconds: 5),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: "Rota+ Canlı Takip",
                notificationText: "Konumunuz arka planda kaydediliyor ve paylaşılıyor.",
                notificationIcon: AndroidResource(name: 'ic_notification'),
                enableWakeLock: true,
                setOngoing: true,
              ),
            ),
    ).listen((pos) async {
      if (!mounted) return;

      // ── 1. UI GÜNCELLEMESI (setState senkron, hızlı) ──────────────────────
      setState(() {
        _currentPosition = pos;

        if (_isTracking && !_isPaused) {
          if (_lastRecordedPosition != null) {
            double dist = Geolocator.distanceBetween(
              _lastRecordedPosition!.latitude, _lastRecordedPosition!.longitude,
              pos.latitude, pos.longitude,
            );
            if (dist > 5) {
              _totalDistance += dist;
              _steps = (_totalDistance / 0.75).round();

              double altDiff = pos.altitude - _lastRecordedPosition!.altitude;
              if (altDiff > 0) _elevationGain += altDiff;
              if (pos.altitude > _maxAltitude) _maxAltitude = pos.altitude;

              _routePoints.add(ll.LatLng(pos.latitude, pos.longitude));
              _lastRecordedPosition = pos;

              // iOS bellek tasarrufu: liste sınırını aş arsa en eski noktaları at
              if (_routePoints.length > _maxRoutePoints) {
                _routePoints.removeRange(0, _routePoints.length - _maxRoutePoints);
              }
            }
          } else {
            _lastRecordedPosition = pos;
            _routePoints.add(ll.LatLng(pos.latitude, pos.longitude));
          }
        }
      });

      // ── 2. ASYNC İŞLEMLER (setState dışında — iOS çakışmasını önler) ──────

      // Rota sapma uyarısı
      if (_isTracking && !_isPaused && _aktifRotaNoktalar.isNotEmpty) {
        final noktalarList = _aktifRotaNoktalar
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList();
        final nearest = DatabaseHelper.enYakinRotaNoktasi(
            pos.latitude, pos.longitude, noktalarList);
        if (nearest != null) {
          double distToRoute = Geolocator.distanceBetween(
              pos.latitude, pos.longitude, nearest['lat'], nearest['lng']);
          if (distToRoute > 50) {
            final warnNow = DateTime.now();
            if (_lastOffRouteWarningTime == null ||
                warnNow.difference(_lastOffRouteWarningTime!).inSeconds > 60) {
              _lastOffRouteWarningTime = warnNow;
              if (mounted) {
                _showAltitudeWarning(
                  "ROTADAN SAPMA (${distToRoute.toInt()}m)",
                  "Planlanan rotadan uzaklaştınız. Lütfen yönünüzü kontrol edin.",
                );
              }
              _speak("Dikkat! Rotadan saptınız. Planlanan rotadan uzaklaşıyorsunuz.");
            }
          }
        }
      }

      // İrtifa uyarısı ve Sesli Kilometre / İrtifa Koçu
      if (_isTracking && !_isPaused) {
        _checkAltitudeWarnings(pos.altitude);
        _checkAudioPaceCoach(pos.altitude);
        _recordMovementForDeadMansSwitch(pos);
        CloudSyncService.syncLocation(
            pos.latitude, pos.longitude, pos.altitude, DateTime.now().toIso8601String());
      }

      // ── 3. FİRESTORE SYNC (30 saniyede bir — async, ayrı) ─────────────────
      final now = DateTime.now();
      if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds >= 30) {
        _lastSyncTime = now;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final battery = await Battery().batteryLevel;
            if (!mounted) return;

            List trail = [];
            if (_isTracking && !_isPaused) {
              trail = _routePoints.map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
                'timestamp': DateTime.now().toIso8601String(),
              }).toList();
              // Firestore'a gönderilecek max 200 nokta
              if (trail.length > 200) trail = trail.sublist(trail.length - 200);
            }

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'last_lat': pos.latitude,
              'last_lng': pos.longitude,
              'last_elevation': pos.altitude.toInt(),
              'battery_level': battery,
              'signal_strength': 'GÜÇLÜ',
              'last_seen': FieldValue.serverTimestamp(),
              'is_recording': _isTracking,
              'live_trail': trail,
              if (_aktifRotaNoktalar.isNotEmpty)
                'planned_route': _aktifRotaNoktalar
                    .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                    .toList(),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }

      // ── 4. HARİTA GÜNCELLEME (throttle: 3 saniyede bir — GPU/CPU baskısı azaltır) ──
      if (!mounted) return;
      final mapNow = DateTime.now();
      final shouldUpdateAnnotations = _lastAnnotationUpdate == null ||
          mapNow.difference(_lastAnnotationUpdate!).inSeconds >= 3;

      if (_isPremiumUser && _mapReady && _mapboxMap != null) {
        try {
          if (_isLocationLocked) {
            _mapboxMap?.setCamera(mbx.CameraOptions(
              center: mbx.Point(
                  coordinates: mbx.Position(pos.longitude, pos.latitude)),
              zoom: 16.0,
            ));
          }
          if (shouldUpdateAnnotations) {
            _lastAnnotationUpdate = mapNow;
            _updateMapboxAnnotations();
          }
        } catch (_) {}
      } else if (!_isPremiumUser && _mapController != null) {
        try {
          if (_isLocationLocked) {
            _mapController?.move(ll.LatLng(pos.latitude, pos.longitude), 16.0);
          }
        } catch (_) {}
      }
    });
  }

  void _onMapCreated(mbx.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polylineAnnotationManager = await _mapboxMap?.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager = await _mapboxMap?.annotations.createCircleAnnotationManager();
    
    // Pusulayı SOL ÜST köşeye taşı (SOS Butonuyla çakışmaması için)
    _mapboxMap?.compass.updateSettings(mbx.CompassSettings(
      position: mbx.OrnamentPosition.TOP_LEFT,
      marginTop: 50, // Saat/Bildirim çubuğunun altına denk gelmesi için
    ));

    // 3D Terrain Aktif Etme
    try {
      await _mapboxMap?.style.setProjection(mbx.StyleProjection(name: mbx.StyleProjectionName.globe));
      // Terrain Kaynağını Ekle
      await _mapboxMap?.style.addSource(mbx.RasterDemSource(id: "mapbox-dem", url: "mapbox://mapbox.mapbox-terrain-dem-v1"));
      await _mapboxMap?.style.setStyleTerrainProperty("source", "mapbox-dem");
      await _mapboxMap?.style.setStyleTerrainProperty("exaggeration", _isHighDetailTerrain ? 2.5 : 1.2);
    } catch (e) {
      debugPrint("Mapbox Terrain Error: $e");
    }

    if (mounted) {
      setState(() => _mapReady = true);
      if (_currentPosition != null) {
        _mapboxMap?.setCamera(mbx.CameraOptions(
          center: mbx.Point(coordinates: mbx.Position(_currentPosition!.longitude, _currentPosition!.latitude)),
          zoom: 15.0,
        ));
      }
      // Harita hazır olduğunda rotayı çiz
      _updateMapboxAnnotations();
    }
  }

  void _updateMapboxAnnotations() async {
    if (_polylineAnnotationManager == null || _pointAnnotationManager == null) return;

    // Temizle
    await _polylineAnnotationManager?.deleteAll();
    await _pointAnnotationManager?.deleteAll();

    // Aktif Rota (Planlanan) - Sadece takip aktifken göster
    if (_aktifRotaNoktalar.isNotEmpty && _isTracking) {
      final line = mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(coordinates: _aktifRotaNoktalar.map((p) => mbx.Position(p.longitude, p.latitude)).toList()),
        lineColor: Colors.blueAccent.value,
        lineWidth: 6.0,
        lineOpacity: 0.6,
      );
      await _polylineAnnotationManager?.create(line);
    }

    // İzlenen Rota (Gerçekleşen)
    if (_routePoints.isNotEmpty) {
      final line = mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(coordinates: _routePoints.map((p) => mbx.Position(p.longitude, p.latitude)).toList()),
        lineColor: kOrange.value,
        lineWidth: 5.0,
      );
      await _polylineAnnotationManager?.create(line);
    }

    // Mevcut Konum İşaretçisi
    if (_currentPosition != null) {
      final marker = mbx.CircleAnnotationOptions(
        geometry: mbx.Point(coordinates: mbx.Position(_currentPosition!.longitude, _currentPosition!.latitude)),
        circleRadius: 8.0,
        circleColor: Colors.blueAccent.value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      );
      await _pointAnnotationManager?.create(marker);
    }
  }
  
  void _startTracking() async {
    setState(() {
      _isTracking = true;
      _secondsElapsed = 0;
      _totalDistance = 0;
      _elevationGain = 0;
      _steps = 0;
      _routePoints.clear();
      // Başlangıçta irtifayı mevcut konumdan al ama rotaya ekleme (ilk GPS noktasını bekle)
      _maxAltitude = _currentPosition?.altitude ?? 0;
    });

    // Notify Web Admin Panel that tracking has started
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'is_recording': true,
          'start_time': FieldValue.serverTimestamp(),
          'live_trail': [], // Önceki izleri temizle ki yeni yürüyüş tertemiz başlasın
          if (_aktifRotaNoktalar.isNotEmpty)
            'planned_route': _aktifRotaNoktalar.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    _speak("Canlı takip başlatıldı. İyi yürüyüşler.");
    
    // NOT: _currentPosition'ı hemen eklemiyoruz, çünkü eski/uzak bir nokta olabilir.
    // İlk taze GPS noktası GPS stream'den geldiğinde otomatik olarak _routePoints'e eklenecek.
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isTracking && !_isPaused) {
        setState(() => _secondsElapsed++);
      }
    });
  }
  
  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _speak("Takip duraklatıldı. Mola veriliyor.");
    } else {
      _speak("Takip devam ediyor. Yürüyüşe devam.");
    }
  }
  
  void _stopTracking() {
    _timer?.cancel();
    setState(() => _isTracking = false);
    _speak("Canlı takip durduruldu.");
    _showSaveDialog();
  }

  void _toggleSOS() async {
    setState(() => _isSOS = !_isSOS);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'is_sos': _isSOS,
        }, SetOptions(merge: true));

        // Global localhost admin ve mobil admin panele düşmesi için sos_alerts koleksiyonuna yaz
        if (_isSOS) {
          FirebaseFirestore.instance.collection('sos_alerts').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? 'Bilinmeyen Kullanıcı',
            'latitude': _currentPosition?.latitude ?? 0.0,
            'longitude': _currentPosition?.longitude ?? 0.0,
            'timestamp': FieldValue.serverTimestamp(),
            'active': true,
          });

          // KOMUTA MERKEZİNE (ADMIN APK) SİNYAL GÖNDER
          CloudSyncService.syncMessage(
            "CANLI KONUM: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}", 
            "LOCATION", 
            false
          );

          // EKİP BİLDİRİMİ GÖNDER (Yeni Premium Özellik)
          try {
            final myUserDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            final teamId = myUserDoc.data()?['team_id'];
            final myName = myUserDoc.data()?['name'] ?? 'Ekip Üyeniz';
            final myPic = myUserDoc.data()?['profile_pic_url'] ?? '';

            if (teamId != null && teamId.toString().isNotEmpty) {
              final membersSnap = await FirebaseFirestore.instance
                  .collection('teams')
                  .doc(teamId.toString())
                  .collection('members')
                  .get();

              for (final memberDoc in membersSnap.docs) {
                final memberUid = memberDoc.id;
                if (memberUid != user.uid) {
                  await NotificationService.sendTeamSOSNotification(
                    toUserId: memberUid,
                    fromUserId: user.uid,
                    fromUserName: myName,
                    fromUserPic: myPic,
                  );
                }
              }
            }
          } catch (e) {
            debugPrint('Team SOS broadcast error: $e');
          }
        } else {
          // SOS KAPATILDI - Tam temizlik
          FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'is_sos': false,
          });
          
          FirebaseFirestore.instance.collection('sos_alerts').doc(user.uid).delete(); // Listeden tamamen sil
        }
      } catch (e) {
        debugPrint("SOS Toggle Error: $e");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isSOS ? '🚨 ACİL DURUM AKTİF: Konumunuz ekibinizde öncelikli görünüyor!' : 'Acil Durum İptal Edildi.'),
      backgroundColor: _isSOS ? Colors.redAccent.shade700 : kBackground,
    ));
  }
  
  void _showSaveDialog() {
    final nameCtrl = TextEditingController(text: 'Sefer ${DateTime.now().toString().substring(0,10)}');
    
    // Notify Web Admin Panel that tracking has ended
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      try {
        FirebaseFirestore.instance.collection('users').doc(authUser.uid).set({
          'is_recording': false,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Seferi Kaydet', style: TextStyle(color: kOrange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Rota Adı',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kOrange)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Mesafe: ${(_totalDistance/1000).toStringAsFixed(2)} km', style: const TextStyle(color: Colors.white70)),
            Text('Süre: $_timeStr', style: const TextStyle(color: Colors.white70)),
            Text('Kazanım: ${_elevationGain.toInt()} m', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _routePoints.clear();
                _secondsElapsed = 0;
                _totalDistance = 0;
                _elevationGain = 0;
                _steps = 0;
                _lastRecordedPosition = null;
              });
            },
            child: const Text('SİL', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              if (_routePoints.length < 2) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt için yeterli veri yok.')));
                return;
              }
              
              final noktalarMap = _routePoints.map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              }).toList();
              
              await DatabaseHelper.instance.rotaKaydet(
                nameCtrl.text,
                noktalarMap,
                baslangicAdi: 'Canlı Takip Başlangıcı',
                bitisAdi: 'Canlı Takip Bitişi',
                distance: _totalDistance,
                durationSeconds: _secondsElapsed,
                elevationGain: _elevationGain,
                maxAltitude: _maxAltitude,
                steps: _steps,
                source: 'live_tracking',
              );
              
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  // Toplam mesafeyi güncelle (rozet sistemi)
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                    'total_distance': FieldValue.increment(_totalDistance),
                  }, SetOptions(merge: true));

                  // Profil Rotalar sekmesi için Firestore'a CloudSyncService üzerinden zaten eklendi.
                } catch (_) {}
              }
              
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: kGreen,
                content: Text('Rota kaydedildi!', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ));
              
              setState(() {
                _routePoints.clear();
                _secondsElapsed = 0;
                _totalDistance = 0;
                _elevationGain = 0;
                _steps = 0;
                _lastRecordedPosition = null;
              });
            },
            child: const Text('KAYDET', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
  
  String get _timeStr {
    int h = _secondsElapsed ~/ 3600;
    int m = (_secondsElapsed % 3600) ~/ 60;
    int s = _secondsElapsed % 60;
    if (h > 0) return '${h.toString()}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  void _onRotaGuncellendi() {
    if (mounted) _loadAktifRota();
  }

  void _aktifRotayiKaldir() async {
    await DatabaseHelper.instance.rotayiTemizle();
    if (mounted) {
      setState(() => _aktifRotaNoktalar = []);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aktif rota kaldırıldı.'),
        backgroundColor: Colors.white24,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  void dispose() {
    DatabaseHelper.rotaUpdateNotifier.removeListener(_onRotaGuncellendi);
    _positionStream?.cancel();
    _timer?.cancel();
    _inactivityCheckTimer?.cancel();
    _mapController?.dispose();
    _sirenPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Stat hesaplama
    String kmTxt = (_totalDistance / 1000).toStringAsFixed(2);
    String rakimTxt = _elevationGain.toInt().toString();
    String adimTxt = _steps.toString();

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: TacticalStyles.kOutlineVariant),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: TacticalStyles.kPrimaryContainer.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TacticalStyles.kPrimaryContainer.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.gps_fixed_rounded,
                color: TacticalStyles.kPrimary,
                size: 17,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
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
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: TacticalStyles.kPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'TELEMETRİ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TacticalStyles.labelMicro(
                              color: TacticalStyles.kPrimary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Gerçek Zamanlı Saha & GPS Takibi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() => _audioCoachEnabled = !_audioCoachEnabled);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _audioCoachEnabled
                          ? 'Sesli Kilometre & İrtifa Koçu Açıldı (Her 1 km / 250 m)'
                          : 'Sesli Kilometre & İrtifa Koçu Kapatıldı',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: TacticalStyles.capsuleDecoration(
                  backgroundColor: TacticalStyles.kSurfaceHigh.withOpacity(0.85),
                  borderColor: _audioCoachEnabled
                      ? TacticalStyles.kPrimary.withOpacity(0.5)
                      : TacticalStyles.kGlassBorder,
                ),
                child: Icon(
                  _audioCoachEnabled ? Icons.record_voice_over : Icons.voice_over_off,
                  size: 16,
                  color: _audioCoachEnabled ? TacticalStyles.kPrimary : TacticalStyles.kOnSurfaceVariant,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: TacticalStyles.capsuleDecoration(
                backgroundColor: TacticalStyles.kSurfaceHigh.withOpacity(0.85),
                borderColor: _isTracking
                    ? TacticalStyles.kTertiary.withOpacity(0.45)
                    : TacticalStyles.kGlassBorder,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulsingStatusIndicator(
                    color: _isTracking
                        ? TacticalStyles.kTertiary
                        : TacticalStyles.kPrimaryContainer,
                    size: 7,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isTracking ? 'KAYIT AKTİF' : 'HAZIR',
                    style: TacticalStyles.labelMicro(
                      color: _isTracking
                          ? TacticalStyles.kTertiary
                          : TacticalStyles.kOnSurface,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Removed floatingActionButton to consolidate all map controls in the Stack below
      body: Column(
        children: [
          // ÜST YARI: HARİTA 
          Expanded(
            flex: _isTracking ? 4 : 6,
            child: Stack(
              children: [
                if (_isPremiumUser)
                  mbx.MapWidget(
                    key: const ValueKey("mapbox_map"),
                    onMapCreated: _onMapCreated,
                    styleUri: mbx.MapboxStyles.OUTDOORS,
                    cameraOptions: mbx.CameraOptions(
                      center: _currentPosition != null
                          ? mbx.Point(coordinates: mbx.Position(_currentPosition!.longitude, _currentPosition!.latitude))
                          : mbx.Point(coordinates: mbx.Position(35.0, 39.0)),
                      zoom: 15.0,
                    ),
                  )
                else
                  fm.FlutterMap(
                    mapController: _mapController,
                    options: fm.MapOptions(
                      initialCenter: _currentPosition != null
                          ? ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                          : const ll.LatLng(39.0, 35.0),
                      initialZoom: 15.0,
                    ),
                    children: [
                      fm.TileLayer(
                        urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.mountaineering_app',
                        maxZoom: 22,
                        maxNativeZoom: 19,
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      // Aktif Rota (Planlanan) - Sadece takip aktifken göster
                      if (_aktifRotaNoktalar.isNotEmpty && _isTracking)
                        fm.PolylineLayer<Object>(polylines: [
                          fm.Polyline<Object>(
                            points: _aktifRotaNoktalar,
                            color: TacticalStyles.kSecondaryContainer.withOpacity(0.85),
                            strokeWidth: 6.0,
                            pattern: fm.StrokePattern.dashed(segments: [15, 15]),
                          ),
                        ]),
                      // İzlenen Rota (Gerçekleşen)
                      if (_routePoints.isNotEmpty)
                        fm.PolylineLayer<Object>(polylines: [
                          fm.Polyline<Object>(
                            points: _routePoints,
                            color: TacticalStyles.kPrimaryContainer,
                            strokeWidth: 5.0,
                          ),
                        ]),
                      // Mevcut Konum
                      if (_currentPosition != null)
                        fm.MarkerLayer(markers: [
                          fm.Marker(
                            point: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: TacticalStyles.kSecondaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: TacticalStyles.kSecondaryContainer.withOpacity(0.6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                    ],
                  ),
                // Gradient Gölge 
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [TacticalStyles.kSurface, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                
                // --- SOL ÜST: HAREKETSİZLİK KORUMASI (PRO DEAD MAN'S SWITCH) ---
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: _toggleDeadMansSwitch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _deadMansSwitchEnabled
                            ? TacticalStyles.kTertiary.withOpacity(0.18)
                            : TacticalStyles.kSurfaceLowest.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _deadMansSwitchEnabled
                              ? TacticalStyles.kTertiary
                              : Colors.amber.withOpacity(0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _deadMansSwitchEnabled ? Icons.shield_rounded : Icons.shield_moon_outlined,
                            color: _deadMansSwitchEnabled ? TacticalStyles.kTertiary : Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _deadMansSwitchEnabled
                                ? 'AUTO-SOS $_inactivityLimitMinutes DK'
                                : 'AUTO-SOS PRO',
                            style: TextStyle(
                              color: _deadMansSwitchEnabled ? TacticalStyles.kTertiary : Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- SAĞ TARAF KONTROL PANELİ (DÜZENLİ SÜTUN) ---
                Positioned(
                  top: 20,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SOS BUTONU
                      FloatingActionButton(
                        heroTag: "sos_btn",
                        backgroundColor: _isSOS
                            ? Colors.white
                            : TacticalStyles.kPrimaryContainer,
                        onPressed: _toggleSOS,
                        child: Icon(
                          Icons.share_location_rounded,
                          color: _isSOS
                              ? TacticalStyles.kErrorContainer
                              : Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // KONUM KİLİDİ BUTONU
                      FloatingActionButton(
                        heroTag: 'locationLockBtn',
                        mini: true,
                        backgroundColor: _isLocationLocked
                            ? TacticalStyles.kPrimaryContainer
                            : TacticalStyles.kSurfaceLow.withOpacity(0.95),
                        child: Icon(
                          _isLocationLocked ? Icons.my_location : Icons.location_searching, 
                          color: _isLocationLocked
                              ? Colors.white
                              : TacticalStyles.kTextPrimary, 
                          size: 20
                        ),
                        onPressed: () {
                          setState(() {
                            _isLocationLocked = !_isLocationLocked;
                          });
                          if (_isLocationLocked && _currentPosition != null) {
                            if (_isPremiumUser && _mapboxMap != null) {
                              _mapboxMap?.setCamera(mbx.CameraOptions(
                                center: mbx.Point(coordinates: mbx.Position(_currentPosition!.longitude, _currentPosition!.latitude)),
                                zoom: 16.0,
                              ));
                            } else if (!_isPremiumUser && _mapController != null) {
                              _mapController?.move(ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 16.0);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // 3D ÖN İZLEME (FLY-THROUGH)
                      if (_aktifRotaNoktalar.isNotEmpty) ...[
                        FloatingActionButton(
                          heroTag: "fly_btn",
                          backgroundColor: TacticalStyles.kPrimaryContainer,
                          onPressed: _startFlyThrough,
                          child: const Icon(Icons.auto_awesome_motion, color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // SESLİ YÖNLENDİRME TOGGLE
                      FloatingActionButton(
                        heroTag: 'soundToggleBtn',
                        mini: true,
                        backgroundColor: _isVoiceNavEnabled
                            ? TacticalStyles.kSurfaceLow.withOpacity(0.95)
                            : TacticalStyles.kErrorContainer,
                        child: Icon(
                          _isVoiceNavEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: _isVoiceNavEnabled ? TacticalStyles.kTextPrimary : Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isVoiceNavEnabled = !_isVoiceNavEnabled;
                          });
                          _speak(_isVoiceNavEnabled ? "Sesli yönlendirme açıldı." : "");
                        },
                      ),
                      const SizedBox(height: 12),

                      // KATMAN SEÇİCİ
                      FloatingActionButton(
                        heroTag: 'layerBtn1',
                        mini: true,
                        backgroundColor: TacticalStyles.kSurfaceLow.withOpacity(0.95),
                        child: const Icon(Icons.layers_rounded, color: TacticalStyles.kTextPrimary, size: 20),
                        onPressed: _showMapLayerSelector,
                      ),
                    ],
                  ),
                ),
                // Aktif Rotayı Kaldır Butonu
                if (_aktifRotaNoktalar.isNotEmpty)
                  Positioned(
                    bottom: 80,
                    left: 16,
                    child: GestureDetector(
                      onTap: _aktifRotayiKaldir,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: TacticalStyles.kSurfaceLow.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: TacticalStyles.kOutlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close_rounded, color: TacticalStyles.kError, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Rotayı Kaldır',
                              style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                                color: TacticalStyles.kTextPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // ALT YARI: DASHBOARD (TACTICAL LIQUID GLASS TELEMETRY SHEET)
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: TacticalStyles.kSurface,
                border: Border(
                  top: BorderSide(color: TacticalStyles.kGlassBorder),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Specular Highlight Strip
                  Container(
                    height: 1.2,
                    width: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          TacticalStyles.kPrimary.withOpacity(0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Ana Süre Monoliti
                  Column(
                    children: [
                      Text(
                        'OPERASYON SÜRESİ',
                        style: TacticalStyles.labelCaps(
                          color: TacticalStyles.kOutline,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeStr,
                        style: TacticalStyles.displayHero(
                          fontSize: 48,
                          color: TacticalStyles.kOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  
                  // Metrikler
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: TacticalStyles.glassCardDecoration(radius: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatBox(Icons.straighten_rounded, kmTxt, 'MESAFE (KM)'),
                        Container(width: 1, height: 36, color: TacticalStyles.kGlassBorder),
                        _buildStatBox(Icons.terrain_rounded, rakimTxt, 'İRTİFA (M)'),
                        Container(width: 1, height: 36, color: TacticalStyles.kGlassBorder),
                        _buildStatBox(Icons.directions_walk_rounded, adimTxt, 'ADIM'),
                      ],
                    ),
                  ),
                  
                  // Butonlar
                  if (!_isTracking)
                    TacticalPressable(
                      onTap: _startTracking,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              TacticalStyles.kPrimaryContainer,
                              TacticalStyles.kPrimaryContainer.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: TacticalStyles.kPrimary.withOpacity(0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: TacticalStyles.kPrimaryContainer.withOpacity(0.32),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'BAŞLAT',
                              style: TacticalStyles.headline(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Mola / Devam Butonu
                        Expanded(
                          flex: 2,
                          child: TacticalPressable(
                            onTap: _togglePause,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: _isPaused
                                    ? TacticalStyles.kPrimaryContainer
                                    : TacticalStyles.kSurfaceHigh,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isPaused
                                      ? TacticalStyles.kPrimary
                                      : TacticalStyles.kGlassBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _isPaused ? 'DEVAM ET' : 'MOLA VER',
                                  style: TacticalStyles.headline(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bitir Butonu
                        Expanded(
                          flex: 3,
                          child: TacticalPressable(
                            onTap: _stopTracking,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: TacticalStyles.kErrorContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: TacticalStyles.kError.withOpacity(0.45),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: TacticalStyles.kErrorContainer.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'TAKİBİ BİTİR',
                                  style: TacticalStyles.headline(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
  
  Widget _buildStatBox(IconData icon, String value, String unit) {
    return Column(
      children: [
        Icon(icon, color: TacticalStyles.kPrimaryContainer, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TacticalStyles.heroMetric(size: 24),
        ),
        const SizedBox(height: 3),
        Text(
          unit,
          style: TacticalStyles.monoLabel(
            color: TacticalStyles.kTextSecondary,
            size: 9.5,
          ),
        ),
      ],
    );
  }

  void _showMapLayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Harita Katmanı Seçimi', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Premium üyeler Mapbox 3D ve uydu katmanlarına erişebilir.', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kTextSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              _buildLayerOption('Topografik (Ücretsiz)', 'free', Icons.map, false),
              const SizedBox(height: 8),
              _buildLayerOption('Mapbox Outdoors (Hiking PRO)', mbx.MapboxStyles.OUTDOORS, Icons.terrain, true),
              const SizedBox(height: 8),
              _buildLayerOption('Uydu Görünümü (Premium)', mbx.MapboxStyles.SATELLITE_STREETS, Icons.satellite_alt, true),
              const SizedBox(height: 8),
              _buildLayerOption('Gece Modu (Taktiksel)', mbx.MapboxStyles.DARK, Icons.nightlight_round, true),
              const Divider(color: TacticalStyles.kOutlineVariant),
              _buildHighDetailToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerOption(String name, String url, IconData icon, bool requiresPremium) {
    bool isSelected = _selectedMapLayer == name;
    return ListTile(
      tileColor: isSelected ? kOrange.withOpacity(0.12) : TacticalStyles.kSurfaceLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? kOrange : TacticalStyles.kOutlineVariant),
      ),
      leading: Icon(icon, color: isSelected ? kOrange : TacticalStyles.kTextSecondary),
      title: Text(name, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: isSelected ? kOrange : TacticalStyles.kTextPrimary, fontWeight: FontWeight.w600)),
      trailing: requiresPremium
          ? const Icon(Icons.stars, color: Colors.amber, size: 20)
          : null,
      onTap: () {
        Navigator.pop(context);
        if (requiresPremium && !_isPremiumUser) {
           PremiumService.showPremiumRequired(context, 'Gelişmiş Mapbox Katmanları ve 3D Arazi');
           return;
        }
        setState(() {
          _selectedMapLayer = name;
          if (url == 'free') {
            // Premium olsa bile ücretsiz katmana geçmek isteyebilir
            _isPremiumUser = false; 
          } else {
             _isPremiumUser = true; // Premium özellikleri aktif et
             _mapboxMap?.loadStyleURI(url);
          }
        });
      },
    );
  }
  void _startFlyThrough() async {
    if (!_isPremiumUser) {
      PremiumService.showPremiumRequired(context, '3D Rota Ön İzleme (Fly-through)');
      return;
    }
    if (_aktifRotaNoktalar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ön izleme için aktif bir rota gereklidir.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('3D Rota Ön İzleme Başlatıldı...'),
      backgroundColor: kOrange,
      duration: Duration(seconds: 2),
    ));
    
    // Rota başını odakla
    await _mapboxMap?.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(_aktifRotaNoktalar.first.longitude, _aktifRotaNoktalar.first.latitude)),
        zoom: 16.5,
        pitch: 75.0,
        bearing: 0.0,
      ),
      mbx.MapAnimationOptions(duration: 3000),
    );
    await Future.delayed(const Duration(milliseconds: 3100));

    // Rota boyunca ilerle
    for (int i = 1; i < _aktifRotaNoktalar.length; i += (_aktifRotaNoktalar.length > 50 ? 5 : 1)) {
      if (!mounted) break;
      final p = _aktifRotaNoktalar[i];
      
      await _mapboxMap?.flyTo(
        mbx.CameraOptions(
          center: mbx.Point(coordinates: mbx.Position(p.longitude, p.latitude)),
          zoom: 16.5,
          pitch: 75.0,
        ),
        mbx.MapAnimationOptions(duration: 1500),
      );
      await Future.delayed(const Duration(milliseconds: 1600));
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ön İzleme Tamamlandı.')));
  }

  Widget _buildHighDetailToggle() {
    return ListTile(
      tileColor: _isHighDetailTerrain ? kOrange.withOpacity(0.12) : TacticalStyles.kSurfaceLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: TacticalStyles.kOutlineVariant)),
      leading: Icon(Icons.terrain, color: _isHighDetailTerrain ? kOrange : TacticalStyles.kTextSecondary),
      title: Text('YÜKSEK DETAYLI 3D ARAZİ', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: Switch(
        value: _isHighDetailTerrain,
        onChanged: (val) async {
          if (!_isPremiumUser) {
            Navigator.pop(context);
            PremiumService.showPremiumRequired(context, 'Yüksek Detaylı 3D Arazi');
            return;
          }
          setState(() => _isHighDetailTerrain = val);
          await _mapboxMap?.style.setStyleTerrainProperty("exaggeration", val ? 2.5 : 1.2);
        },
        activeColor: kOrange,
      ),
    );
  }
}
