import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/tactical_styles.dart';

class BarometerStormScreen extends StatefulWidget {
  const BarometerStormScreen({super.key});

  @override
  State<BarometerStormScreen> createState() => _BarometerStormScreenState();
}

class _BarometerStormScreenState extends State<BarometerStormScreen> {
  bool _loading = true;
  String? _error;
  double _lat = 39.92;
  double _lng = 32.85;
  double _altitudeM = 1000;
  List<double> _pressures = [];
  double _currentPressure = 1013.2;
  double _delta3h = 0.0;
  double _windKmh = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAtmosphereData();
  }

  Future<void> _loadAtmosphereData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 5));
        _lat = pos.latitude;
        _lng = pos.longitude;
        _altitudeM = pos.altitude;
      } catch (_) {}

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng'
        '&hourly=surface_pressure,wind_speed_10m&forecast_days=1&timezone=auto',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>;
      final List rawP = hourly['surface_pressure'] ?? [];
      final List rawW = hourly['wind_speed_10m'] ?? [];

      _pressures = rawP.map((e) => (e as num).toDouble()).toList();
      final maxIdx = _pressures.isEmpty ? 0 : _pressures.length - 1;
      final int nowHour = DateTime.now().hour.clamp(0, maxIdx);
      if (_pressures.isNotEmpty) {
        _currentPressure = _pressures[nowHour];
        final int prevIdx = math.max(0, nowHour - 3);
        _delta3h = _currentPressure - _pressures[prevIdx];
      }
      if (rawW.isNotEmpty && nowHour < rawW.length) {
        _windKmh = (rawW[nowHour] as num).toDouble();
      }
    } catch (e) {
      _error = 'Atmosfer verisi alınamadı: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _oxygenPercent {
    // Yaklaşık barometrik oksijen oranı (deniz seviyesi = %100 efektif)
    return (100.0 * math.exp(-_altitudeM / 8400.0)).clamp(35.0, 100.0);
  }

  double get _barometricAlt {
    return 44330.0 * (1.0 - math.pow(_currentPressure / 1013.25, 0.1903));
  }

  String get _stormStatus {
    if (_delta3h <= -3.5 || _windKmh >= 45) return 'FIRTINA UYARISI (YÜKSEK RİSK)';
    if (_delta3h <= -1.5 || _windKmh >= 28) return 'BASINÇ DÜŞÜYOR (DİKKAT)';
    return 'ATMOSFER STABİL (GÜVENLİ)';
  }

  Color get _stormColor {
    if (_delta3h <= -3.5 || _windKmh >= 45) return Colors.redAccent;
    if (_delta3h <= -1.5 || _windKmh >= 28) return Colors.amber;
    return TacticalStyles.kTertiary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.speed_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'BAROMETRE & FIRTINA PRO',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: TacticalStyles.kOnSurfaceVariant),
            onPressed: _loadAtmosphereData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Fırtına Durum Banner'ı
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _stormColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _stormColor.withOpacity(0.45)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.thunderstorm_rounded, color: _stormColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_stormStatus, style: TextStyle(color: _stormColor, fontSize: 13, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text(
                                  '3 Saatlik Değişim: ${_delta3h >= 0 ? '+' : ''}${_delta3h.toStringAsFixed(1)} hPa • Rüzgar: ${_windKmh.toStringAsFixed(0)} km/s',
                                  style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Ana Metrikler
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard('YÜZEY BASINCI', '${_currentPressure.toStringAsFixed(1)} hPa', TacticalStyles.kSecondaryContainer),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricCard('OKSİJEN ORANI', '%${_oxygenPercent.toStringAsFixed(0)}', TacticalStyles.kTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard('BAROMETRİK İRTİFA', '${_barometricAlt.toInt()} m', Colors.amber),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricCard('GPS RAKIM', '${_altitudeM.toInt()} m', TacticalStyles.kPrimary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 24 Saatlik Basınç Eğrisi
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: TacticalStyles.glassCardDecoration(radius: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '24 SAATLİK BAROMETRİK BASINÇ EĞRİSİ (hPa)',
                            style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _PressureChartPainter(_pressures),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: TacticalStyles.glassCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 9.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PressureChartPainter extends CustomPainter {
  final List<double> values;
  _PressureChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min) - 1.0;
    final maxV = values.reduce(math.max) + 1.0;
    final range = (maxV - minV).clamp(1.0, 100.0);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePath = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.amber.withOpacity(0.32), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.amber
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PressureChartPainter oldDelegate) => oldDelegate.values != values;
}
