import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import '../services/tactical_styles.dart';

class CrashDetectorScreen extends StatefulWidget {
  const CrashDetectorScreen({super.key});

  @override
  State<CrashDetectorScreen> createState() => _CrashDetectorScreenState();
}

class _CrashDetectorScreenState extends State<CrashDetectorScreen> {
  final AudioPlayer _sirenPlayer = AudioPlayer();
  StreamSubscription<AccelerometerEvent>? _accelSub;

  bool _armed = false;
  double _thresholdG = 3.0;
  double _currentG = 1.0;
  double _peakG = 1.0;
  bool _countdownOpen = false;

  @override
  void initState() {
    super.initState();
    _startAccelStream();
  }

  void _startAccelStream() {
    _accelSub = accelerometerEventStream().listen((ev) {
      final g = math.sqrt(ev.x * ev.x + ev.y * ev.y + ev.z * ev.z) / 9.80665;
      if (!mounted) return;
      setState(() {
        _currentG = g;
        if (g > _peakG) _peakG = g;
      });
      if (_armed && !_countdownOpen && g >= _thresholdG) {
        _triggerImpactCountdown(g);
      }
    });
  }

  Future<void> _triggerImpactCountdown(double impactG) async {
    _countdownOpen = true;
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [0, 400, 200, 400]);
      }
    } catch (_) {}

    int secLeft = 20;
    Timer? timer;

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) {
              t.cancel();
              return;
            }
            if (secLeft <= 1) {
              t.cancel();
              Navigator.of(ctx).pop();
              _dispatchEmergencySos(impactG);
            } else {
              setDlg(() => secLeft--);
            }
          });
          return AlertDialog(
            backgroundColor: TacticalStyles.kSurfaceLow,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text('SERT DARBE ALGILANDI!', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            content: Text(
              '${impactG.toStringAsFixed(1)}G darbe tespit edildi.\n$secLeft saniye içinde iptal edilmezse acil siren ve konum paylaşımı başlatılacak.',
              style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: TacticalStyles.kTertiary, foregroundColor: Colors.black),
                onPressed: () {
                  timer?.cancel();
                  _countdownOpen = false;
                  Navigator.of(ctx).pop();
                },
                child: const Text('İYİYİM, İPTAL ET', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      timer?.cancel();
      _countdownOpen = false;
    });
  }

  Future<void> _dispatchEmergencySos(double impactG) async {
    try {
      await _sirenPlayer.setLoopMode(LoopMode.one);
      await _sirenPlayer.setAsset('assets/audio/siren.mp3');
      _sirenPlayer.play();
    } catch (_) {}

    String coords = 'Konum alınamadı';
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));
      coords = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} '
          '(https://maps.google.com/?q=${pos.latitude},${pos.longitude})';
    } catch (_) {}

    final msg = '🆘 OTOMATİK DARBE/DÜŞME SOS!\nŞiddet: ${impactG.toStringAsFixed(1)}G\nKonum: $coords';
    final smsUri = Uri(scheme: 'sms', queryParameters: {'body': msg});
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      await Share.share(msg);
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _sirenPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (_currentG / 5.0).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sensors_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'DÜŞME & DARBE ALGILAYICI',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: TacticalStyles.glassCardDecoration(
              radius: 16,
              borderColor: _armed ? Colors.redAccent.withOpacity(0.5) : TacticalStyles.kOutlineVariant,
            ),
            child: Column(
              children: [
                Text(
                  '${_currentG.toStringAsFixed(2)} G',
                  style: TextStyle(
                    color: _currentG >= _thresholdG ? Colors.redAccent : TacticalStyles.kTertiary,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: TacticalStyles.kSurfaceLowest,
                    color: _currentG >= _thresholdG ? Colors.redAccent : TacticalStyles.kTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Zirve Darbe: ${_peakG.toStringAsFixed(2)} G • Eşik: ${_thresholdG.toStringAsFixed(1)} G',
                  style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: TacticalStyles.glassCardDecoration(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HASSASİYET EŞİĞİ', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [2.5, 3.0, 4.0].map((val) {
                    final sel = _thresholdG == val;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _thresholdG = val),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? Colors.redAccent.withOpacity(0.18) : TacticalStyles.kSurfaceLowest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? Colors.redAccent : TacticalStyles.kOutlineVariant),
                            ),
                            child: Text(
                              '${val.toStringAsFixed(1)} G',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: sel ? Colors.redAccent : TacticalStyles.kOnSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _armed ? Colors.redAccent : TacticalStyles.kTertiary,
              foregroundColor: _armed ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              setState(() {
                _armed = !_armed;
                _peakG = 1.0;
              });
            },
            icon: Icon(_armed ? Icons.shield_rounded : Icons.play_arrow_rounded),
            label: Text(
              _armed ? 'DARBE KALKANI AKTİF (DURDUR)' : 'DARBE KALKANINI AKTİF ET',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: BorderSide(color: Colors.amber.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _triggerImpactCountdown(_thresholdG + 0.4),
            icon: const Icon(Icons.bug_report_rounded, size: 18),
            label: const Text('TEST DARBESİ SİMÜLE ET', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
