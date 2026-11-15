import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/premium_service.dart';
import '../services/tactical_styles.dart';

class ArCompassScreen extends StatefulWidget {
  const ArCompassScreen({Key? key}) : super(key: key);

  @override
  State<ArCompassScreen> createState() => _ArCompassScreenState();
}

class _ArCompassScreenState extends State<ArCompassScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  double _heading = 0;
  double _lat = 0;
  double _lng = 0;
  bool _cameraReady = false;
  bool _cameraError = false;
  late AnimationController _pulseController;

  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kGreen = TacticalStyles.kTertiary;

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
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = true);
        return;
      }
      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _cameraController = ctrl;
        _cameraReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
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
    _cameraController?.dispose();
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
      backgroundColor: TacticalStyles.kSurface,
      body: Stack(
        children: [
          // Camera background
          Positioned.fill(
            child: _cameraReady &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize?.height ?? 720,
                      height: _cameraController!.value.previewSize?.width ?? 1280,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                : Container(color: TacticalStyles.kSurface),
          ),

          // AR Dark overlay gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TacticalStyles.kSurfaceLowest.withOpacity(0.6),
                    Colors.transparent,
                    TacticalStyles.kSurfaceLowest.withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ),

          // Top HUD + Heading pill stacked cleanly (zero overlap)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TacticalPressable(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: TacticalStyles.glassCardDecoration(radius: 12),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: kOrange, size: 17),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: TacticalStyles.glassCardDecoration(
                            radius: 999,
                            borderColor: kOrange.withOpacity(0.40),
                          ),
                          child: Text('AR PUSULA HUD', style: TacticalStyles.labelCaps(color: kOrange, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: TacticalStyles.glassCardDecoration(radius: 999),
                          child: Text('ROTA+', style: TacticalStyles.labelMicro(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: TacticalStyles.glassCardDecoration(
                        radius: 16,
                        borderColor: kOrange.withOpacity(0.42),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.explore, color: kOrange, size: 19),
                          const SizedBox(width: 8),
                          Text(
                            '${_heading.toStringAsFixed(1)}°  ${_headingToCardinal(_heading)}',
                            style: TacticalStyles.headline(color: kOrange, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xEB27272E),
                    Color(0xE81C1C22),
                    Color(0xF0141419),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: TacticalStyles.kOutlineVariant),
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
                      _buildHUDItem('BOYLAM', '${_lng.toStringAsFixed(4)}E'),
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
          Container(
            decoration: BoxDecoration(
              color: TacticalStyles.kSurfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TacticalStyles.kOutlineVariant),
            ),
          ),
          // Cardinal marks - simplified
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['B', 'KB', 'K', 'KD', 'D', 'GD', 'G', 'GB', 'B'].map((c) => Text(
                c,
                style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                  color: c == _headingToCardinal(h) ? kOrange : TacticalStyles.kOnSurfaceVariant,
                  fontSize: c == _headingToCardinal(h) ? 13 : 10,
                  fontWeight: c == _headingToCardinal(h) ? FontWeight.bold : FontWeight.w500,
                ),
              )).toList(),
            ),
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
        Text(label, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TacticalStyles.kPrimaryContainer.withOpacity(0.8)
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
      ..color = TacticalStyles.kPrimaryContainer
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
    final northPaint = Paint()..color = TacticalStyles.kPrimaryContainer..style = PaintingStyle.fill;
    final southPaint = Paint()..color = TacticalStyles.kOnSurfaceVariant..style = PaintingStyle.fill;

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
