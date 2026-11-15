import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/tactical_styles.dart';

class HypothermiaShieldScreen extends StatefulWidget {
  const HypothermiaShieldScreen({super.key});

  @override
  State<HypothermiaShieldScreen> createState() => _HypothermiaShieldScreenState();
}

class _HypothermiaShieldScreenState extends State<HypothermiaShieldScreen> {
  bool _loading = true;
  double _baseTempC = 6.0;
  double _baseWindKmh = 22.0;
  double _extraAltitudeM = 1000.0;

  @override
  void initState() {
    super.initState();
    _fetchLiveWeather();
  }

  Future<void> _fetchLiveWeather() async {
    setState(() => _loading = true);
    double lat = 39.92;
    double lng = 32.85;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 4));
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,wind_speed_10m',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final cur = data['current'] as Map<String, dynamic>?;
        if (cur != null) {
          _baseTempC = (cur['temperature_2m'] as num?)?.toDouble() ?? _baseTempC;
          _baseWindKmh = (cur['wind_speed_10m'] as num?)?.toDouble() ?? _baseWindKmh;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  double get _projectedTempC => _baseTempC - ((_extraAltitudeM / 1000.0) * 6.5);
  double get _projectedWindKmh => _baseWindKmh * (1.0 + (_extraAltitudeM / 3000.0) * 0.65);

  double get _windChillC {
    final t = _projectedTempC;
    final v = _projectedWindKmh;
    if (t <= 10.0 && v >= 4.8) {
      return 13.12 +
          0.6215 * t -
          11.37 * math.pow(v, 0.16) +
          0.3965 * t * math.pow(v, 0.16);
    }
    return t;
  }

  String get _riskTitle {
    final wc = _windChillC;
    if (wc <= -25) return 'KRİTİK DONMA & HİPOTERMİ RİSKİ';
    if (wc <= -10) return 'YÜKSEK SOĞUK MARUZİYETİ';
    if (wc <= 0) return 'ORTA HİPOTERMİ DİKKATİ';
    return 'DÜŞÜK TERMAL RİSK';
  }

  Color get _riskColor {
    final wc = _windChillC;
    if (wc <= -25) return Colors.redAccent;
    if (wc <= -10) return Colors.deepOrangeAccent;
    if (wc <= 0) return Colors.amber;
    return TacticalStyles.kTertiary;
  }

  String get _frostbiteWindow {
    final wc = _windChillC;
    if (wc <= -35) return '5-10 dk (Açık Deri)';
    if (wc <= -25) return '15-30 dk (Açık Deri)';
    if (wc <= -15) return '30-60 dk (Dikkat)';
    if (wc <= 0) return 'Düşük Risk (>60 dk)';
    return 'Donma Riski Yok';
  }

  String get _clothingAdvice {
    final wc = _windChillC;
    if (wc <= -20) {
      return '3 Katman + Kaz Tüyü Mont + Rüzgarlık + Yüz Maskesi + Çift Eldiven (Matarayı vücut içinde taşıyın)';
    }
    if (wc <= -5) {
      return 'Termal İçlik + Kalın Polar + Gore-Tex Kabuk + Bere & Eldiven';
    }
    if (wc <= 5) {
      return 'Nefes Alabilir İçlik + Hafif Polar + Rüzgar Kesici Ceket';
    }
    return 'Standart Trekking Giyim + Yedek Rüzgarlık';
  }

  @override
  Widget build(BuildContext context) {
    final wc = _windChillC;
    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.ac_unit_rounded, color: TacticalStyles.kSecondaryContainer, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'HİPOTERMİ KALKANI PRO',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: TacticalStyles.kOnSurfaceVariant),
            onPressed: _fetchLiveWeather,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TacticalStyles.kSecondaryContainer))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Risk Kartı
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _riskColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${wc.toStringAsFixed(1)}°C',
                        style: TextStyle(color: _riskColor, fontSize: 42, fontWeight: FontWeight.w900),
                      ),
                      const Text(
                        'HİSSEDİLEN (WIND CHILL)',
                        style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _riskTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _riskColor, fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // İrtifa Simülasyonu Slider
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: TacticalStyles.glassCardDecoration(radius: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('HEDEF TIRMANIŞ İRTİFASI (+m)', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800)),
                          Text('+${_extraAltitudeM.toInt()} m', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Slider(
                        value: _extraAltitudeM,
                        min: 0,
                        max: 3000,
                        divisions: 30,
                        activeColor: Colors.amber,
                        inactiveColor: TacticalStyles.kOutlineVariant,
                        onChanged: (v) => setState(() => _extraAltitudeM = v),
                      ),
                      Text(
                        'Tahmini Zirve: ${_projectedTempC.toStringAsFixed(1)}°C • Rüzgar: ${_projectedWindKmh.toStringAsFixed(0)} km/s',
                        style: const TextStyle(color: TacticalStyles.kSecondaryContainer, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _infoCard('DONMA SÜRESİ', _frostbiteWindow, _riskColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        'MATARA DONMA',
                        _projectedTempC <= 0 ? 'Yalıtımlı Kılıf Şart' : 'Normal',
                        _projectedTempC <= 0 ? Colors.amber : TacticalStyles.kTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: TacticalStyles.glassCardDecoration(radius: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.checkroom_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Text('ÖNERİLEN KATMANLAMA', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_clothingAdvice, style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoCard(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: TacticalStyles.glassCardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 9.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
