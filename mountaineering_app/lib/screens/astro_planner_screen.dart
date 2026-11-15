import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/tactical_styles.dart';

class AstroPlannerScreen extends StatefulWidget {
  const AstroPlannerScreen({super.key});

  @override
  State<AstroPlannerScreen> createState() => _AstroPlannerScreenState();
}

class _AstroPlannerScreenState extends State<AstroPlannerScreen> {
  double _lat = 39.92;
  double _lng = 32.85;
  DateTime _selectedDate = DateTime.now();
  bool _gpsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGps();
  }

  Future<void> _loadGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _gpsLoaded = true;
        });
      }
    } catch (_) {}
  }

  // Basitleştirilmiş NOAA güneş doğuşu / batışı hesabı (offline çalışır)
  Map<String, DateTime> _calcSunTimes(DateTime date, double lat, double lng) {
    final dayOfYear = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    final gamma = (2 * math.pi / 365.0) * (dayOfYear - 1);
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma);

    final latRad = lat * math.pi / 180.0;
    final zenRad = 90.833 * math.pi / 180.0;
    final cosHa = (math.cos(zenRad) / (math.cos(latRad) * math.cos(decl))) -
        (math.tan(latRad) * math.tan(decl));
    final clampedCosHa = cosHa.clamp(-0.99, 0.99);
    final haDeg = math.acos(clampedCosHa) * 180.0 / math.pi;

    final tzOffsetMin = date.timeZoneOffset.inMinutes.toDouble();
    final solarNoonMin = 720 - 4 * lng - eqTime + tzOffsetMin;
    final sunriseMin = (solarNoonMin - haDeg * 4).round();
    final sunsetMin = (solarNoonMin + haDeg * 4).round();

    final baseDay = DateTime(date.year, date.month, date.day);
    return {
      'sunrise': baseDay.add(Duration(minutes: sunriseMin)),
      'noon': baseDay.add(Duration(minutes: solarNoonMin.round())),
      'sunset': baseDay.add(Duration(minutes: sunsetMin)),
    };
  }

  // Ay evresi hesabı (0..1)
  double _moonPhaseRatio(DateTime date) {
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    final days = date.toUtc().difference(ref).inHours / 24.0;
    const synodic = 29.53058867;
    final phase = (days % synodic) / synodic;
    return phase < 0 ? phase + 1 : phase;
  }

  String _moonName(double ratio) {
    if (ratio < 0.06 || ratio > 0.94) return 'Yeni Ay (Karanlık Gece)';
    if (ratio < 0.22) return 'Hilal (Büyüyen)';
    if (ratio < 0.30) return 'İlk Dördün';
    if (ratio < 0.45) return 'Şişkin Ay';
    if (ratio < 0.55) return 'Dolunay (Maks. Gece Görüşü)';
    if (ratio < 0.72) return 'Şişkin Ay (Küçülen)';
    if (ratio < 0.80) return 'Son Dördün';
    return 'Hilal (Küçülen)';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sun = _calcSunTimes(_selectedDate, _lat, _lng);
    final sunrise = sun['sunrise']!;
    final noon = sun['noon']!;
    final sunset = sun['sunset']!;
    final goldenStart = sunset.subtract(const Duration(minutes: 45));

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    final totalDayMin = sunset.difference(sunrise).inMinutes.clamp(1, 1440);
    final elapsedMin = isToday
        ? now.difference(sunrise).inMinutes.clamp(0, totalDayMin)
        : (totalDayMin ~/ 2);
    final sunProgress = elapsedMin / totalDayMin;

    final remaining = isToday ? sunset.difference(now) : sunset.difference(sunrise);
    final remText = remaining.isNegative
        ? 'Güneş Battı (Gece Modu)'
        : '${remaining.inHours}s ${(remaining.inMinutes % 60)}dk gün ışığı';

    final moonRatio = _moonPhaseRatio(_selectedDate);
    final moonIllum = ((1 - math.cos(2 * math.pi * moonRatio)) / 2 * 100).round();

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.wb_twilight_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'GÜNEŞ & GECE RADARI PRO',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tarih Seç',
            icon: const Icon(Icons.calendar_today_rounded, color: Colors.amber, size: 19),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Güneş Yayı Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: TacticalStyles.glassCardDecoration(
              radius: 16,
              borderColor: Colors.amber.withOpacity(0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _gpsLoaded ? 'CANLI GPS YÖRÜNGE' : 'VARSAYILAN KONUM',
                      style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    Text(
                      '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                      style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(painter: _SolarArcPainter(sunProgress)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    remText,
                    style: TextStyle(
                      color: remaining.isNegative ? Colors.redAccent : TacticalStyles.kTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Saat Kartları
          Row(
            children: [
              Expanded(child: _timeBox('GÜN DOĞUMU', _fmtTime(sunrise), Colors.orangeAccent)),
              const SizedBox(width: 8),
              Expanded(child: _timeBox('ÖĞLE ZİRVE', _fmtTime(noon), Colors.amber)),
              const SizedBox(width: 8),
              Expanded(child: _timeBox('GÜN BATIMI', _fmtTime(sunset), Colors.deepOrangeAccent)),
            ],
          ),

          const SizedBox(height: 12),

          // Altın Saat & Kamp Kurma Uyarısı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: TacticalStyles.glassCardDecoration(radius: 14),
            child: Row(
              children: [
                const Icon(Icons.nights_stay_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALTIN SAAT & KAMP LİMİTİ: ${_fmtTime(goldenStart)}',
                        style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Karanlık çökmeden çadır kurmak ve sıcak yemek hazırlamak için ideal son pencere.',
                        style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Ay Evresi & Gece Yürüyüşü Görüşü
          Container(
            padding: const EdgeInsets.all(14),
            decoration: TacticalStyles.glassCardDecoration(
              radius: 14,
              borderColor: TacticalStyles.kSecondaryContainer.withOpacity(0.35),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSecondaryContainer.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.nightlight_round, color: TacticalStyles.kSecondaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _moonName(moonRatio),
                        style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gece Ay Aydınlatması: %$moonIllum • ${moonIllum >= 65 ? "Ay ışığında yürüyüş elverişli" : "Kafa lambası zorunlu"}',
                        style: const TextStyle(color: TacticalStyles.kSecondaryContainer, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: TacticalStyles.glassCardDecoration(radius: 12),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SolarArcPainter extends CustomPainter {
  final double progress;
  _SolarArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 16;
    canvas.drawLine(
      Offset(12, baseY),
      Offset(size.width - 12, baseY),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.2,
    );

    final rect = Rect.fromLTWH(20, 14, size.width - 40, (baseY - 14) * 2);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.amber.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final angle = math.pi + (progress.clamp(0.0, 1.0) * math.pi);
    final cx = rect.center.dx + (rect.width / 2) * math.cos(angle);
    final cy = rect.center.dy + (rect.height / 2) * math.sin(angle);

    canvas.drawCircle(Offset(cx, cy), 12, Paint()..color = Colors.amber.withOpacity(0.25));
    canvas.drawCircle(Offset(cx, cy), 6.5, Paint()..color = Colors.amber);
  }

  @override
  bool shouldRepaint(covariant _SolarArcPainter oldDelegate) => oldDelegate.progress != progress;
}
