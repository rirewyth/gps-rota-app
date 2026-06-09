import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({Key? key}) : super(key: key);

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _bgAnim;
  late AnimationController _iconAnim;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotate;

  static const _slides = [
    _IntroSlide(
      icon: Icons.crisis_alert,
      accentColor: Color(0xFFFF2244),
      bgColorA: Color(0xFF1A0008),
      bgColorB: Color(0xFF0A0A0A),
      tag: 'ACİL DURUM',
      title: 'SOS — Tek Dokunuş,\nHayat Kurtarır',
      desc:
          'SOS butonuna bas, konumun otomatik olarak acil kişine SMS ile gönderilsin. Sesli komutla bile tetiklenebilir.',
      badge: '🆘',
    ),
    _IntroSlide(
      icon: Icons.radar,
      accentColor: Color(0xFF00AAFF),
      bgColorA: Color(0xFF00111A),
      bgColorB: Color(0xFF0A0A0A),
      tag: 'EKİP RADARI',
      title: 'Ekibinin Konumunu\nAnlık Gör',
      desc:
          'Tüm ekip üyelerinin gerçek zamanlı konumunu haritada izle. Kayıp üye olduğunda anında uyarı al.',
      badge: '📡',
    ),
    _IntroSlide(
      icon: Icons.groups,
      accentColor: Color(0xFF62FF4C),
      bgColorA: Color(0xFF001A00),
      bgColorB: Color(0xFF0A0A0A),
      tag: 'EKİP YÖNETİMİ',
      title: 'Ekip Kur,\nKoordine Ol',
      desc:
          'Ekip oluştur, üye ekle, ortak görevler belirle. SOS anında tüm ekip aynı anda bilgilendirilsin.',
      badge: '🤝',
    ),
    _IntroSlide(
      icon: Icons.dynamic_feed,
      accentColor: Color(0xFFFFD700),
      bgColorA: Color(0xFF1A1400),
      bgColorB: Color(0xFF0A0A0A),
      tag: 'SOSYAL AKIŞ',
      title: 'Dağcıların\nSosyal Dünyası',
      desc:
          'Diğer dağcıların rotalarını, fotoğraflarını ve deneyimlerini keşfet. Beğen, yorum yap, ilham al.',
      badge: '🏔️',
    ),
    _IntroSlide(
      icon: Icons.map,
      accentColor: Color(0xFFFF6B00),
      bgColorA: Color(0xFF1A0800),
      bgColorB: Color(0xFF0A0A0A),
      tag: 'ROTA PLANLAMA',
      title: 'Profesyonel\nRota Planla',
      desc:
          'Topografik harita üzerinde waypoint ekle, yükseklik profili gör, GPX olarak dışa aktar. Offline çalışır.',
      badge: '🗺️',
    ),
    _IntroSlide(
      icon: Icons.share_location,
      accentColor: Color(0xFFAA44FF),
      bgColorA: Color(0xFF0D0018),
      bgColorB: Color(0xFF0A0A0A),
      tag: 'ROTA PAYLAŞMA',
      title: 'Rotanı Paylaş,\nBirlikte Keşfet',
      desc:
          'Planladığın rotayı ekibinle veya tüm toplulukla paylaş. Canlı takipte konumunu gerçek zamanlı yayınla.',
      badge: '📍',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _iconAnim = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _iconScale = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _iconAnim, curve: Curves.easeInOut));
    _iconRotate = Tween<double>(begin: -0.05, end: 0.05)
        .animate(CurvedAnimation(parent: _iconAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _iconAnim.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_intro_seen_v1', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    return Scaffold(
      body: Stack(
        children: [
          // Animated background (Isolated rebuilds)
          _AnimatedBackground(slide: slide, bgAnim: _bgAnim),

          // Grid lines (subtle)
          CustomPaint(
            painter: _GridPainter(slide.accentColor),
            size: Size.infinite,
          ),

          // Main content (Non-rebuilding core)
          Column(
            children: [
              const SizedBox(height: 56),

              // Top bar: Skip button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page count
                    Text(
                      '${_currentPage + 1}/${_slides.length}',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white24,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    // Skip button
                    GestureDetector(
                      onTap: _complete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ATLA',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white38,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Progress bar (thin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(_slides.length, (i) {
                    final active = i == _currentPage;
                    final done = i < _currentPage;
                    return Expanded(
                      flex: active ? 3 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: done || active
                              ? slide.accentColor
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // PageView (swipeable) - This stays stable
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (ctx, i) => _buildSlide(_slides[i]),
                ),
              ),

              // Bottom navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? _slides[_currentPage].accentColor
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),

                    // Next / Start button
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              slide.accentColor,
                              slide.accentColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: slide.accentColor.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _slides.length - 1
                                  ? 'HEMEN BAŞLA'
                                  : 'DEVAM ET',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              _currentPage == _slides.length - 1
                                  ? Icons.rocket_launch
                                  : Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_IntroSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container
          AnimatedBuilder(
            animation: _iconAnim,
            builder: (ctx, _) {
              return Transform.scale(
                scale: _iconScale.value,
                child: Transform.rotate(
                  angle: _iconRotate.value,
                  child: FadeIn(
                    duration: const Duration(milliseconds: 600),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: slide.accentColor.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                        ),
                        // Middle ring
                        Container(
                          width: 145,
                          height: 145,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: slide.accentColor.withOpacity(0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Icon circle
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: slide.accentColor.withOpacity(0.12),
                            border: Border.all(
                              color: slide.accentColor.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: slide.accentColor.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            slide.icon,
                            color: slide.accentColor,
                            size: 48,
                          ),
                        ),
                        // Badge emoji
                        Positioned(
                          top: 10,
                          right: 20,
                          child: Text(slide.badge, style: const TextStyle(fontSize: 28)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Tag
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: slide.accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: slide.accentColor.withOpacity(0.4)),
              ),
              child: Text(
                slide.tag,
                style: GoogleFonts.shareTechMono(
                  color: slide.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 500),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, slide.accentColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                slide.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Description
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 500),
            child: Text(
              slide.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Background (Isolated for Performance) ──────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final _IntroSlide slide;
  final AnimationController bgAnim;

  const _AnimatedBackground({Key? key, required this.slide, required this.bgAnim}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgAnim,
      builder: (context, _) {
        return Stack(
          children: [
            // Base Gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [slide.bgColorA, slide.bgColorB],
                ),
              ),
            ),

            // Animated glow blob
            Positioned(
              top: -60 + (bgAnim.value * 30),
              right: -60 + (bgAnim.value * 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.accentColor.withOpacity(0.08 + bgAnim.value * 0.04),
                ),
              ),
            ),

            Positioned(
              bottom: -80 + (bgAnim.value * 20),
              left: -40,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.accentColor.withOpacity(0.05),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Data class ──────────────────────────────────────────────────────────────
class _IntroSlide {
  final IconData icon;
  final Color accentColor;
  final Color bgColorA;
  final Color bgColorB;
  final String tag;
  final String title;
  final String desc;
  final String badge;

  const _IntroSlide({
    required this.icon,
    required this.accentColor,
    required this.bgColorA,
    required this.bgColorB,
    required this.tag,
    required this.title,
    required this.desc,
    required this.badge,
  });
}

// ── Subtle grid background ──────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}
