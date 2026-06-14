import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable visual "juice" for casual games (pure Flutter, no packages).
/// - ConfettiOverlay: one-shot celebratory particle burst (show on win).
/// - AnimatedGradientBackground: slowly shifting gradient for menus/screens.
/// - PressableScale: scales a child down on tap for tactile feedback.

/// One-line win celebration: `Celebrate.show(context);` — inserts a confetti
/// burst over everything and removes itself automatically. No widget-tree changes needed.
class Celebrate {
  static void show(BuildContext context) {
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => ConfettiOverlay(onDone: () {
          try { entry.remove(); } catch (_) {}
        }),
      );
      overlay.insert(entry);
    } catch (_) {}
  }
}

class _Particle {
  double x, y, vx, vy, rot, vrot, size;
  Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.rot, this.vrot, this.size, this.color);
}

/// Place inside a Stack on top of the game when the player wins.
/// It auto-plays once and calls [onDone] when finished.
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback? onDone;
  final int count;
  const ConfettiOverlay({super.key, this.onDone, this.count = 90});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<_Particle> _p = [];
  final _rnd = math.Random();
  static const _colors = [
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF118AB2), Color(0xFF8338EC), Color(0xFFFB5607),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _spawn());
  }

  void _spawn() {
    final size = context.size ?? const Size(400, 700);
    for (var i = 0; i < widget.count; i++) {
      _p.add(_Particle(
        size.width * (0.2 + 0.6 * _rnd.nextDouble()),
        size.height * 0.35,
        (_rnd.nextDouble() - 0.5) * 6,
        -6 - _rnd.nextDouble() * 7,
        _rnd.nextDouble() * math.pi,
        (_rnd.nextDouble() - 0.5) * 0.4,
        6 + _rnd.nextDouble() * 8,
        _colors[_rnd.nextInt(_colors.length)],
      ));
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_p, _c.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final dt = t * 60; // advance
    final paint = Paint();
    for (final p in particles) {
      final px = p.x + p.vx * dt;
      final py = p.y + p.vy * dt + 0.18 * dt * dt; // gravity
      final rot = p.rot + p.vrot * dt;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Slowly shifting gradient background. Wrap your screen body with it.
class AnimatedGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Widget child;
  const AnimatedGradientBackground({super.key, required this.colors, required this.child});

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final a = Alignment(-1 + 2 * _c.value, -1);
        final b = Alignment(1 - 2 * _c.value, 1);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors, begin: a, end: b),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Rich, slowly drifting premium background: a deep radial gradient with a few
/// soft out-of-focus "bokeh" orbs floating upward. Wrap your screen body with it.
class PremiumBackground extends StatefulWidget {
  /// 3 colors, center → mid → edge of the radial gradient.
  final List<Color> colors;
  final Color bokeh;
  final Widget child;
  const PremiumBackground({
    super.key,
    required this.colors,
    required this.bokeh,
    required this.child,
  });

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _orbs = [
    [0.18, 0.34, 0.7, 0.0],
    [0.78, 0.46, 0.5, 0.3],
    [0.50, 0.28, 0.9, 0.6],
    [0.30, 0.40, 0.6, 0.15],
    [0.86, 0.30, 0.8, 0.8],
    [0.10, 0.26, 1.0, 0.45],
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 1.25,
          colors: widget.colors,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _BokehPainter(_c.value, widget.bokeh),
                size: Size.infinite,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  final double t;
  final Color color;
  _BokehPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in _PremiumBackgroundState._orbs) {
      final x = o[0] * size.width;
      final prog = (t * o[2] + o[3]) % 1.0;
      final y = size.height * (1.15 - 1.3 * prog);
      final r = o[1] * size.width * 0.5;
      final fade = (1 - (prog - 0.5).abs() * 2).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.10 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BokehPainter old) => old.t != t;
}

/// One-shot sparkle/star burst at a point — use when a bottle is fully sorted.
class BurstOverlay {
  static void show(BuildContext context, Offset globalPos, Color color) {
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _Burst(
          pos: globalPos,
          color: color,
          onDone: () {
            try {
              entry.remove();
            } catch (_) {}
          },
        ),
      );
      overlay.insert(entry);
    } catch (_) {}
  }
}

class _Burst extends StatefulWidget {
  final Offset pos;
  final Color color;
  final VoidCallback onDone;
  const _Burst({required this.pos, required this.color, required this.onDone});

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.pos.dx,
      top: widget.pos.dy,
      child: IgnorePointer(
        child: CustomPaint(painter: _BurstPainter(_c.value, widget.color)),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;
  _BurstPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const n = 10;
    final dist = 8 + t * 46;
    final opacity = (1 - t).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      6 + t * 40,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * opacity
        ..color = Colors.white.withValues(alpha: 0.6 * opacity),
    );
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi;
      final p = Offset(math.cos(a) * dist, math.sin(a) * dist);
      final s = (4 - t * 2.5).clamp(0.5, 4.0);
      final paint = Paint()
        ..color = (i.isEven ? color : Colors.white).withValues(alpha: opacity);
      canvas.drawCircle(p, s, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

/// Wrap a tappable widget: scales down briefly when pressed.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const PressableScale({super.key, required this.child, this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}
