import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tactical_styles.dart';

class BreadcrumbRadarScreen extends StatefulWidget {
  const BreadcrumbRadarScreen({super.key});

  @override
  State<BreadcrumbRadarScreen> createState() => _BreadcrumbRadarScreenState();
}

class _BreadcrumbRadarScreenState extends State<BreadcrumbRadarScreen> {
  static const String _trailKey = 'free_breadcrumb_trail_v1';

  final FlutterTts _tts = FlutterTts();
  final List<LatLng> _trail = [];
  LatLng? _currentPos;
  double _heading = 0;
  bool _recording = false;
  bool _returnMode = false;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<CompassEvent>? _compassSub;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('tr-TR');
    _loadTrail();
    _initSensors();
  }

  Future<void> _loadTrail() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trailKey);
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _trail
              ..clear()
              ..addAll(list.map((e) => LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble())));
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveTrail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _trailKey,
      jsonEncode(_trail.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()),
    );
  }

  void _initSensors() {
    _compassSub = FlutterCompass.events?.listen((ev) {
      if (ev.heading != null && mounted) {
        setState(() => _heading = ev.heading!);
      }
    });

    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).then((pos) {
      if (mounted) {
        setState(() => _currentPos = LatLng(pos.latitude, pos.longitude));
      }
    }).catchError((_) {});
  }

  void _toggleRecording() {
    if (_recording) {
      _posSub?.cancel();
      _posSub = null;
      setState(() => _recording = false);
      return;
    }

    setState(() => _recording = true);
    if (_currentPos != null && _trail.isEmpty) {
      _trail.add(_currentPos!);
      _saveTrail();
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      final next = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _currentPos = next;
        if (_trail.isEmpty || const Distance().as(LengthUnit.Meter, _trail.last, next) >= 12) {
          _trail.add(next);
          _saveTrail();
        }
      });
    });
  }

  double _bearingTo(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  String _cardinal(double deg) {
    const dirs = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    return dirs[((deg + 22.5) / 45).floor() % 8];
  }

  Future<void> _speakReturnGuidance() async {
    if (_currentPos == null || _trail.isEmpty) {
      await _tts.speak('Henüz kayıtlı iz noktası bulunmuyor.');
      return;
    }
    final target = _returnMode ? _trail.first : _trail.last;
    final distM = const Distance().as(LengthUnit.Meter, _currentPos!, target);
    final brg = _bearingTo(_currentPos!, target);
    final dir = _cardinal(brg);
    final distStr = distM >= 1000
        ? '${(distM / 1000).toStringAsFixed(1)} kilometre'
        : '${distM.toInt()} metre';
    await _tts.speak('Başlangıç noktasına dönüş için ${brg.toInt()} derece $dir yönüne $distStr ilerleyin.');
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _compassSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _trail.isEmpty ? null : (_returnMode ? _trail.first : _trail.last);
    final distM = (_currentPos != null && target != null)
        ? const Distance().as(LengthUnit.Meter, _currentPos!, target)
        : 0.0;
    final brg = (_currentPos != null && target != null)
        ? _bearingTo(_currentPos!, target)
        : 0.0;

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.radar_rounded, color: TacticalStyles.kTertiary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'İZ TAKİP & GERİ DÖNÜŞ RADARI',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'İzi Temizle',
            icon: const Icon(Icons.delete_sweep_rounded, color: TacticalStyles.kOnSurfaceVariant),
            onPressed: () {
              setState(() => _trail.clear());
              _saveTrail();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Radar Ekranı
          Container(
            height: 290,
            decoration: TacticalStyles.glassCardDecoration(
              radius: 18,
              borderColor: TacticalStyles.kTertiary.withOpacity(0.4),
            ),
            child: CustomPaint(
              painter: _BreadcrumbRadarPainter(
                trail: _trail,
                currentPos: _currentPos,
                headingDeg: _heading,
                targetBearingDeg: brg,
                hasTarget: target != null,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Yön & Mesafe Kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: TacticalStyles.glassCardDecoration(radius: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _returnMode ? 'BAŞLANGICA DÖNÜŞ YÖNÜ' : 'KAYITLI İZ NOKTASI',
                        style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        target == null
                            ? 'İz Kaydı Başlatın'
                            : '${brg.toInt()}° ${_cardinal(brg)} • ${distM >= 1000 ? '${(distM / 1000).toStringAsFixed(2)} km' : '${distM.toInt()} m'}',
                        style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Toplam ${_trail.length} iz noktası • Pusula: ${_heading.toInt()}°',
                        style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _speakReturnGuidance,
                  icon: const Icon(Icons.volume_up_rounded, color: TacticalStyles.kTertiary, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Kontroller
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _recording ? Colors.redAccent : TacticalStyles.kTertiary,
                    foregroundColor: _recording ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _toggleRecording,
                  icon: Icon(_recording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded),
                  label: Text(
                    _recording ? 'İZ KAYDINI DURDUR' : 'İZ KAYDI BAŞLAT',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _returnMode ? Colors.amber : TacticalStyles.kOnSurface,
                    side: BorderSide(color: _returnMode ? Colors.amber : TacticalStyles.kOutlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _returnMode = !_returnMode),
                  icon: const Icon(Icons.u_turn_left_rounded, size: 18),
                  label: Text(
                    _returnMode ? 'GERİ DÖNÜŞ AKTİF' : 'GERİ DÖNÜŞ MODU',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbRadarPainter extends CustomPainter {
  final List<LatLng> trail;
  final LatLng? currentPos;
  final double headingDeg;
  final double targetBearingDeg;
  final bool hasTarget;

  _BreadcrumbRadarPainter({
    required this.trail,
    required this.currentPos,
    required this.headingDeg,
    required this.targetBearingDeg,
    required this.hasTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.42;

    final ringPaint = Paint()
      ..color = TacticalStyles.kTertiary.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final f in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, maxR * f, ringPaint);
    }

    canvas.drawLine(Offset(center.dx - maxR, center.dy), Offset(center.dx + maxR, center.dy), ringPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxR), Offset(center.dx, center.dy + maxR), ringPaint);

    // İz noktalarını göreceli olarak çiz
    if (currentPos != null && trail.length > 1) {
      final path = Path();
      const scale = 18000.0; // yakl. 500m radar menzili
      final headingRad = -headingDeg * math.pi / 180.0;
      for (int i = 0; i < trail.length; i++) {
        final dxRaw = (trail[i].longitude - currentPos!.longitude) * scale;
        final dyRaw = -(trail[i].latitude - currentPos!.latitude) * scale;
        final rx = dxRaw * math.cos(headingRad) - dyRaw * math.sin(headingRad);
        final ry = dxRaw * math.sin(headingRad) + dyRaw * math.cos(headingRad);
        final pt = Offset(
          (center.dx + rx).clamp(center.dx - maxR, center.dx + maxR),
          (center.dy + ry).clamp(center.dy - maxR, center.dy + maxR),
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = TacticalStyles.kTertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    // Hedef yön oku
    if (hasTarget) {
      final relAngle = (targetBearingDeg - headingDeg - 90) * math.pi / 180.0;
      final tip = Offset(
        center.dx + math.cos(relAngle) * (maxR * 0.82),
        center.dy + math.sin(relAngle) * (maxR * 0.82),
      );
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = Colors.amber
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(tip, 6, Paint()..color = Colors.amber);
    }

    // Kullanıcı merkezi
    canvas.drawCircle(center, 7, Paint()..color = TacticalStyles.kPrimaryContainer);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BreadcrumbRadarPainter oldDelegate) => true;
}
