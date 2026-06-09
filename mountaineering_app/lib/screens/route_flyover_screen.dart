import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';


const Color _kCyan = Color(0xFF00E5FF);
const Color _kOrange = Color(0xFFFF6B00);
const Color _kGreen = Color(0xFF62FF4C);
const Color _kBg = Color(0xFF0A0A12);
const Color _kCard = Color(0xFF131320);

class RouteFlyoverScreen extends StatefulWidget {
  final String routeName;
  final List noktalar; // [{'lat': x, 'lng': y}, ...]
  final double distance;
  final int durationSeconds;
  final double elevationGain;
  final double maxAltitude;

  const RouteFlyoverScreen({
    super.key,
    required this.routeName,
    required this.noktalar,
    this.distance = 0,
    this.durationSeconds = 0,
    this.elevationGain = 0,
    this.maxAltitude = 0,
  });

  @override
  State<RouteFlyoverScreen> createState() => _RouteFlyoverScreenState();
}

class _RouteFlyoverScreenState extends State<RouteFlyoverScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  Timer? _timer;

  List<LatLng> _points = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  double _speedMultiplier = 1.0;
  bool _isFinished = false;

  // HUD
  double _completedDistanceM = 0;
  double _currentElevation = 0;

  // Animasyon
  late AnimationController _markerPulseCtrl;

  // Harita tile URL — Esri Uydu
  final String _tileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  // Yükseklik profili (simüle)
  List<double> _elevationProfile = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _markerPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _buildPoints();
  }

  void _buildPoints() {
    _points = widget.noktalar
        .map((e) {
          try {
            return LatLng(
              (e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble(),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<LatLng>()
        .toList();

    // Yükseklik profili simüle et
    if (_points.isNotEmpty) {
      _elevationProfile = _simulateElevation(_points, widget.maxAltitude, widget.elevationGain);
      _currentElevation = _elevationProfile.isNotEmpty ? _elevationProfile[0] : 0;
    }
  }

  List<double> _simulateElevation(List<LatLng> pts, double maxAlt, double gain) {
    if (pts.isEmpty) return [];
    final base = (maxAlt > 0 ? maxAlt - gain : 500).clamp(0.0, double.infinity);
    final rand = math.Random(42);
    final profile = <double>[];
    double current = base.toDouble();
    for (int i = 0; i < pts.length; i++) {
      final progress = i / pts.length;
      // Genel tırmanış eğrisi + gürültü
      final target = base + gain * _smoothStep(progress);
      current = current * 0.85 + target * 0.15 + (rand.nextDouble() - 0.5) * (gain * 0.04);
      profile.add(current.clamp(0.0, maxAlt > 0 ? maxAlt + 50 : 9999));
    }
    return profile;
  }

  double _smoothStep(double t) {
    // Sinüs benzeri tırmanış
    return math.sin(t * math.pi * 0.9);
  }

  void _startTimer() {
    _timer?.cancel();
    // Her 50ms bir adım (1x = ~20 puan/sn)
    final intervalMs = (50 / _speedMultiplier).round().clamp(16, 500);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!_isPlaying) return;
      if (_currentIndex >= _points.length - 1) {
        _timer?.cancel();
        setState(() { _isPlaying = false; _isFinished = true; });
        return;
      }
      setState(() {
        _currentIndex++;
        _updateHUD();
        _moveCameraTo(_points[_currentIndex]);
      });
    });
  }

  void _updateHUD() {
    final dist = const Distance();
    if (_currentIndex > 0) {
      double total = 0;
      for (int i = 1; i <= _currentIndex && i < _points.length; i++) {
        total += dist.as(LengthUnit.Meter, _points[i - 1], _points[i]);
      }
      _completedDistanceM = total;
    }
    if (_elevationProfile.isNotEmpty && _currentIndex < _elevationProfile.length) {
      _currentElevation = _elevationProfile[_currentIndex];
    }
  }

  void _moveCameraTo(LatLng pt) {
    try {
      _mapController.move(pt, _mapController.camera.zoom);
    } catch (_) {}
  }

  void _togglePlayPause() {
    if (_isFinished) {
      setState(() {
        _currentIndex = 0;
        _completedDistanceM = 0;
        _isFinished = false;
        _isPlaying = true;
      });
      _startTimer();
      return;
    }
    setState(() { _isPlaying = !_isPlaying; });
    if (_isPlaying) _startTimer();
  }

  void _onScrub(double ratio) {
    final idx = (ratio * (_points.length - 1)).round().clamp(0, _points.length - 1);
    setState(() {
      _currentIndex = idx;
      _isFinished = false;
      _updateHUD();
    });
    _moveCameraTo(_points[idx]);
  }

  void _setSpeed(double s) {
    setState(() { _speedMultiplier = s; });
    if (_isPlaying) _startTimer();
  }

  // Bounding box hesapla
  LatLngBounds? _getBounds() {
    if (_points.isEmpty) return null;
    double minLat = _points.first.latitude, maxLat = _points.first.latitude;
    double minLng = _points.first.longitude, maxLng = _points.first.longitude;
    for (final p in _points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  LatLng get _center {
    if (_points.isEmpty) return const LatLng(39.0, 35.0);
    double latSum = 0, lngSum = 0;
    for (final p in _points) { latSum += p.latitude; lngSum += p.longitude; }
    return LatLng(latSum / _points.length, lngSum / _points.length);
  }

  double get _progress => _points.isEmpty ? 0 : _currentIndex / (_points.length - 1).clamp(1, 999999);

  @override
  void dispose() {
    _timer?.cancel();
    _markerPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex < _points.length ? _points[_currentIndex] : null;

    return Scaffold(
      backgroundColor: _kBg,
      body: RepaintBoundary(
        child: Stack(
          children: [
          // ── HARITA ──────────────────────────────────────────────────
          if (_points.isNotEmpty)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.rotaplus.mountaineering',
                ),
                // Tüm rota — soluk (Uydu üzerinde daha iyi görünmesi için beyaz-saydam)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _points,
                    color: Colors.white.withOpacity(0.4),
                    strokeWidth: 4,
                  ),
                ]),
                // Geçilen kısım — parlak Strava Turuncusu
                if (_currentIndex > 0)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _points.sublist(0, _currentIndex + 1),
                      color: _kOrange,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                    ),
                  ]),
                // Başlangıç noktası
                MarkerLayer(markers: [
                  Marker(
                    point: _points.first,
                    width: 16, height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kGreen, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  // Bitiş noktası
                  Marker(
                    point: _points.last,
                    width: 16, height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  // Aktif marker
                  if (current != null)
                    Marker(
                      point: current,
                      width: 36, height: 36,
                      child: AnimatedBuilder(
                        animation: _markerPulseCtrl,
                        builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 36 * (0.7 + 0.3 * _markerPulseCtrl.value),
                              height: 36 * (0.7 + 0.3 * _markerPulseCtrl.value),
                              decoration: BoxDecoration(
                                color: _kCyan.withOpacity(0.2 - 0.15 * _markerPulseCtrl.value),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: _kCyan,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
                              ),
                              child: const Icon(Icons.directions_walk, color: Colors.black, size: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ],
            )
          else
            const Center(child: Text('Koordinat bulunamadı.', style: TextStyle(color: Colors.white54))),

          // ── ÜST BAR ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.routeName,
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _kCyan.withOpacity(0.4)),
                        ),
                        child: Text('FLYOVER', style: GoogleFonts.shareTechMono(color: _kCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                // ── HUD İSTATİSTİKLER ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHudItem(
                          Icons.straighten,
                          _completedDistanceM >= 1000
                              ? '${(_completedDistanceM / 1000).toStringAsFixed(2)} km'
                              : '${_completedDistanceM.toInt()} m',
                          'GİDİLEN',
                          _kGreen,
                        ),
                        _buildHudDivider(),
                        _buildHudItem(
                          Icons.landscape,
                          '${_currentElevation.toInt()} m',
                          'YÜKSEKLİK',
                          Colors.lightBlueAccent,
                        ),
                        _buildHudDivider(),
                        _buildHudItem(
                          Icons.route_rounded,
                          widget.distance >= 1000
                              ? '${(widget.distance / 1000).toStringAsFixed(1)} km'
                              : '${widget.distance.toInt()} m',
                          'TOPLAM',
                          _kOrange,
                        ),
                        _buildHudDivider(),
                        _buildHudItem(
                          Icons.trending_up,
                          '+${widget.elevationGain.toInt()} m',
                          'RAKIM K.',
                          Colors.amberAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── ALT KONTROL PANELİ ─────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Yükseklik Profili
                if (_elevationProfile.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 70,
                      child: CustomPaint(
                        painter: _ElevationProfilePainter(
                          profile: _elevationProfile,
                          progress: _progress,
                          lineColor: _kCyan,
                          fillColor: _kCyan.withOpacity(0.15),
                          progressLineColor: Colors.white.withOpacity(0.6),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                // Scrubber + Kontroller
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4), // Daha şeffaf (kötü görünüm düzeltmesi)
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // İlerleme çubuğu
                      Row(children: [
                        Text(
                          _formatProgress(_currentIndex),
                          style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10),
                        ),
                        Expanded(
                          child: Slider(
                            value: _progress,
                            min: 0, max: 1,
                            activeColor: _kCyan,
                            inactiveColor: Colors.white12,
                            thumbColor: Colors.white,
                            onChanged: _points.isEmpty ? null : (v) => _onScrub(v),
                          ),
                        ),
                        Text(
                          '${_points.length} nokta',
                          style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10),
                        ),
                      ]),

                      const SizedBox(height: 4),

                      // Kontrol butonları
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Geri sar
                          _buildCtrlBtn(
                            Icons.replay_rounded,
                            'BAŞA DÖN',
                            Colors.white38,
                            () => setState(() {
                              _currentIndex = 0;
                              _completedDistanceM = 0;
                              _isFinished = false;
                              _isPlaying = false;
                              _timer?.cancel();
                              if (_points.isNotEmpty) _moveCameraTo(_points[0]);
                            }),
                          ),
                          // Oynat / Duraklat
                          GestureDetector(
                            onTap: _points.isEmpty ? null : _togglePlayPause,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                color: _isPlaying ? _kOrange : _kCyan,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: (_isPlaying ? _kOrange : _kCyan).withOpacity(0.4),
                                  blurRadius: 20, spreadRadius: 2,
                                )],
                              ),
                              child: Icon(
                                _isFinished
                                    ? Icons.replay_rounded
                                    : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                color: Colors.black,
                                size: 36,
                              ),
                            ),
                          ),
                          // Hız
                          _buildSpeedSelector(),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // İlerleme yüzdesi
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%  tamamlandı',
                          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        if (_isPlaying)
                          Row(children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('OYNATILIYOR', style: GoogleFonts.shareTechMono(color: _kGreen, fontSize: 10)),
                          ]),
                        if (_isFinished)
                          Row(children: [
                            const Icon(Icons.check_circle, color: _kGreen, size: 14),
                            const SizedBox(width: 5),
                            Text('TAMAMLANDI', style: GoogleFonts.shareTechMono(color: _kGreen, fontSize: 10)),
                          ]),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── FİLİGRAN (Sürekli görünür, kayıt yapanlar için) ───────────
          Positioned(
            bottom: 140, // Alt kontrol panelinin üzerinde kalması için
            right: 20,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ROTA+', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.85), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    const SizedBox(height: 2),
                    Text(widget.routeName.toUpperCase(), style: GoogleFonts.shareTechMono(color: Colors.white.withOpacity(0.65), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ), // RepaintBoundary kapat
    );
  }

  Widget _buildHudItem(IconData icon, String value, String label, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
    ]);
  }

  Widget _buildHudDivider() => Container(width: 1, height: 30, color: Colors.white10);

  Widget _buildCtrlBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(color: color, fontSize: 9, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _buildSpeedSelector() {
    final speeds = [1.0, 2.0, 5.0, 10.0, 20.0];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) {
            final selected = _speedMultiplier == s;
            return GestureDetector(
              onTap: () => _setSpeed(s),
              child: Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? _kCyan.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s == s.roundToDouble() ? s.toInt() : s}x',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.shareTechMono(
                    color: selected ? _kCyan : Colors.white38,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 4),
      Text('HIZ', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
    ]);
  }

  String _formatProgress(int idx) {
    if (_points.isEmpty) return '0/0';
    return '$idx/${_points.length}';
  }
}

