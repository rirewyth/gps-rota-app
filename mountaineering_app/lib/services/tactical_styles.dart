import 'dart:ui';
import 'package:flutter/material.dart';

class TacticalStyles {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kGreen = Color(0xFF62FF4C);
  static const Color kCardBg = Color(0xFF141414);
  
  /// Glassmorphic Box Decoration (Simplified for AOT stability)
  static BoxDecoration glassDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.08),
        width: 1,
      ),
    );
  }

  /// Tactical Blur Filter
  static Widget glassEffect({required Widget child}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: child,
      ),
    );
  }
}

class PulsingStatusIndicator extends StatefulWidget {
  const PulsingStatusIndicator({Key? key}) : super(key: key);

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
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: TacticalStyles.kGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: TacticalStyles.kGreen.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            )
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
      duration: const Duration(seconds: 1),
    );
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withOpacity(0.15),
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
            border: widget.isActive ? Border.all(color: _colorAnimation.value ?? Colors.transparent, width: 4) : null,
            boxShadow: widget.isActive ? [BoxShadow(color: _colorAnimation.value ?? Colors.transparent, blurRadius: 40, spreadRadius: 10)] : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}
