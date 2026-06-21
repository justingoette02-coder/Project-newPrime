import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/gamification.dart';
import 'aura_orb.dart';

/// Provisorische "Aura-Augen" (Platzhalter fuer das spaetere Rive-Asset).
/// Zwei leuchtende Anime-Augen, deren Farbe und Intensitaet von der Stufe
/// abhaengen (BAUPLAN Abschnitt 5). Hoehere Stufen: hellere Iris, Stern-Burst,
/// staerkeres Glühen. [dimmed] => Aura verblasst (Streak in Gefahr).
class AuraEyes extends StatefulWidget {
  final AuraTier tier;
  final double width;
  final bool dimmed;

  const AuraEyes({
    super.key,
    required this.tier,
    this.width = 120,
    this.dimmed = false,
  });

  @override
  State<AuraEyes> createState() => _AuraEyesState();
}

class _AuraEyesState extends State<AuraEyes> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    // Puls: hoehere Stufe -> schneller/intensiver.
    final seconds = (5 - widget.tier.index * 0.4).clamp(2.0, 5.0);
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (seconds * 1000).round()),
    )..repeat(reverse: true);

    // Blinzeln in unregelmaessigen Abstaenden.
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scheduleBlink();
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
          Duration(milliseconds: 2600 + math.Random().nextInt(2600)));
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AuraOrb.colorForTier(widget.tier.index);
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _blink]),
      builder: (context, _) {
        return SizedBox(
          width: widget.width,
          height: widget.width * 0.5,
          child: CustomPaint(
            painter: _EyesPainter(
              color: widget.dimmed ? AppColors.textTertiary : color,
              tierIndex: widget.tier.index,
              pulse: _pulse.value,
              blink: _blink.value,
              dimmed: widget.dimmed,
            ),
          ),
        );
      },
    );
  }
}

class _EyesPainter extends CustomPainter {
  final Color color;
  final int tierIndex;
  final double pulse; // 0..1
  final double blink; // 0 = offen, 1 = geschlossen
  final bool dimmed;

  _EyesPainter({
    required this.color,
    required this.tierIndex,
    required this.pulse,
    required this.blink,
    required this.dimmed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final eyeW = size.width * 0.42;
    final eyeH = size.height * 0.9 * (1 - 0.85 * blink);
    final cy = size.height / 2;
    final leftC = Offset(size.width * 0.26, cy);
    final rightC = Offset(size.width * 0.74, cy);
    final intensity = tierIndex / 6.0;

    for (final c in [leftC, rightC]) {
      _drawEye(canvas, c, eyeW, eyeH, intensity);
    }
  }

  void _drawEye(
      Canvas canvas, Offset c, double eyeW, double eyeH, double intensity) {
    // Mandelfoermige Augenkontur.
    final eyePath = _almond(c, eyeW, eyeH);

    // Aussen-Glühen (intensiver bei hoeheren Stufen + Puls).
    if (!dimmed) {
      final glow = Paint()
        ..color = color.withAlpha(
            (((0.18 + 0.35 * intensity) * (0.7 + 0.3 * pulse)) * 255).round())
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, 6 + 10 * intensity * (0.8 + 0.2 * pulse));
      canvas.drawPath(eyePath, glow);
    }

    // Dunkler Augapfel-Hintergrund.
    canvas.drawPath(eyePath, Paint()..color = AppColors.bg);

    // Clip auf die Augenform fuer Iris/Glanz.
    canvas.save();
    canvas.clipPath(eyePath);

    // Iris als radialer Verlauf.
    final irisR = eyeH * 0.62;
    final irisRect = Rect.fromCircle(center: c, radius: irisR);
    final irisPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(color, Colors.white, dimmed ? 0.0 : 0.35)!,
          color,
          color.withAlpha(38),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(irisRect);
    canvas.drawCircle(c, irisR, irisPaint);

    // Stern-Burst in der Iris ab Stufe 3.
    if (tierIndex >= 3 && !dimmed) {
      final burst = Paint()
        ..color = Colors.white
            .withAlpha(((0.55 * (0.6 + 0.4 * pulse)) * 255).round())
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final rays = 4 + (tierIndex - 3) * 2; // mehr Strahlen bei hoeherer Stufe
      for (int i = 0; i < rays; i++) {
        final a = (math.pi * 2 / rays) * i + pulse * 0.4;
        final len = irisR * (0.55 + 0.25 * pulse);
        canvas.drawLine(
          c,
          Offset(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len),
          burst,
        );
      }
    }

    // Pupille.
    canvas.drawCircle(c, eyeH * 0.22, Paint()..color = AppColors.bg);

    // Glanzpunkt.
    canvas.drawCircle(
      Offset(c.dx - eyeW * 0.12, c.dy - eyeH * 0.18),
      eyeH * 0.09,
      Paint()..color = Colors.white.withAlpha(dimmed ? 77 : 217),
    );

    canvas.restore();

    // Augenkontur-Linie.
    canvas.drawPath(
      eyePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = dimmed ? AppColors.border : color.withAlpha(230),
    );
  }

  // Mandelform aus zwei quadratischen Kurven.
  Path _almond(Offset c, double w, double h) {
    final path = Path();
    final left = Offset(c.dx - w / 2, c.dy);
    final right = Offset(c.dx + w / 2, c.dy);
    path.moveTo(left.dx, left.dy);
    path.quadraticBezierTo(c.dx, c.dy - h / 2, right.dx, right.dy);
    path.quadraticBezierTo(c.dx, c.dy + h / 2, left.dx, left.dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_EyesPainter old) =>
      old.pulse != pulse ||
      old.blink != blink ||
      old.color != color ||
      old.tierIndex != tierIndex ||
      old.dimmed != dimmed;
}