// Yükseklik Profili Çizici
class _ElevationProfilePainter extends CustomPainter {
  final List<double> profile;
  final double progress;
  final Color lineColor;
  final Color fillColor;
  final Color progressLineColor;

  const _ElevationProfilePainter({
    required this.profile,
    required this.progress,
    required this.lineColor,
    required this.fillColor,
    required this.progressLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.isEmpty) return;

    final minE = profile.reduce(math.min);
    final maxE = profile.reduce(math.max);
    final range = (maxE - minE).clamp(1.0, double.infinity);

    double xStep = size.width / (profile.length - 1).clamp(1, 999999);

    // Arka plan dolgu
    final bgPath = Path();
    bgPath.moveTo(0, size.height);
    for (int i = 0; i < profile.length; i++) {
      final x = i * xStep;
      final y = size.height - ((profile[i] - minE) / range) * size.height * 0.85;
      if (i == 0) bgPath.lineTo(x, y); else bgPath.lineTo(x, y);
    }
    bgPath.lineTo(size.width, size.height);
    bgPath.close();
    canvas.drawPath(bgPath, Paint()..color = fillColor);

    // Çizgi
    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final linePath = Path();
    for (int i = 0; i < profile.length; i++) {
      final x = i * xStep;
      final y = size.height - ((profile[i] - minE) / range) * size.height * 0.85;
      if (i == 0) linePath.moveTo(x, y); else linePath.lineTo(x, y);
    }
    canvas.drawPath(linePath, linePaint);

    // Geçilen kısım (dolu)
    final progressX = progress * size.width;
    final progressIdx = (progress * (profile.length - 1)).round();
    if (progressIdx > 0) {
      final filledPath = Path();
      filledPath.moveTo(0, size.height);
      for (int i = 0; i <= progressIdx && i < profile.length; i++) {
        final x = i * xStep;
        final y = size.height - ((profile[i] - minE) / range) * size.height * 0.85;
        if (i == 0) filledPath.lineTo(x, y); else filledPath.lineTo(x, y);
      }
      filledPath.lineTo(progressX, size.height);
      filledPath.close();
      canvas.drawPath(filledPath, Paint()..color = lineColor.withOpacity(0.3));
    }

    // Dikey çizgi — şu anki konum
    if (progress > 0 && progress < 1) {
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        Paint()
          ..color = progressLineColor
          ..strokeWidth = 1.5,
      );
      // Nokta
      canvas.drawCircle(
        Offset(progressX, size.height - ((profile[progressIdx] - minE) / range) * size.height * 0.85),
        5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ElevationProfilePainter old) =>
      old.progress != progress;
}
