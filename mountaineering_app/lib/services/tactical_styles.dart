import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ROTA+ — Tactical Liquid Glass Tasarım Sistemi (Stitch Referanslı)
/// Koyu obsidyen zemin (#131317), kontrollü sıvı cam efekti, ince speküler yansımalar,
/// Space Grotesk / Inter / JetBrains Mono (tabular-nums) tipografi.
class TacticalStyles {
  // ── TACTICAL LIQUID GLASS RENK PALETİ (tactical_liquid_glass/DESIGN.md) ───
  static const Color kSurface = Color(0xFF131317); // Ana arka plan
  static const Color kSurfaceLowest = Color(0xFF0E0E12); // En koyu yüzey
  static const Color kSurfaceLow = Color(0xFF1B1B20); // Kart yüzeyi (alt)
  static const Color kSurfaceContainer = Color(0xFF1F1F24); // Yükseltilmiş kart
  static const Color kSurfaceHigh = Color(0xFF2A292E); // Daha yüksek yüzey
  static const Color kSurfaceHighest = Color(0xFF353439); // Vurgulu/aktif yüzey
  static const Color kSurfaceBright = Color(0xFF39393E);

  static const Color kOnSurface = Color(0xFFE4E1E8); // Ana metin
  static const Color kOnSurfaceVariant = Color(0xFFE5BEB2); // İkincil metin
  static const Color kOutline = Color(0xFFAC897E); // Teknik etiket / kontur
  static const Color kOutlineVariant = Color(0xFF5C4037); // İkincil sınır

  // Primary (Ana vurgu / SOS / Güvenlik Kehribarı)
  static const Color kPrimary = Color(0xFFFFB59C);
  static const Color kOnPrimary = Color(0xFF5C1900);
  static const Color kPrimaryContainer = Color(0xFFFF5708);
  static const Color kOnPrimaryContainer = Color(0xFF511500);
  static const Color kPrimaryFixed = Color(0xFFFFDBCF);

  // Secondary (Navigasyon / Telemetri / Radar Cyan)
  static const Color kSecondary = Color(0xFFBDF4FF);
  static const Color kOnSecondary = Color(0xFF00363D);
  static const Color kSecondaryContainer = Color(0xFF00E3FD);
  static const Color kOnSecondaryContainer = Color(0xFF00616D);

  // Tertiary (Güvenli / Bağlantı Aktif / Doğrulanmış Yeşil)
  static const Color kTertiary = Color(0xFF4EDEA3);
  static const Color kOnTertiary = Color(0xFF003824);
  static const Color kTertiaryContainer = Color(0xFF00A572);
  static const Color kOnTertiaryContainer = Color(0xFF00311F);

  // Error (Tehlike / Hata / Kritik Durum)
  static const Color kError = Color(0xFFFFB4AB);
  static const Color kOnError = Color(0xFF690005);
  static const Color kErrorContainer = Color(0xFF93000A);
  static const Color kOnErrorContainer = Color(0xFFFFDAD6);

