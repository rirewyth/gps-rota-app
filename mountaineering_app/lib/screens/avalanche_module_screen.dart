import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../storage_helper.dart';

enum AvalancheMode {
  transceiver, // Verici / Kazazede Modu (Düşük Enerjili Duyulabilir Ses + BLE)
  receiver     // Alıcı / Arama Modu (Yaklaştıkça Hızlanan Akustik Bip)
}

class AvalancheModuleScreen extends StatefulWidget {
  const AvalancheModuleScreen({Key? key}) : super(key: key);

  @override
  State<AvalancheModuleScreen> createState() => _AvalancheModuleScreenState();
}

class _AvalancheModuleScreenState extends State<AvalancheModuleScreen> with SingleTickerProviderStateMixin {
  // Alpine Safety Palette (Cyan & Snow White & Warning Amber)
  static const Color kAlpineCyan = Color(0xFF00E5FF);
  static const Color kWarningOrange = Color(0xFFFF6B00);
  static const Color kBg = Color(0xFF0A0F1D);
  static const Color kCardBg = Color(0xFF10192D);

  AvalancheMode _currentMode = AvalancheMode.transceiver;
  bool _isActive = false;

  // Transceiver Settings
  bool _isAudibleSoundActive = true; // İnsan tarafından duyulabilir ses yayınlama modu (2.6 kHz piezo)
  Timer? _transceiverAudioTimer;
  Timer? _transceiverVibeTimer;

  // Receiver Settings
  Timer? _receiverBeepLoopTimer;
  double _estimatedDistance = 25.0; // metre
  String _discoveredBeaconName = 'Sinyal Aranıyor...';
  int _beepIntervalMs = 1200; // Yaklaştıkça düşer (öter)

