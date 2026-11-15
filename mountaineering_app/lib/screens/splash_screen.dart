import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '../storage_helper.dart';
import 'onboarding_screen.dart';
import 'app_intro_screen.dart';
import '../services/ad_service.dart';
import '../services/tactical_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _initAndNavigate();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initAndNavigate() async {
    // Biraz bekle, ekran çizilsin (ATT'nin çıkması için gerekiyor)
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // 1. Önce ATT iste (sadece iOS)
    if (Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('ATT Status: $status');
      } catch (e) {
        debugPrint('ATT Error: $e');
      }
    }
    // 2. Ardından AdService başlat
    AdService().init();
    // 3. Son olarak navigasyona devam et
    await _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 4000));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    // 1. İlk kez mi açılıyor? — App Intro göster
    final introSeen = prefs.getBool('app_intro_seen_v1') ?? false;
    if (!introSeen) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppIntroScreen()),
      );
      return;
    }

    // 2. Giriş yok — login'e gönder
    final isLoggedIn = await StorageHelper.isUserLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // 3. Onboarding tamamlanmamış — onboarding'e gönder
    final onboardingDone = prefs.getBool('onboarding_complete_v1') ?? false;
    if (!mounted) return;
    if (!onboardingDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(nextRoute: '/home'),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color kBlue = TacticalStyles.kSecondaryContainer;
    const Color kRed = TacticalStyles.kPrimaryContainer;

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              TacticalStyles.kSurfaceLow,
              TacticalStyles.kSurfaceLowest,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Arka plan glow efekti
            Positioned(
              top: 100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: kBlue.withOpacity(0.06), blurRadius: 120, spreadRadius: 40),
                    BoxShadow(color: kRed.withOpacity(0.04), blurRadius: 80, spreadRadius: 20),
                  ],
                ),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animasyonlu Şeffaf PNG Logo + Taktik Radar Halkası
                FadeIn(
                  duration: const Duration(milliseconds: 900),
                  child: ZoomIn(
                    duration: const Duration(milliseconds: 800),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_orbitController, _pulseController]),
                      builder: (context, child) {
                        final pulse = _pulseController.value;
                        final scale = 0.985 + (pulse * 0.03);
                        return SizedBox(
                          width: 270,
                          height: 270,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Nefes alan arka plan ışık halesi
                              Container(
                                width: 220 + (pulse * 18),
                                height: 220 + (pulse * 18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: kBlue.withOpacity(0.18 + pulse * 0.12),
                                      blurRadius: 48,
                                      spreadRadius: 6,
                                    ),
                                    BoxShadow(
                                      color: kRed.withOpacity(0.14 + pulse * 0.10),
                                      blurRadius: 34,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              // Dönen taktik radar halkası
                              Transform.rotate(
                                angle: _orbitController.value * 2 * math.pi,
                                child: CustomPaint(
                                  size: const Size(264, 264),
                                  painter: _SplashRadarRingPainter(
                                    primaryColor: kRed,
                                    secondaryColor: kBlue,
                                  ),
                                ),
                              ),
                              // Şeffaf PNG Logo
                              Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            ],
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/icon/tactical_logo.png',
                        width: 226,
                        height: 226,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.shield, size: 100, color: kBlue),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // App Name
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'ACİL DURUM APP',
                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                          fontSize: 18,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [kBlue, kRed],
                        ).createShader(bounds),
                        child: Text(
                          'ROTA+',
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HAYAT KURTARAN TEKNOLOJİ',
                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                          fontSize: 13,
                          color: Colors.white38,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Loading indicator
                FadeIn(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 1200),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kBlue.withOpacity(0.8)),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom text
            Positioned(
              bottom: 36,
              child: FadeIn(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(seconds: 2),
                child: Text(
                  'POWERED BY ADVANCED SAFETY SYSTEMS',
                  style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                    fontSize: 8,
                    color: Colors.white12,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashRadarRingPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const _SplashRadarRingPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final baseRing = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, baseRing);

    final primaryArc = Paint()
      ..color = primaryColor.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 4, math.pi * 0.45, false, primaryArc);

    final secondaryArc = Paint()
      ..color = secondaryColor.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 0.35, false, secondaryArc);

    final dotPaint = Paint()..color = primaryColor;
    final dotPos = Offset(
      center.dx + radius * math.cos(-math.pi / 4),
      center.dy + radius * math.sin(-math.pi / 4),
    );
    canvas.drawCircle(dotPos, 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashRadarRingPainter oldDelegate) => false;
}