  // Cam Yüzey & Speküler Kenarlık Sabitleri
  static const Color kGlassSurface = Color(0xA6141620); // rgba(20, 22, 32, 0.65)
  static const Color kGlassBorder = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.10)
  static const Color kSpecularHighlight = Color(0x2EFFFFFF); // rgba(255, 255, 255, 0.18)

  // Ekranlar arası uyumluluk sabitleri
  static const Color kOrange = kPrimaryContainer;
  static const Color kGreen = kTertiary;
  static const Color kCyan = kSecondaryContainer;
  static const Color kCardBg = kSurfaceContainer;
  static const Color kBackground = kSurface;
  static const Color kTextPrimary = kOnSurface;
  static const Color kTextSecondary = kOnSurfaceVariant;

  // ── TİPOGRAFİ (Helvetica + Tabular Figures) ─────────────────────────────
  static const String kHelveticaFont = 'Helvetica';
  static const List<String> kHelveticaFallback = [
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];
  static TextStyle heroMetric({
    double size = 40,
    Color color = kOnSurface,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
  }) {
    return displayHero(
      fontSize: size,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle monoLabel({
    double size = 11,
    Color color = kOnSurfaceVariant,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.8,
  }) {
    return labelCaps(
      fontSize: size,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle monoValue({
    double size = 13,
    Color color = kOnSurface,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.3,
  }) {
    return telemetry(
      fontSize: size,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle displayHero({
    double fontSize = 40,
    double? size,
    Color color = kOnSurface,
    FontWeight fontWeight = FontWeight.w700,
    FontWeight? weight,
    double? height,
  }) {
    return TextStyle(
      fontFamily: kHelveticaFont,
      fontFamilyFallback: kHelveticaFallback,
      fontSize: size ?? fontSize,
      fontWeight: weight ?? fontWeight,
      color: color,
      height: height ?? 1.15,
      letterSpacing: -0.6,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle headline({
    double fontSize = 20,
    double? size,
    Color color = kOnSurface,
    FontWeight fontWeight = FontWeight.w600,
    FontWeight? weight,
    double letterSpacing = -0.2,
  }) {
    return TextStyle(
      fontFamily: kHelveticaFont,
      fontFamilyFallback: kHelveticaFallback,
      fontSize: size ?? fontSize,
      fontWeight: weight ?? fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle body({
    double fontSize = 14,
    double? size,
    Color color = kOnSurface,
    FontWeight fontWeight = FontWeight.w400,
    FontWeight? weight,
    double? height,
  }) {
    return TextStyle(
      fontFamily: kHelveticaFont,
      fontFamilyFallback: kHelveticaFallback,
      fontSize: size ?? fontSize,
      fontWeight: weight ?? fontWeight,
      color: color,
      height: height ?? 1.45,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle telemetry({
    double fontSize = 13,
    double? size,
    Color color = kOnSurface,
    FontWeight fontWeight = FontWeight.w600,
    FontWeight? weight,
    double letterSpacing = 0.3,
  }) {
    return TextStyle(
      fontFamily: kHelveticaFont,
      fontFamilyFallback: kHelveticaFallback,
      fontSize: size ?? fontSize,
      fontWeight: weight ?? fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle labelCaps({
    double fontSize = 11,
    double? size,
    Color color = kOutline,
    FontWeight fontWeight = FontWeight.w700,
    FontWeight? weight,
    double letterSpacing = 0.8,
  }) {
    return TextStyle(
      fontFamily: kHelveticaFont,
      fontFamilyFallback: kHelveticaFallback,
      fontSize: size ?? fontSize,
      fontWeight: weight ?? fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle labelMicro({
    double fontSize = 9.5,
    double? size,
    Color color = kOutline,
    FontWeight fontWeight = FontWeight.w500,
    FontWeight? weight,
    double letterSpacing = 0.6,
  }) {
    return TextStyle(
      fontFamily: kHelveticaFont,
      fontFamilyFallback: kHelveticaFallback,
      fontSize: size ?? fontSize,
      fontWeight: weight ?? fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ── TACTICAL LIQUID GLASS KART & YÜZEY DEKORASYONLARI ───────────────────
  static BoxDecoration glassCardDecoration({
    Color? borderColor,
    Color? backgroundColor,
    double radius = 16,
    Color? glowColor,
  }) {
    return glassDecoration(
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      radius: radius,
      glowColor: glowColor,
    );
  }

  static Widget appBarPill(
    String title, {
    Color color = kPrimary,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: glassCardDecoration(
        radius: 999,
        borderColor: color.withValues(alpha: 0.45),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            title,
            style: labelCaps(
              color: color,
              size: 11,
              weight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  static BoxDecoration glassDecoration({
    Color? borderColor,
    Color? backgroundColor,
    double radius = 16,
    Color? glowColor,
  }) {
    final effectiveBorder = borderColor ?? const Color(0x1FFFFFFF);
    final baseColor = backgroundColor ?? kSurfaceContainer;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: backgroundColor != null
            ? [
                Color.alphaBlend(Colors.white.withOpacity(0.045), baseColor),
                baseColor,
                Color.alphaBlend(Colors.black.withOpacity(0.18), baseColor),
              ]
            : const [
                Color(0xF227272E),
                Color(0xEB1C1C22),
                Color(0xF5141419),
              ],
        stops: const [0.0, 0.46, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: effectiveBorder,
        width: 1,
      ),
      boxShadow: [
        // Top specular rim micro-refraction
        BoxShadow(
          color: Colors.white.withOpacity(0.055),
          offset: const Offset(0, -1),
          blurRadius: 1,
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.20),
            blurRadius: 22,
            spreadRadius: 0,
          ),
        BoxShadow(
          color: Colors.black.withOpacity(0.46),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration recessedDecoration({
    Color? borderColor,
    double radius = 12,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xF00B0B0F),
          Color(0xEB111116),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.07),
        width: 1,
      ),
    );
  }

  static BoxDecoration capsuleDecoration({
    Color? backgroundColor,
    Color? borderColor,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? kSurfaceHigh.withOpacity(0.88),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.10),
        width: 1,
      ),
      boxShadow: [
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        BoxShadow(
          color: Colors.black.withOpacity(0.30),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static Widget glassEffect({
    required Widget child,
    double radius = 16,
    double blur = 24,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }
}

class PulsingStatusIndicator extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingStatusIndicator({
    Key? key,
    this.color = TacticalStyles.kTertiary,
    this.size = 8,
  }) : super(key: key);

  @override
  State<PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.55),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class SOSAtmosphere extends StatefulWidget {
  final Widget child;
  final bool isActive;
  const SOSAtmosphere({Key? key, required this.child, required this.isActive}) : super(key: key);

  @override
  State<SOSAtmosphere> createState() => _SOSAtmosphereState();
}

class _SOSAtmosphereState extends State<SOSAtmosphere> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: TacticalStyles.kPrimaryContainer.withOpacity(0.28),
    ).animate(_controller);

    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SOSAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive) {
      _controller.stop();
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            border: widget.isActive
                ? Border.all(color: _colorAnimation.value ?? Colors.transparent, width: 2.5)
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Dokunsal geri bildirim (Haptic) ve mikro-ölçek (0.97) tepkili taktiksel sarıcı
class TacticalPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const TacticalPressable({
    Key? key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
  }) : super(key: key);

  @override
  State<TacticalPressable> createState() => _TacticalPressableState();
}

class _TacticalPressableState extends State<TacticalPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() => _pressed = true);
          HapticFeedback.selectionClick();
        }
      },
      onTapUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Canlı dolum animasyonlu ve uç noktasında parlayan sinyalli telemetri barı
class TacticalAnimatedBar extends StatelessWidget {
  final double factor;
  final Color color;
  final double height;

  const TacticalAnimatedBar({
    Key? key,
    required this.factor,
    required this.color,
    this.height = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double clamped = factor.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: clamped),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animVal, _) {
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: TacticalStyles.kSurfaceHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: animVal,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.55),
                    color,
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.65),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

