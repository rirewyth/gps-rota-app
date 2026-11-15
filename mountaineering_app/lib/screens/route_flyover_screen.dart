import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/tactical_styles.dart';
import '../services/premium_service.dart';


const Color _kCyan = TacticalStyles.kSecondaryContainer;
const Color _kOrange = TacticalStyles.kPrimaryContainer;
const Color _kGreen = TacticalStyles.kTertiary;
const Color _kBg = TacticalStyles.kSurface;
const Color _kCard = TacticalStyles.kSurfaceLow;

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
  final GlobalKey _repaintKey = GlobalKey();
  static const MethodChannel _videoChannel = MethodChannel('com.rotaplus/video_exporter');
  Timer? _timer;
  bool _isExportingVideo = false;
  double _exportProgress = 0;

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

  Future<void> _exportAndShareMp4() async {
    if (_isExportingVideo || _points.isEmpty) return;

    final wasPlaying = _isPlaying;
    final savedIndex = _currentIndex;
    _timer?.cancel();

    setState(() {
      _isPlaying = false;
      _isExportingVideo = true;
      _exportProgress = 0.0;
    });

    final tempDir = await getTemporaryDirectory();
    final sessionDir = Directory('${tempDir.path}/flyover_${DateTime.now().millisecondsSinceEpoch}');
    await sessionDir.create(recursive: true);

    try {
      const int totalFrames = 24;
      final List<String> framePaths = [];

      for (int f = 0; f < totalFrames; f++) {
        if (!mounted) return;
        final ratio = totalFrames == 1 ? 1.0 : f / (totalFrames - 1);
        final idx = (ratio * (_points.length - 1)).round().clamp(0, _points.length - 1);

        setState(() {
          _currentIndex = idx;
          _isFinished = false;
          _updateHUD();
          _exportProgress = (f + 1) / (totalFrames + 2);
        });
        _moveCameraTo(_points[idx]);

        // Wait for map & overlay frame to settle and paint
        await Future.delayed(const Duration(milliseconds: 140));
        await WidgetsBinding.instance.endOfFrame;

        final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (byteData != null) {
            final frameFile = File('${sessionDir.path}/frame_${f.toString().padLeft(3, '0')}.png');
            await frameFile.writeAsBytes(byteData.buffer.asUint8List());
            framePaths.add(frameFile.path);
          }
        }
      }

      if (framePaths.isEmpty) {
        throw Exception('Kare yakalanamadı');
      }

      final safeName = widget.routeName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final outName = safeName.isEmpty ? 'rotaplus_flyover' : 'rotaplus_$safeName';
      final mp4Path = '${sessionDir.path}/$outName.mp4';

      String sharePath = framePaths.last;
      if (Platform.isAndroid) {
        setState(() { _exportProgress = 0.94; });
        final encoded = await _videoChannel.invokeMethod<String>('encodeFramesToMp4', {
          'framePaths': framePaths,
          'outputPath': mp4Path,
          'fps': 6,
        });
        if (encoded != null && await File(encoded).exists()) {
          sharePath = encoded;
        }
      }

      if (!mounted) return;
      setState(() { _exportProgress = 1.0; });

      await Share.shareXFiles(
        [XFile(sharePath)],
        text: '${widget.routeName} - ROTA+ 3D Flyover',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video dışa aktarılamadı: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingVideo = false;
          _exportProgress = 0.0;
          _currentIndex = savedIndex;
          _updateHUD();
          if (wasPlaying) _isPlaying = true;
        });
        _moveCameraTo(_points[savedIndex.clamp(0, _points.length - 1)]);
        if (wasPlaying) _startTimer();
      }
    }
  }

  Future<void> _exportAndShareGpx() async {
    if (_points.isEmpty) return;
    final isPrem = await PremiumService.isPremium();
    if (!mounted) return;
    if (!isPrem) {
      PremiumService.showPremiumRequired(context, 'Profesyonel GPX Rota Dışa Aktarma');
      return;
    }

    try {
      final safeName = widget.routeName
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      final fileSlug = widget.routeName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final outName = fileSlug.isEmpty ? 'rotaplus_track' : fileSlug;

      final sb = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
        ..writeln('<gpx version="1.1" creator="ROTA+ Pro" xmlns="http://www.topografix.com/GPX/1/1">')
        ..writeln('  <metadata><name>$safeName</name></metadata>')
        ..writeln('  <trk>')
        ..writeln('    <name>$safeName</name>')
        ..writeln('    <trkseg>');

      for (int i = 0; i < _points.length; i++) {
        final p = _points[i];
        final raw = i < widget.noktalar.length ? widget.noktalar[i] : null;
        final ele = raw is Map && raw['alt'] != null ? raw['alt'] : null;
        if (ele != null) {
          sb.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}"><ele>$ele</ele></trkpt>');
        } else {
          sb.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}" />');
        }
      }

      sb
        ..writeln('    </trkseg>')
        ..writeln('  </trk>')
        ..writeln('</gpx>');

      final tempDir = await getTemporaryDirectory();
      final gpxFile = File('${tempDir.path}/$outName.gpx');
      await gpxFile.writeAsString(sb.toString());

      await Share.shareXFiles(
        [XFile(gpxFile.path)],
        text: '${widget.routeName} - ROTA+ GPX Parkuru',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPX oluşturulamadı: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showSlopeAnalysisSheet() async {
    final isPrem = await PremiumService.isPremium();
    if (!mounted) return;
    if (!isPrem) {
      PremiumService.showPremiumRequired(context, 'Akıllı Eğim & Zirve Analizi');
      return;
    }

    double totalDistM = widget.distance;
    if (totalDistM <= 0 && _points.length > 1) {
      const distCalc = Distance();
      for (int i = 1; i < _points.length; i++) {
        totalDistM += distCalc.as(LengthUnit.Meter, _points[i - 1], _points[i]);
      }
    }
    final distKm = totalDistM / 1000.0;
    final elevGain = widget.elevationGain > 0 ? widget.elevationGain : (totalDistM * 0.045);
    // Naismith kuralı: 5 km/saat + her 600 m tırmanış için +1 saat
    final naismithHours = (distKm / 5.0) + (elevGain / 600.0);
    final naismithMins = (naismithHours * 60).round();
    final avgSlopePct = totalDistM > 0 ? (elevGain / totalDistM) * 100.0 : 0.0;
    final estMaxSlopePct = (avgSlopePct * 1.9).clamp(0.0, 75.0);
    final estMaxAngleDeg = math.atan(estMaxSlopePct / 100.0) * 180.0 / math.pi;

    final String riskLabel;
    final Color riskColor;
    if (estMaxAngleDeg >= 30.0) {
      riskLabel = 'YÜKSEK DİKKAT (>30° Dik Eğim / Çığ Bölgesi)';
      riskColor = Colors.redAccent;
    } else if (estMaxAngleDeg >= 18.0) {
      riskLabel = 'ORTA EĞİM (Teknik Yürüyüş / Baton Önerilir)';
      riskColor = Colors.amber;
    } else {
      riskLabel = 'DÜŞÜK EĞİM (Standart Trekking Parkuru)';
      riskColor = _kGreen;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
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
              Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AKILLI EĞİM & ZİRVE ANALİZİ',
                      style: TacticalStyles.headline(
                        color: TacticalStyles.kOnSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAnalysisMetric(
                      'NAISMITH SÜRE',
                      '${naismithMins ~/ 60}s ${naismithMins % 60}dk',
                      _kCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnalysisMetric(
                      'ORTALAMA EĞİM',
                      '%${avgSlopePct.toStringAsFixed(1)}',
                      _kOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnalysisMetric(
                      'MAKS. AÇI',
                      '${estMaxAngleDeg.toStringAsFixed(0)}°',
                      riskColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.terrain_rounded, color: riskColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        riskLabel,
                        style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisMetric(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: TacticalStyles.kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TacticalStyles.kOutlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
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
        key: _repaintKey,
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
                          decoration: TacticalStyles.glassCardDecoration(radius: 12),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: TacticalStyles.kOnSurface, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: TacticalStyles.glassCardDecoration(radius: 12),
                          child: Text(
                            widget.routeName,
                            style: TacticalStyles.headline(color: TacticalStyles.kOnSurface, fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _points.isEmpty ? null : _exportAndShareGpx,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: TacticalStyles.glassCardDecoration(
                            radius: 999,
                            borderColor: Colors.amber.withOpacity(0.55),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.amber, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'GPX',
                                style: TacticalStyles.labelMicro(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _isExportingVideo || _points.isEmpty ? null : _exportAndShareMp4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: TacticalStyles.glassCardDecoration(
                            radius: 999,
                            borderColor: _kOrange.withOpacity(0.55),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isExportingVideo ? Icons.hourglass_top_rounded : Icons.movie_creation_outlined,
                                color: _kOrange,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isExportingVideo
                                    ? '${(_exportProgress * 100).toInt()}%'
                                    : 'MP4 PAYLAŞ',
                                style: TacticalStyles.labelMicro(
                                  color: _kOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── HUD İSTATİSTİKLER ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: TacticalStyles.glassCardDecoration(radius: 16),
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
                          _kCyan,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xF027272E),
                        Color(0xEC1C1C22),
                        Color(0xF2141419),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border.all(color: TacticalStyles.kOutlineVariant),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, -6)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // İlerleme çubuğu
                      Row(children: [
                        Text(
                          _formatProgress(_currentIndex),
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 10),
                        ),
                        Expanded(
                          child: Slider(
                            value: _progress,
                            min: 0, max: 1,
                            activeColor: _kCyan,
                            inactiveColor: TacticalStyles.kOutlineVariant,
                            thumbColor: TacticalStyles.kOnSurface,
                            onChanged: _points.isEmpty ? null : (v) => _onScrub(v),
                          ),
                        ),
                        Text(
                          '${_points.length} nokta',
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 10),
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
                            TacticalStyles.kOnSurfaceVariant,
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
                                  color: (_isPlaying ? _kOrange : _kCyan).withOpacity(0.35),
                                  blurRadius: 16, spreadRadius: 1,
                                )],
                              ),
                              child: Icon(
                                _isFinished
                                    ? Icons.replay_rounded
                                    : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                color: _isPlaying ? Colors.white : TacticalStyles.kSurfaceLowest,
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
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        if (_isPlaying)
                          Row(children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('OYNATILIYOR', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: _kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ]),
                        if (_isFinished)
                          Row(children: [
                            const Icon(Icons.check_circle, color: _kGreen, size: 14),
                            const SizedBox(width: 5),
                            Text('TAMAMLANDI', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: _kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ]),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── FİLİGRAN (Harita üst-sol, HUD altında; alt kontrol paneliyle çakışmaz) ──
          Positioned(
            top: 148,
            left: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TacticalStyles.kSurfaceLowest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ROTA+', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                    const SizedBox(height: 1),
                    Text(widget.routeName.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white.withOpacity(0.7), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),

          // ── EĞİM & ZİRVE ANALİZİ (PREMIUM) ─────────────────────────
          Positioned(
            top: 148,
            right: 16,
            child: GestureDetector(
              onTap: _showSlopeAnalysisSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TacticalStyles.kSurfaceLowest.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_graph_rounded, color: Colors.amber, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'EĞİM PRO',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
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
      Text(value, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 9, letterSpacing: 0.4, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildHudDivider() => Container(width: 1, height: 30, color: TacticalStyles.kOutlineVariant);

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
        Text(label, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: color, fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildSpeedSelector() {
    final speeds = [1.0, 2.0, 5.0, 10.0];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: TacticalStyles.kSurfaceLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TacticalStyles.kOutlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) {
            final selected = _speedMultiplier == s;
            return GestureDetector(
              onTap: () => _setSpeed(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? _kCyan.withOpacity(0.22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${s.toInt()}x',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontFamilyFallback: const ['Helvetica Neue', 'Arial', 'sans-serif'],
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: selected ? _kCyan : TacticalStyles.kOnSurfaceVariant,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'HIZ',
        style: TextStyle(
          fontFamily: 'Helvetica',
          fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'],
          fontFeatures: [FontFeature.tabularFigures()],
          color: TacticalStyles.kOnSurfaceVariant,
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
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
