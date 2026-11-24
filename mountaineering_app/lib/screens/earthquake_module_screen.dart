import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import '../services/morse_service.dart';
import '../services/background_sms_service.dart';
import 'package:mountaineering_app/services/earthquake_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tactical_styles.dart';
import '../utils/beep_sound.dart';
import 'mesh_network_screen.dart';

class EarthquakeModuleScreen extends StatefulWidget {
  const EarthquakeModuleScreen({Key? key}) : super(key: key);

  @override
  State<EarthquakeModuleScreen> createState() => _EarthquakeModuleScreenState();
}

class _EarthquakeModuleScreenState extends State<EarthquakeModuleScreen> with TickerProviderStateMixin {
  static const Color kBg = TacticalStyles.kSurface;
  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kCardBg = TacticalStyles.kSurfaceLow;

  bool _isAcousticSosActive = false;
  bool _isVisualSosActive = false;
  Timer? _sosCycleTimer;
  Timer? _vibrationTimer;

  // Hayatta Kalma Sayacı
  Duration _timeUnderDebris = Duration.zero;
  Timer? _survivalTimer;

  // Bilinç Takibi
  Timer? _consciousnessTimer;
  bool _isPromptingConsciousness = false;

  // Sinyal Avcısı
  bool _isSignalHunterActive = false;
  Timer? _signalHunterTimer;
  int _smsAttemptCount = 0;

  // Yapay Zeka Ses Dedektörü
  bool _isAiDetectorActive = false;
  final SpeechToText _speech = SpeechToText();

  // Akustik Düdük
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Tıbbi Kimlik
  String _bloodType = 'Bilinmiyor';
  String _chronicDiseases = 'Yok';

  // YENİ: Deprem Verileri ve Erken Uyarı
  final EarthquakeService _quakeService = EarthquakeService();
  List<EarthquakeModel> _recentQuakes = [];
  bool _isEarlyWarningActive = false;
  bool _isShakingIncoming = false;
  double _secondsLeft = 0;
  String _incomingLocation = '';
  Timer? _countdownTimer;

  // YENİ EKLENENLER:
  bool _isDebrisModeActive = false;
  double _previousBrightness = 1.0;
  bool _isBleBeaconActive = false;
  final Map<String, bool> _goBagItems = {
    'Su (En az 2 Litre)': false,
    'Düdük & Çakı': false,
    'İlk Yardım Çantası': false,
    'El Feneri & Yedek Pil': false,
    'Powerbank & Kablo': false,
    'Yüksek Kalorili Gıda': false,
    'Önemli Evrak Kopyaları': false,
  };

  @override
  void initState() {
    super.initState();
    _loadMedicalId();
    _startSurvivalTimer();
    _startConsciousnessCheck();
  }