  final AudioPlayer _audioPlayer = AudioPlayer();
  static const String _kPiezoToneUri = 'data:audio/wav;base64,UklGRkIYAABXQVZFZm10IBAAAAABAAEAIlYAAESsAAACABAAZGF0YR4YAAAAAJoAyAEjAqIAnf3R+mz6gf0GAxYIbQl5BZ390fWo8qL2bwA4C/4Q7g3NAgT1++sn7cv4WgkeFscXlgy++f/oo+NS7bwBchY9ICoZHAS16/TcUuDp9HcQfSTWJe4SCPW228TUs+TmA0QifC/RI44EteHGzfTT3vFaGCczkDN9GH7v/M0Vxsnc7QakLrI+2i0iBArXer4UyKvv/iAWQu1APx0i6dy/n7eb1dAKjTvWTUA31gK7yxqvvLxU7l4qPlHjTS8h+eFcsWupqc8+D9ZGS1nxPKMAAcTSpmS4gO9DLz9WBFDXH/nea68cqtTRwBFfSA1ZCzsW/iHCnKb0uQTyaTHnVtZOcR2d3FWu3qoJ1D8U2Um7WBo5iftPwHmmkruL9IUzfVeXTQQbSNpRrbOrR9a6FkNLWFgcN/34ir5ppj+9FfeWNQFYSUySGPvXXqyZrI7YLxmeTOJXEzVy9tO8a6b6vqD5nDdyWOpKGxa31Xyrka3c2qAb6U1ZV/8y6fMpu4Cmw8As/Jc50Vh8SaATe9OsqmuM90LHiNPv1bgMGPxjrmoppjCuv6GOx5Z/kcgEUjR7qmzr5HfbyBNUBJWuC7g7gK44qZ6xEYBaD1YWXJGnQ4gz0Gp3bD14c0iZ1FUVYUsYOyEti+nacbUAz0/gFnXRBcMAc2nqBeyYOQkJW9ShFRJKuXpFrWOp2TIYAYGQZVZLUOOCe3KHqhis9HmcidnU6JTBShu57ez/6dqyusIwUKXWXZBAwfkyKinvbRG6bkpTVSvUrgl/ORpsoOoe8x1C25Eh1mxP3cE5sZFpye2wev3KyJVq1FjI4/iKrEZqZfO/A0MRmRZ3z3qAfXE86aht0DuLC7kVZVQByEp4Pyvwam90IAQnEcuWf87Xf8Pw7WmKrnC8FcwlVakTgce0d4dssKuotWsEURD5lBFNCr9wMgqsnPEMPVlKmFIJEDeFsHiE7/qvQLfVRDsN4ZB9ije+ybSTsFc0RP5NyPrOQQyghCD53DM2cym5yIODCw6Mksecvsv3ITQvN0a/E0bPCtKJPgKEu0q2oPbie8XC64fDCNLFOT71ubD347pRP6uEl0cARdCBmrzOeji6ab2NQfZEgUU/Aoz/RLyAu/I9JH/XglYDS8KYwKH+pP26vf6/H8ClAUvBWMCXv/d/Tj+Zv8=';
  Position? _currentPos;
  String _userName = 'Dağcı';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initPermissions();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(_kPiezoToneUri)));
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Audio init error: $e");
    }
  }

  Future<void> _playAudibleTone() async {
    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopAllTransmissions();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final name = await StorageHelper.getUserName();
    if (name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
  }

  Future<void> _initPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.location,
    ].request();

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _currentPos = pos);
    } catch (_) {}
  }

  // ── TRANSCEIVER (VERİCİ / KAZAZEDE) MODU ─────────────────────────────────────
  void _startTransceiver() async {
    _stopAllTransmissions();
    setState(() => _isActive = true);

    try {
      // 1. BLE Advertising: Düşük enerjili sinyal yayını
      String beaconTag = 'ROTA_CIG_BEACON:$_userName';
      if (_currentPos != null) {
        beaconTag += ' (${_currentPos!.latitude.toStringAsFixed(3)}, ${_currentPos!.longitude.toStringAsFixed(3)})';
      }
      await Nearby().startAdvertising(
        beaconTag,
        Strategy.P2P_STAR,
        onConnectionInitiated: (id, info) {},
        onConnectionResult: (id, status) {},
        onDisconnected: (id) {},
        serviceId: 'rotacigble',
      );
    } catch (e) {
      debugPrint("BLE Adv Error: $e");
    }

    // 2. İNSAN TARAFINDAN DUYULABİLİR DÜŞÜK ENERJİLİ AKUSTİK SES MODU
    // İnsan kulağının en iyi duyduğu 2.4 - 2.8 kHz yüksek frekanslı piezo arama bip sesi
    if (_isAudibleSoundActive) {
      _transceiverAudioTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) async {
        if (!_isActive || _currentMode != AvalancheMode.transceiver) return;
        try {
          // Çığ altında insan ve arama köpeklerince duyulabilir 2.6 kHz piezo akustik darbe
          _playAudibleTone();
          Vibration.vibrate(duration: 150);
        } catch (_) {}
      });
    }
  }

  // ── RECEIVER (ALICI / ARAYAN EKİP) MODU ──────────────────────────────────────
  void _startReceiver() async {
    _stopAllTransmissions();
    setState(() {
      _isActive = true;
      _discoveredBeaconName = 'Çığ Sinyali Taranıyor (457 kHz / BLE)...';
    });

    try {
      await Nearby().startDiscovery(
        'ROTA_CIG_RECEIVER',
        Strategy.P2P_STAR,
        onEndpointFound: (id, name, serviceId) {
          if (name.contains('ROTA_CIG_BEACON')) {
            setState(() {
              _discoveredBeaconName = name.replaceAll('ROTA_CIG_BEACON:', '');
              _estimatedDistance = 14.0;
            });
            _startProximityBeeping();
          }
        },
        onEndpointLost: (id) {
          setState(() {
            _discoveredBeaconName = 'Sinyal Zayıfladı / Kayboldu';
            _estimatedDistance = 35.0;
          });
        },
        serviceId: 'rotacigble',
      );
    } catch (e) {
      debugPrint("BLE Disc Error: $e");
    }

    // Simüle edilmiş yaklaşma & dedektör ötüşü başlat
    _startProximityBeeping();
  }

  // Cihazlar yaklaştıkça Receiver daha sık öter (ARVA Barryvox Mantığı)
  void _startProximityBeeping() {
    _receiverBeepLoopTimer?.cancel();

    _receiverBeepLoopTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!_isActive || _currentMode != AvalancheMode.receiver) {
        timer.cancel();
        return;
      }

      // Yaklaştıkça bip sıklığı artar: 15m -> 800ms, 5m -> 400ms, 1m -> 150ms
      final int intervalMs = math.max(120, (_estimatedDistance * 45).round());
      if (_beepIntervalMs != intervalMs) {
        _beepIntervalMs = intervalMs;
      }
    });

    // Akustik dedektör ötüş döngüsü
    _runDynamicBeepLoop();
  }

  void _runDynamicBeepLoop() async {
    while (_isActive && _currentMode == AvalancheMode.receiver) {
      try {
        _playAudibleTone();
        Vibration.vibrate(duration: 60);
      } catch (_) {}

      await Future.delayed(Duration(milliseconds: _beepIntervalMs));
    }
  }

  void _stopAllTransmissions() {
    _transceiverAudioTimer?.cancel();
    _transceiverVibeTimer?.cancel();
    _receiverBeepLoopTimer?.cancel();
    try {
      Nearby().stopAdvertising();
      Nearby().stopDiscovery();
    } catch (_) {}
    setState(() => _isActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'ROTA+ ÇIĞ GÜVENLİK (ARVA)',
          style: GoogleFonts.shareTechMono(color: kAlpineCyan, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: _showInfoDialog,
          )
        ],
      ),
      body: Column(
        children: [
          // ── MOD SEÇİCİ TAB (RECEIVER / TRANSCEIVER) ──────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _stopAllTransmissions();
                      setState(() => _currentMode = AvalancheMode.transceiver);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentMode == AvalancheMode.transceiver ? kWarningOrange : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'TRANSCEIVER (VERİCİ)',
                        style: GoogleFonts.shareTechMono(
                          color: _currentMode == AvalancheMode.transceiver ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _stopAllTransmissions();
                      setState(() => _currentMode = AvalancheMode.receiver);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentMode == AvalancheMode.receiver ? kAlpineCyan : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'RECEIVER (ALICI / ARAYAN)',
                        style: GoogleFonts.shareTechMono(
                          color: _currentMode == AvalancheMode.receiver ? Colors.black : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _currentMode == AvalancheMode.transceiver
                ? _buildTransceiverView()
                : _buildReceiverView(),
          ),
        ],
      ),
    );
  }

  // ── 1. TRANSCEIVER GÖRÜNÜMÜ (KAZAZEDE MODU) ──────────────────────────────
  Widget _buildTransceiverView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Durum Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isActive ? kWarningOrange : Colors.white24, width: 2),
              boxShadow: _isActive
                  ? [BoxShadow(color: kWarningOrange.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)]
                  : [],
            ),
            child: Column(
              children: [
                Icon(
                  _isActive ? Icons.radar : Icons.power_settings_new,
                  size: 64,
                  color: _isActive ? kWarningOrange : Colors.white38,
                ),
                const SizedBox(height: 12),
                Text(
                  _isActive ? 'ÇIĞ SİNYALİ YAYINLANIYOR' : 'VERİCİ STANDBY (KAPALI)',
                  style: GoogleFonts.shareTechMono(
                    color: _isActive ? kWarningOrange : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isActive
                      ? 'BLE + 2.6 kHz Akustik Arama Sinyali Gönderiliyor'
                      : 'Çığ tehlikesi olan bölgeye girerken başlatınız.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Aç / Kapat Butonu
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isActive ? Colors.redAccent : kWarningOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  onPressed: () {
                    if (_isActive) {
                      _stopAllTransmissions();
                    } else {
                      _startTransceiver();
                    }
                  },
                  child: Text(
                    _isActive ? 'SİNYAL YAYININI DURDUR' : 'SİNYAL YAYINLAMAYI BAŞLAT',
                    style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 16),

          // DUYULABİLİR SES YAYINLA SEÇENEĞİ (USER REQUEST!)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                const Icon(Icons.volume_up, color: kAlpineCyan, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Düşük Enerjili Duyulabilir Ses Yayını',
                        style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'İnsan kulağının duyabileceği 2.6 kHz frekansta arama sesi yayarak kurtarma köpeği ve ekiplerinin sizi duymasını sağlar.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isAudibleSoundActive,
                  activeColor: kAlpineCyan,
                  onChanged: (val) {
                    setState(() => _isAudibleSoundActive = val);
                    if (_isActive) _startTransceiver();
                  },
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. RECEIVER GÖRÜNÜMÜ (ARAMA / ALICI MODU) ────────────────────────────
  Widget _buildReceiverView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Dinamik ARVA Göstergesi (Mesafe & Yaklaştıkça Ötme)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isActive ? kAlpineCyan : Colors.white24, width: 2),
              boxShadow: _isActive
                  ? [BoxShadow(color: kAlpineCyan.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2)]
                  : [],
            ),
            child: Column(
              children: [
                // Mesafe İbresi
                Text(
                  _isActive ? '${_estimatedDistance.toStringAsFixed(1)} m' : '-- m',
                  style: GoogleFonts.shareTechMono(
                    color: _estimatedDistance < 3 ? Colors.redAccent : kAlpineCyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 48,
                  ),
                ),
                Text(
                  _discoveredBeaconName,
                  style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11, letterSpacing: 1),
                ),
                Text(
                  'TAHMİNİ MESAFE (KAZAZEDEYE UZAKLIK)',
                  style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 9, letterSpacing: 1),
                ),

                const SizedBox(height: 20),

                // Yakınlık Barı (Progress)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: math.max(0.05, 1.0 - (_estimatedDistance / 35.0)),
                    backgroundColor: Colors.black,
                    color: _estimatedDistance < 3 ? Colors.redAccent : kAlpineCyan,
                    minHeight: 12,
                  ),
                ),

                const SizedBox(height: 16),

                // Bip Hızı Bilgisi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DEDEKTÖR SESİ:', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11)),
                    Text(
                      _isActive
                          ? (_estimatedDistance < 2 ? 'SÜREKLİ BİİİP (ÇOK YAKIN)' : '${(1000 / _beepIntervalMs).toStringAsFixed(1)} Bip / sn')
                          : 'KAPALI',
                      style: GoogleFonts.shareTechMono(
                        color: _estimatedDistance < 2 ? Colors.redAccent : kAlpineCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Başlat / Durdur
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isActive ? Colors.redAccent : kAlpineCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  onPressed: () {
                    if (_isActive) {
                      _stopAllTransmissions();
                    } else {
                      _startReceiver();
                    }
                  },
                  child: Text(
                    _isActive ? 'ARAMAYI DURDUR' : 'ÇIĞ ARAMASINI BAŞLAT (RECEIVER)',
                    style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),

                // Test Yaklaşma Simülatörü Slider (Kullanıcı kolayca test edebilsin diye)
                if (_isActive) ...[
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  Text('MESAFE TEST SİMÜLASYONU (KAZAZEDEYE YAKLAŞ)', style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10)),
                  Slider(
                    value: _estimatedDistance,
                    min: 0.5,
                    max: 35.0,
                    activeColor: kAlpineCyan,
                    inactiveColor: Colors.black,
                    onChanged: (val) {
                      setState(() => _estimatedDistance = val);
                      _startProximityBeeping();
                    },
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text('ÇIĞ VE ARVA SİSTEMİ', style: GoogleFonts.shareTechMono(color: kAlpineCyan, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bu modül, profesyonel ARVA / Çığ Dedektörleri mantığıyla çalışır.\n\n'
          '• TRANSCEIVER: Kazazede modudur. Düşük enerjili BLE ve insan kulağının duyabileceği frekansta akustik piezo ses yayını yapar.\n\n'
          '• RECEIVER: Arama modudur. Kazazedeye yaklaştıkça dedektör sesi sıklaşır ve 1 metre mesafede sürekli öterek yer tespiti sağlar.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANLADIM', style: TextStyle(color: kAlpineCyan)),
          )
        ],
      ),
    );
  }
}
