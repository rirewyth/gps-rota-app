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

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);
const Color kGreen = Color(0xFF62FF4C);

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({Key? key}) : super(key: key);

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

  // New features
  bool _isPaused = false;
  DateTime? _lastSyncTime;
  DateTime? _lastAnnotationUpdate; // Mapbox annotation throttle (iOS bellek tasarrufu)
  bool _isLocationLocked = true; // Konum kilidi
  static const int _maxRoutePoints = 300; // Bellek sınırı (iOS için kritik)

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
    _loadAktifRota();
    _initGps();
    _checkPremium();
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
            await _sirenPlayer.setAudioContext(AudioContext(
              android: AudioContextAndroid(
                usageType: AndroidUsageType.alarm,
                contentType: AndroidContentType.sonification,
                audioFocus: AndroidAudioFocus.gainTransient,
              ),
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
                options: {
                  AVAudioSessionOptions.defaultToSpeaker,
                  AVAudioSessionOptions.duckOthers,
                },
              ),
            ));
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

      // İrtifa uyarısı
      if (_isTracking && !_isPaused) {
        _checkAltitudeWarnings(pos.altitude);
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
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ACİL DURUM ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
              ),
              TextSpan(
                text: 'CANLI TAKİP',
                style: TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic, letterSpacing: 2),
              ),
            ],
          ),
        ),
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
                            color: Colors.cyanAccent.withOpacity(0.8),
                            strokeWidth: 6.0,
                            pattern: fm.StrokePattern.dashed(segments: [15, 15]),
                          ),
                        ]),
                      // İzlenen Rota (Gerçekleşen)
                      if (_routePoints.isNotEmpty)
                        fm.PolylineLayer<Object>(polylines: [
                          fm.Polyline<Object>(
                            points: _routePoints,
                            color: kOrange,
                            strokeWidth: 5.0,
                          ),
                        ]),
                      // Mevcut Konum
                      if (_currentPosition != null)
                        fm.MarkerLayer(markers: [
                          fm.Marker(
                            point: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 16, height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ]),
                    ],
                  ),
                // Gradient Gölge 
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [kBackground, Colors.transparent],
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
                        backgroundColor: _isSOS ? Colors.white : Colors.redAccent.shade700,
                        onPressed: _toggleSOS,
                        child: Icon(Icons.share_location, color: _isSOS ? Colors.redAccent.shade700 : Colors.white, size: 32),
                      ),
                      const SizedBox(height: 12),
                      
                      // KONUM KİLİDİ BUTONU
                      FloatingActionButton(
                        heroTag: 'locationLockBtn',
                        mini: true,
                        backgroundColor: _isLocationLocked ? kOrange : kCardBg,
                        child: Icon(
                          _isLocationLocked ? Icons.my_location : Icons.location_searching, 
                          color: _isLocationLocked ? Colors.black : Colors.white, 
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
                          backgroundColor: kOrange,
                          onPressed: _startFlyThrough,
                          child: const Icon(Icons.auto_awesome_motion, color: Colors.black, size: 28),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // SESLİ YÖNLENDİRME TOGGLE
                      FloatingActionButton(
                        heroTag: 'soundToggleBtn',
                        mini: true,
                        backgroundColor: _isVoiceNavEnabled ? kCardBg : Colors.redAccent.withOpacity(0.8),
                        child: Icon(_isVoiceNavEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 20),
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
                        backgroundColor: kCardBg,
                        child: const Icon(Icons.layers, color: Colors.white, size: 20),
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
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, color: Colors.redAccent, size: 14),
                            SizedBox(width: 4),
                            Text('Rotayı Kaldır', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Ses Kapatma Butonu artık yukarıdaki sütunda
                // (Eski konumu temizlendi)
              ],
            ),
          ),
          
          // ALT YARI: DASHBOARD
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: kBackground,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Ana Süre
                  Column(
                    children: [
                      Text('GEÇEN SÜRE', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(
                        _timeStr,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1.0),
                      ),
                    ],
                  ),
                  
                  // Metrikler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBox(Icons.straighten, kmTxt, 'KM'),
                      Container(width: 1, height: 40, color: Colors.white10),
                      _buildStatBox(Icons.trending_up, rakimTxt, 'İRTİFA (M)'),
                      Container(width: 1, height: 40, color: Colors.white10),
                      _buildStatBox(Icons.directions_walk, adimTxt, 'ADIM'),
                    ],
                  ),
                  
                  // Butonlar
                  if (!_isTracking)
                    GestureDetector(
                      onTap: _startTracking,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: kGreen.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'BAŞLA',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Mola / Devam Butonu
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _togglePause,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: _isPaused ? kOrange : Colors.white12,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _isPaused ? kOrange : Colors.white24),
                              ),
                              child: Center(
                                child: Text(
                                  _isPaused ? 'DEVAM ET' : 'MOLA VER',
                                  style: GoogleFonts.outfit(
                                    color: _isPaused ? Colors.black : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bitir Butonu
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: _stopTracking,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.shade700,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'TAKİBİ BİTİR',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
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
        Icon(icon, color: kOrange, size: 24),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.0)),
        const SizedBox(height: 4),
        Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
              const Text('Harita Katmanı Seçimi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Premium üyeler Mapbox 3D ve uydu katmanlarına erişebilir.', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 16),
              _buildLayerOption('Topografik (Ücretsiz)', 'free', Icons.map, false),
              const SizedBox(height: 8),
              _buildLayerOption('Mapbox Outdoors (Hiking PRO)', mbx.MapboxStyles.OUTDOORS, Icons.terrain, true),
              const SizedBox(height: 8),
              _buildLayerOption('Uydu Görünümü (Premium)', mbx.MapboxStyles.SATELLITE_STREETS, Icons.satellite_alt, true),
              const SizedBox(height: 8),
              _buildLayerOption('Gece Modu (Taktiksel)', mbx.MapboxStyles.DARK, Icons.nightlight_round, true),
              const Divider(color: Colors.white10),
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
      tileColor: isSelected ? kOrange.withOpacity(0.1) : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? kOrange : Colors.white10),
      ),
      leading: Icon(icon, color: isSelected ? kOrange : Colors.white54),
      title: Text(name, style: TextStyle(color: isSelected ? kOrange : Colors.white, fontWeight: FontWeight.bold)),
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
      tileColor: _isHighDetailTerrain ? kOrange.withOpacity(0.1) : Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(Icons.terrain, color: _isHighDetailTerrain ? kOrange : Colors.white54),
      title: const Text('YÜKSEK DETAYLI 3D ARAZİ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