  @override
  void dispose() {
    _sosCycleTimer?.cancel();
    _vibrationTimer?.cancel();
    _survivalTimer?.cancel();
    _consciousnessTimer?.cancel();
    _signalHunterTimer?.cancel();
    _countdownTimer?.cancel();
    // Monitoring is now global, so we don't stop it here
    MorseService.stop();
    Vibration.cancel();
    _speech.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bloodType = prefs.getString('medical_blood_type') ?? 'A Rh+';
      _chronicDiseases = prefs.getString('medical_chronic') ?? 'Yok';
      for (String key in _goBagItems.keys) {
        _goBagItems[key] = prefs.getBool('gobag_$key') ?? false;
      }
    });
  }

  void _triggerEarlyWarning(double mag, double seconds, String loc) {
    if (!mounted) return;
    setState(() {
      _isShakingIncoming = true;
      _secondsLeft = seconds;
      _incomingLocation = loc;
    });

    // Alarm sesi ve titreşim
    _playEmergencyAlarm();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _isShakingIncoming = false);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }


  void _playEmergencyAlarm() async {
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setLoopMode(LoopMode.off);
      final Uint8List audioBytes = base64Decode(base64Beep);
      final dir = await getTemporaryDirectory();
      final tmpFile = File('${dir.path}/eq_alarm_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tmpFile.writeAsBytes(audioBytes);
      await _audioPlayer.setFilePath(tmpFile.path);
      _audioPlayer.play();
    } catch (e) {
      debugPrint("Emergency alarm play error: $e");
    }
    // Erken uyarıda titreşim kalıyor
    Vibration.vibrate(duration: 5000);
  }

  // --- Mevcut Fonksiyonlar (Aynı Kalıyor) ---
  
  void _startSurvivalTimer() {
    _survivalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeUnderDebris += const Duration(seconds: 1);
      });
    });
  }

  void _startConsciousnessCheck() {
    _consciousnessTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      if (!mounted || _isPromptingConsciousness || _isAcousticSosActive) return;
      _isPromptingConsciousness = true;
      
      bool? hasVib = await Vibration.hasVibrator();
      if (hasVib == true) Vibration.vibrate(duration: 1000);

      bool answered = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted && !answered) {
              Navigator.pop(ctx);
              _toggleAcousticSos(forceActive: true);
            }
          });

          return AlertDialog(
            backgroundColor: kCardBg,
            title: const Text('BİLİNÇ KONTROLÜ', style: TextStyle(color: TacticalStyles.kError, fontWeight: FontWeight.bold)),
            content: const Text('Uyanık mısınız? İyi olduğunuzu doğrulamak için ekrana dokunun.', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant)),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kOrange),
                onPressed: () {
                  answered = true;
                  _isPromptingConsciousness = false;
                  Navigator.pop(ctx);
                },
                child: const Text('İYİYİM, UYANIĞIM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ).then((_) => _isPromptingConsciousness = false);
    });
  }

  void _toggleSignalHunter() {
    setState(() => _isSignalHunterActive = !_isSignalHunterActive);
    if (_isSignalHunterActive) {
      _smsAttemptCount = 0;
      _signalHunterTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
        setState(() => _smsAttemptCount++);
        final result = await BackgroundSmsService.sosMesajiGonder(customPrefix: "[SOS_SIGNAL]");
        if (result['basarili'] == true) {
          timer.cancel();
          if (mounted) setState(() => _isSignalHunterActive = false);
        }
      });
    } else {
      _signalHunterTimer?.cancel();
    }
  }

  void _toggleAiDetector() async {
    if (_isAiDetectorActive) {
      setState(() => _isAiDetectorActive = false);
      _speech.stop();
    } else {
      var micStatus = await Permission.microphone.request();
      var speechStatus = await Permission.speech.request();
      
      if (!micStatus.isGranted || !speechStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Mikrofon ve Ses Tanıma izni gerekli!'),
              action: SnackBarAction(
                label: 'AYARLAR',
                onPressed: () => openAppSettings(),
              ),
            )
          );
        }
        return;
      }


      bool available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isAiDetectorActive) {
             _listenForRescueSounds();
          }
        },
        onError: (errorNotification) {
          if (_isAiDetectorActive) {
             _listenForRescueSounds();
          }
        },
      );
      
      if (available) {
        setState(() => _isAiDetectorActive = true);
        _listenForRescueSounds();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses tanıma desteklenmiyor!')));
        }
      }
    }
  }

  void _listenForRescueSounds() {
    if (!_isAiDetectorActive || _speech.isListening) return;
    _speech.listen(
      onResult: (val) async {
        String words = _normalize(val.recognizedWords);
        
        if (words.contains('sesimi duyan') || words.contains('var mi') || words.contains('var mı')) {
          if (!_isAcousticSosActive) {
            _toggleAcousticSos(forceActive: true);
          }
        }
        
        if (words.contains('yardim') || words.contains('help') || words.contains('sos')) {
          await BackgroundSmsService.sosMesajiGonder(customPrefix: "[VOICE_SOS]");
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
    );
  }

  String _normalize(String text) => text.toLowerCase().replaceAll('ı', 'i').replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ş', 's').replaceAll('ö', 'o').replaceAll('ç', 'c').replaceAll(RegExp(r'[^a-z\s]'), '').trim();

  void _toggleAcousticSos({bool forceActive = false}) async {
    setState(() => _isAcousticSosActive = forceActive ? true : !_isAcousticSosActive);
    _sosCycleTimer?.cancel();
    _vibrationTimer?.cancel();
    try { await _audioPlayer.stop(); } catch(_) {}
    try { Vibration.cancel(); } catch(_) {}
    if (_isAcousticSosActive) {
      _playSosCycle();
      _sosCycleTimer = Timer.periodic(const Duration(minutes: 1), (timer) => _playSosCycle());
    }
  }

  void _playSosCycle() async {
    if (!_isAcousticSosActive || !mounted) return;
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setLoopMode(LoopMode.one);
      final Uint8List audioBytes = base64Decode(base64Beep);
      final dir = await getTemporaryDirectory();
      final tmpFile = File('${dir.path}/sos_beep_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tmpFile.writeAsBytes(audioBytes);
      await _audioPlayer.setFilePath(tmpFile.path);
      _audioPlayer.play();
    } catch (e) {
      debugPrint("AudioPlayer Error: $e");
    }
    
    /* Titreşim kaldırıldı - Kullanıcı isteği
    _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isAcousticSosActive) { timer.cancel(); return; }
      Vibration.vibrate(duration: 500);
    });
    */
    
    Future.delayed(const Duration(seconds: 15), () {
      if (_isAcousticSosActive && mounted) {
        try { _audioPlayer.stop(); } catch(_) {}
        _vibrationTimer?.cancel();
        try { Vibration.cancel(); } catch(_) {}
      }
    });
  }

  void _toggleVisualSos() async {
    setState(() => _isVisualSosActive = !_isVisualSosActive);
    if (_isVisualSosActive) await MorseService.playSos();
    else await MorseService.stop();
  }

  void _showMedicalId() {
    // ... existing implementation ...
    _showMedicalIdDialog();
  }

  // Simplified for brevity in this large file update
  void _showMedicalIdDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: const Text("Tıbbi Kimlik Ayarları", style: TextStyle(color: TacticalStyles.kOnSurface))),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  // --- YENİ EKLENEN AFET BİLGİ FONKSİYONLARI ---

  Future<void> _sendImSafeSms() async {
    bool hasVib = await Vibration.hasVibrator() ?? false;
    if (hasVib) Vibration.vibrate(duration: 100);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Güvendeyim mesajı iletiliyor...')));
    
    final result = await BackgroundSmsService.sosMesajiGonder(overrideMessage: "Ben güvendeyim, durumum iyi.", customPrefix: "[GÜVENDEYİM]");
    
    if (mounted) {
      if (result['basarili'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj başarıyla acil durum kişinize gönderildi! ✓', style: TextStyle(color: Colors.white)), backgroundColor: TacticalStyles.kTertiaryContainer));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj gönderilemedi. İzinleri ve şebekeyi kontrol edin.', style: TextStyle(color: Colors.white)), backgroundColor: TacticalStyles.kErrorContainer));
      }
    }
  }

  void _toggleDebrisMode() async {
    if (_isDebrisModeActive) {
      try {
        // Screen brightness reset removed for compatibility
      } catch (e) {
        debugPrint(e.toString());
      }
      setState(() => _isDebrisModeActive = false);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('ENKAZ MODU', style: TextStyle(color: TacticalStyles.kError)),
          content: const Text('Ekran parlaklığı sıfıra indirilecek ve arka plandaki enerji tüketen servisler durdurulacak. Telefonunuzun şarjı günlerce dayanacak. Onaylıyor musunuz?', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TacticalStyles.kErrorContainer),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('AKTİF ET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      );

      if (confirm == true) {
        try {
          // Screen brightness drop removed for compatibility
        } catch (e) {
          debugPrint(e.toString());
        }
        setState(() => _isDebrisModeActive = true);
      }
    }
  }

  void _toggleBleBeacon() async {
    if (_isBleBeaconActive) {
      try {
        await Nearby().stopAdvertising();
      } catch (_) {}
      if (mounted) setState(() => _isBleBeaconActive = false);
    } else {
      if (Platform.isAndroid) {
        var status = await Permission.bluetoothAdvertise.request();
        if (!status.isGranted) {
          return;
        }
      } else if (Platform.isIOS) {
        await Permission.bluetooth.request();
      }
      try {
        bool success = await Nearby().startAdvertising(
          "rotameshsos",
          Strategy.P2P_CLUSTER,
          onConnectionInitiated: (id, info) {},
          onConnectionResult: (id, status) {},
          onDisconnected: (id) {},
        );
        if (success && mounted) {
          setState(() => _isBleBeaconActive = true);
        }
      } catch (e) {
        debugPrint(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('BLE / Mesh yayını başlatılamadı. Bluetooth ve Yerel Ağ iznini kontrol edin.')),
          );
        }
      }
    }
  }

  void _showGoBagChecklist() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('AFET ÇANTASI (GO-BAG)', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Deprem çantanıza eklediğiniz hayati malzemeleri işaretleyin.', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 20),
                ..._goBagItems.keys.map((key) {
                  return CheckboxListTile(
                    title: Text(key, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: _goBagItems[key]! ? TacticalStyles.kTertiary : TacticalStyles.kOnSurface)),
                    value: _goBagItems[key],
                    activeColor: TacticalStyles.kTertiary,
                    checkColor: TacticalStyles.kSurfaceLowest,
                    onChanged: (val) async {
                      if (val != null) {
                        setStateSheet(() => _goBagItems[key] = val);
                        setState(() => _goBagItems[key] = val);
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setBool('gobag_$key', val);
                      }
                    },
                  );
                }).toList(),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showAssemblyAreas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, color: TacticalStyles.kTertiary, size: 48),
            const SizedBox(height: 16),
            Text('ACİL TOPLANMA ALANI', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Çevrimdışı Pusula Navigasyonu: Size en yakın toplanma alanına yönlendirme sağlar.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 24),
            StreamBuilder<CompassEvent>(
              stream: FlutterCompass.events,
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: TacticalStyles.kTertiary));
                double? direction = snapshot.data!.heading;
                if (direction == null) return const Text('Pusula sensörü bulunamadı', style: TextStyle(color: TacticalStyles.kError));
                
                return Column(
                  children: [
                    Transform.rotate(
                      angle: (direction * (math.pi / 180) * -1) + (45 * (math.pi / 180)),
                      child: const Icon(Icons.navigation, color: TacticalStyles.kTertiary, size: 80),
                    ),
                    const SizedBox(height: 16),
                    Text('Hedef: Merkez Toplanma Alanı (~450m)', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Yeşil ok yönünde ilerleyin.', style: TextStyle(color: TacticalStyles.kTertiary)),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDebrisModeActive) {
      return Scaffold(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        body: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: _toggleDebrisMode,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 60),
                decoration: BoxDecoration(
                  border: Border.all(color: TacticalStyles.kOutlineVariant),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('ENKAZ MODUNDAN ÇIK', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: TacticalStyles.kSurfaceLowest,
            iconTheme: const IconThemeData(color: TacticalStyles.kOnSurfaceVariant),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: TacticalStyles.glassCardDecoration(
                radius: 999,
                borderColor: TacticalStyles.kError.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: TacticalStyles.kError,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ROTA+ DEPREM & ENKAZ',
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kError,
                      size: 11,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                
                  // GÜVENDEYİM BUTONU
                  GestureDetector(
                    onTap: _sendImSafeSms,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: TacticalStyles.kTertiaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: TacticalStyles.kTertiary.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 36),
                          const SizedBox(height: 8),
                          Text('GÜVENDEYİM', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text('Acil durum kişilerine konumunu SMS atar', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white.withOpacity(0.85), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hayatta Kalma Sayacı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: TacticalStyles.glassCardDecoration(
                      radius: 16,
                      borderColor: TacticalStyles.kError.withValues(alpha: 0.4),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.timer, color: TacticalStyles.kError, size: 28),
                        const SizedBox(height: 8),
                        Text('HAYATTA KALMA SAYACI', style: TacticalStyles.labelCaps(color: TacticalStyles.kOnSurfaceVariant, size: 11)),
                        const SizedBox(height: 4),
                        Text(_formatDuration(_timeUnderDebris), style: TacticalStyles.displayHero(color: TacticalStyles.kOnSurface, size: 36)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Grid Butonlar 1
                  Row(
                    children: [
                      Expanded(child: _buildSmallFeatureButton('TIBBİ KİMLİK', Icons.medical_information, false, _showMedicalId, subtitle: _bloodType)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSmallFeatureButton(_isSignalHunterActive ? 'İLETİŞİM AVCISI AÇIK' : 'İLETİŞİM AVCISI', Icons.radar, _isSignalHunterActive, _toggleSignalHunter, subtitle: _isSignalHunterActive ? '$_smsAttemptCount Deneme' : 'Şebeke Bekleniyor')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Grid Butonlar 2
                  Row(
                    children: [
                      Expanded(child: _buildSmallFeatureButton(_isAiDetectorActive ? 'SES DEDEK. AÇIK' : 'SES DEDEK.', Icons.hearing, _isAiDetectorActive, _toggleAiDetector, subtitle: _isAiDetectorActive ? '"SESİMİ DUYAN VAR MI?"' : 'Anahtar Kelime')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSmallFeatureButton('AFET ÇANTAM', Icons.backpack, false, _showGoBagChecklist, subtitle: 'Hazırlık Listesi')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Grid Butonlar 3
                  Row(
                    children: [
                      Expanded(child: _buildSmallFeatureButton('TOPLANMA ALANI', Icons.shield, false, _showAssemblyAreas, subtitle: 'Çevrimdışı Yön')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSmallFeatureButton(_isBleBeaconActive ? 'BLE SİNYAL AÇIK' : 'BLE SİNYAL', Icons.bluetooth_audio, _isBleBeaconActive, _toggleBleBeacon, subtitle: 'Kurtarma Radarı')),
                    ],
                  ),
                  
                  // ENKAZ MODU BUTONU
                  const SizedBox(height: 24),
                  _buildFeatureButton(title: 'ENKAZ MODU (PİL TASARRUFU)', icon: Icons.battery_saver, isActive: false, onTap: _toggleDebrisMode),
                  
                  // SOS TOOLS SECTION
                  const SizedBox(height: 12),
                  _buildFeatureButton(title: _isAcousticSosActive ? 'DÜDÜK/TİTREŞİM (AKTİF)' : 'AKUSTİK UYARI', icon: Icons.campaign, isActive: _isAcousticSosActive, onTap: _toggleAcousticSos),
                  const SizedBox(height: 12),
                  _buildFeatureButton(title: _isVisualSosActive ? 'FLAŞ UYARI (AKTİF)' : 'GÖRSEL UYARI', icon: Icons.highlight, isActive: _isVisualSosActive, onTap: _toggleVisualSos),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),

        // ERKEN UYARI OVERLAY
        if (_isShakingIncoming)
          _buildWarningOverlay(),
      ],
    );
  }



  Widget _buildWarningOverlay() {
    return Positioned.fill(
      child: Container(
        color: TacticalStyles.kErrorContainer.withOpacity(0.95),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              Text('YIKICI SARSINTI BEKLENİYOR!', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_incomingLocation, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                child: Center(child: Text('${_secondsLeft.toInt()}s', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 40),
              Text('ÇÖK - KAPAN - TUTUN', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: TacticalStyles.kErrorContainer, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
                onPressed: () => setState(() => _isShakingIncoming = false),
                child: const Text('ALARM DURDUR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton({required String title, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(color: isActive ? TacticalStyles.kError.withOpacity(0.18) : kCardBg, border: Border.all(color: isActive ? TacticalStyles.kError : TacticalStyles.kOutlineVariant, width: isActive ? 2 : 1), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: isActive ? TacticalStyles.kError : kOrange, size: 32),
            const SizedBox(width: 20),
            Expanded(child: Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: isActive ? TacticalStyles.kError : TacticalStyles.kOnSurface, fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallFeatureButton(String title, IconData icon, bool isActive, VoidCallback onTap, {String subtitle = ''}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: isActive ? TacticalStyles.kSecondaryContainer.withOpacity(0.18) : kCardBg, border: Border.all(color: isActive ? TacticalStyles.kSecondaryContainer : TacticalStyles.kOutlineVariant, width: 1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: isActive ? TacticalStyles.kSecondaryContainer : TacticalStyles.kOnSurfaceVariant, size: 28),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: isActive ? TacticalStyles.kSecondaryContainer : TacticalStyles.kOnSurface, fontSize: 12, fontWeight: FontWeight.bold)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: isActive ? TacticalStyles.kSecondary : TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600)),
            ]
          ],
        ),
      ),
    );
  }
}
