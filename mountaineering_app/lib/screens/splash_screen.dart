import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '../storage_helper.dart';
import 'onboarding_screen.dart';
import 'app_intro_screen.dart';
import '../services/ad_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isIOS) {
        try {
          await AppTrackingTransparency.requestTrackingAuthorization();
        } catch (e) {
          debugPrint('ATT Error: $e');
        }
      }
      AdService().init();
    });
    _navigateToNext();
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
    const Color kBlue = Color(0xFF00AAFF);
    const Color kRed = Color(0xFFFF2244);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF0D0D14),
              Color(0xFF050508),
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
                // Logo
                FadeIn(
                  duration: const Duration(milliseconds: 1200),
                  child: ZoomIn(
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: kBlue.withOpacity(0.25), blurRadius: 50, spreadRadius: 5),
                          BoxShadow(color: kRed.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon/tactical_logo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.shield, size: 100, color: kBlue),
                        ),
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
                        style: GoogleFonts.shareTechMono(
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
                          style: GoogleFonts.outfit(
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
                        style: GoogleFonts.shareTechMono(
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
                  style: GoogleFonts.shareTechMono(
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
