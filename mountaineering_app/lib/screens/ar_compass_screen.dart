import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
// import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/premium_service.dart';

class ArCompassScreen extends StatefulWidget {
  const ArCompassScreen({Key? key}) : super(key: key);

  @override
  State<ArCompassScreen> createState() => _ArCompassScreenState();
}

class _ArCompassScreenState extends State<ArCompassScreen>
    with TickerProviderStateMixin {
  // CameraController? _cameraController;
  double _heading = 0;
  double _lat = 0;
  double _lng = 0;
  bool _cameraReady = false;
  bool _cameraError = false;
  late AnimationController _pulseController;

  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kGreen = Color(0xFF62FF4C);

  @override
  void initState() {
    super.initState();
    _checkPremiumAndInit();
  }

  Future<void> _checkPremiumAndInit() async {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initCamera();
    _startCompass();
    _getLocation();
  }

  Future<void> _initCamera() async {
    if (mounted) setState(() => _cameraError = true);
  }

  void _startCompass() {
    FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading ?? 0);
    });
  }

  Future<void> _getLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) setState(() { _lat = pos.latitude; _lng = pos.longitude; });
    } catch (_) {}
  }

  @override
  void dispose() {
    // _cameraController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _headingToCardinal(double h) {
    final h360 = (h + 360) % 360;
    if (h360 < 22.5 || h360 >= 337.5) return 'K';
    if (h360 < 67.5) return 'KD';
    if (h360 < 112.5) return 'D';
    if (h360 < 157.5) return 'GD';
    if (h360 < 202.5) return 'G';
    if (h360 < 247.5) return 'GB';
    if (h360 < 292.5) return 'B';
    return 'KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera background
          Positioned.fill(child: Container(color: Colors.black)),

          // AR Dark overlay gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),

          // Top HUD
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black45,
                        child: const Icon(Icons.arrow_back_ios, color: kOrange, size: 18),
                      ),
                    ),
                    Text('AR PUSULA', style: GoogleFonts.shareTechMono(color: kOrange, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black45,
                      child: Text('ROTA+', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Heading compass strip at top
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                color: Colors.black54,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore, color: kOrange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_heading.toStringAsFixed(1)}°  ${_headingToCardinal(_heading)}',
                      style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center AR Crosshair / Targeting reticle
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing ring
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 160 + (_pulseController.value * 20),
                    height: 160 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kOrange.withOpacity(0.3 - _pulseController.value * 0.3), width: 2),
                    ),
                  ),
                ),
                // Static outer ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kOrange.withOpacity(0.6), width: 1),
                  ),
                ),
                // Crosshair
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _CrosshairPainter(),
                ),
                // Compass needle rotating
                AnimatedRotation(
                  turns: -_heading / 360,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(painter: _NeedlePainter()),
                  ),
                ),
                // Center dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kOrange,
                  ),
                ),
              ],
            ),
          ),

          // Bottom HUD - Coordinates & Status
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  // Cardinal compass bar
                  _buildCompassBar(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHUDItem('KOORDİNAT', '${_lat.toStringAsFixed(4)}N'),
                      _buildHUDItem('BOYLAMM', '${_lng.toStringAsFixed(4)}E'),
                      _buildHUDItem('İSTİKAMET', '${_heading.toStringAsFixed(0)}°'),
                      _buildHUDItem('YÖN', _headingToCardinal(_heading)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHUDItem('MANYETİK ALAN', 'NORMAL'),
                      _buildHUDItem('SAPMA', '+0.5°'),
                      _buildHUDItem('PITCH/ROLL', '±0°'),
                      _buildHUDItem('GPS SİNYALİ', '±4M'),
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

  Widget _buildCompassBar() {
    // Simple cardinal directions bar with a center marker
    final h = (_heading + 360) % 360;
    return SizedBox(
      height: 28,
      child: Stack(
        children: [
          // Background
          Container(color: Colors.black38),
          // Cardinal marks - simplified
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['B', 'KB', 'K', 'KD', 'D', 'GD', 'G', 'GB', 'B'].map((c) => Text(
              c,
              style: GoogleFonts.shareTechMono(
                color: c == _headingToCardinal(h) ? kOrange : Colors.white38,
                fontSize: c == _headingToCardinal(h) ? 13 : 10,
                fontWeight: c == _headingToCardinal(h) ? FontWeight.bold : FontWeight.normal,
              ),
            )).toList(),
          ),
          // Center tick
          Center(
            child: Container(width: 2, height: 28, color: kOrange),
          ),
        ],
      ),
    );
  }

  Widget _buildHUDItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 8, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Cross lines
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx - 10, cy), paint);
    canvas.drawLine(Offset(cx + 10, cy), Offset(cx + 30, cy), paint);
    canvas.drawLine(Offset(cx, cy - 30), Offset(cx, cy - 10), paint);
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx, cy + 30), paint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFFFF6B00)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final bSize = 20.0;
    final bOff = 60.0;
    // Top-left
    canvas.drawLine(Offset(cx - bOff, cy - bOff + bSize), Offset(cx - bOff, cy - bOff), bracketPaint);
    canvas.drawLine(Offset(cx - bOff, cy - bOff), Offset(cx - bOff + bSize, cy - bOff), bracketPaint);
    // Top-right
    canvas.drawLine(Offset(cx + bOff, cy - bOff + bSize), Offset(cx + bOff, cy - bOff), bracketPaint);
    canvas.drawLine(Offset(cx + bOff, cy - bOff), Offset(cx + bOff - bSize, cy - bOff), bracketPaint);
    // Bottom-left
    canvas.drawLine(Offset(cx - bOff, cy + bOff - bSize), Offset(cx - bOff, cy + bOff), bracketPaint);
    canvas.drawLine(Offset(cx - bOff, cy + bOff), Offset(cx - bOff + bSize, cy + bOff), bracketPaint);
    // Bottom-right
    canvas.drawLine(Offset(cx + bOff, cy + bOff - bSize), Offset(cx + bOff, cy + bOff), bracketPaint);
    canvas.drawLine(Offset(cx + bOff, cy + bOff), Offset(cx + bOff - bSize, cy + bOff), bracketPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // North pointer (red/orange)
    final northPaint = Paint()..color = const Color(0xFFFF6B00)..style = PaintingStyle.fill;
    final southPaint = Paint()..color = Colors.white38..style = PaintingStyle.fill;

    final northPath = Path()
      ..moveTo(cx, cy - 45)
      ..lineTo(cx - 6, cy)
      ..lineTo(cx + 6, cy)
      ..close();
    canvas.drawPath(northPath, northPaint);

    final southPath = Path()
      ..moveTo(cx, cy + 45)
      ..lineTo(cx - 6, cy)
      ..lineTo(cx + 6, cy)
      ..close();
    canvas.drawPath(southPath, southPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
