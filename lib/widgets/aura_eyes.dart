import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/gamification.dart';
import 'aura_orb.dart';

/// Provisorische "Aura-Augen" (Platzhalter fuer das spaetere Rive-Asset).
/// Jeder Rang bekommt eine eigene Signatur-Animation passend zum Titel
/// (BAUPLAN Abschnitt 5):
///   1 Flacker    -> unruhiges Flackern
///   2 Glut       -> warmes, langsames Atmen
///   3 Fokus      -> scharfer Pupillen-Pull
///   4 Durchbruch -> berstende Ringe
///   5 Flow-State -> stroemender Glanz
///   6 Sovereign  -> majestaetische Krone + Halo
/// [dimmed] => Aura verblasst (Streak in Gefahr).
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
  late final AnimationController _phase;

  @override
  void initState() {
    super.initState();
    // Puls: hoehere Stufe -> schneller/intensiver.
    final seconds = (5 - widget.tier.index * 0.4).clamp(2.0, 5.0);
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (seconds * 1000).round()),
    )..repeat(reverse: true);

    // Kontinuierliche Phase fuer Rotation / Fluss / Flacker (0..1, kein reverse).
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

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
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AuraOrb.colorForTier(widget.tier.index);
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _blink, _phase]),
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
              phase: _phase.value,
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
  final double phase; // 0..1, kontinuierlich
  final bool dimmed;

  _EyesPainter({
    required this.color,
    required this.tierIndex,
    required this.pulse,
    required this.blink,
    required this.phase,
    required this.dimmed,
  });

  // Flacker-Faktor (nur Stufe 1): unruhige, pseudo-zufaellige Helligkeit.
  double get _flicker {
    if (tierIndex != 1 || dimmed) return 1.0;
    final t = phase * math.pi * 2;
    final n = math.sin(t * 7) * 0.5 +
        math.sin(t * 13 + 1.3) * 0.3 +
        math.sin(t * 23 + 2.1) * 0.2;
    return (0.55 + 0.45 * (0.5 + 0.5 * n)).clamp(0.2, 1.0);
  }

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
    final flicker = _flicker;
    // Stufe 2 "Glut" atmet langsam und weich.
    final breath = tierIndex == 2 ? (0.6 + 0.4 * pulse) : 1.0;

    // Mandelfoermige Augenkontur.
    final eyePath = _almond(c, eyeW, eyeH);

    // Aussen-Glühen (intensiver bei hoeheren Stufen + Puls + Flacker).
    if (!dimmed) {
      final glowBase = (0.18 + 0.35 * intensity) * (0.7 + 0.3 * pulse);
      final glow = Paint()
        ..color = color.withAlpha(
            (glowBase * flicker * breath * 255).round().clamp(0, 255).toInt())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal,
            (6 + 10 * intensity * (0.8 + 0.2 * pulse)) * breath);
      canvas.drawPath(eyePath, glow);
    }

    // Stufe 6: heller Halo-Ring hinter dem Auge.
    if (tierIndex >= 6 && !dimmed) {
      final halo = Paint()
        ..color = color.withAlpha(((0.22 + 0.12 * pulse) * 255).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(c, eyeH * 0.95, halo);
    }

    // Stufe 4: berstende, expandierende Ringe.
    if (tierIndex == 4 && !dimmed) {
      for (final off in [0.0, 0.5]) {
        final p = (phase + off) % 1.0;
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * (1 - p)
          ..color = color.withAlpha(((1 - p) * 0.5 * 255).round());
        canvas.drawCircle(c, eyeH * (0.5 + 0.7 * p), ringPaint);
      }
    }

    // Dunkler Augapfel-Hintergrund.
    canvas.drawPath(eyePath, Paint()..color = AppColors.bg);

    // Clip auf die Augenform fuer Iris/Glanz.
    canvas.save();
    canvas.clipPath(eyePath);

    // Iris als radialer Verlauf.
    final irisR = eyeH * 0.62;
    final irisRect = Rect.fromCircle(center: c, radius: irisR);
    final irisCore = Color.lerp(color, Colors.white, dimmed ? 0.0 : 0.35)!;
    final irisPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          irisCore,
          color,
          color.withAlpha(38),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(irisRect);
    canvas.drawCircle(c, irisR, irisPaint);

    // Stufe 5 "Flow-State": ein stroemender Glanzbogen wandert um die Iris.
    if (tierIndex == 5 && !dimmed) {
      final a = phase * math.pi * 2;
      final gc = Offset(
          c.dx + math.cos(a) * irisR * 0.5, c.dy + math.sin(a) * irisR * 0.5);
      final sweep = Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withAlpha(150),
          Colors.white.withAlpha(0),
        ]).createShader(Rect.fromCircle(center: gc, radius: irisR * 0.6));
      canvas.drawCircle(gc, irisR * 0.6, sweep);
    }

    // Stern-Burst in der Iris ab Stufe 3 (Strahlenzahl/-laenge pro Stufe).
    if (tierIndex >= 3 && !dimmed) {
      final burst = Paint()
        ..color = Colors.white
            .withAlpha(((0.55 * (0.6 + 0.4 * pulse)) * 255).round())
        ..strokeWidth = tierIndex >= 6 ? 1.8 : 1.4
        ..strokeCap = StrokeCap.round;
      final rays = 4 + (tierIndex - 3) * 3; // mehr Strahlen bei hoeherer Stufe
      // Stufe 5/6 rotieren gleichmaessig, sonst nur leichtes Puls-Wandern.
      final spin = tierIndex >= 5 ? phase * math.pi * 2 : pulse * 0.4;
      final lenF = tierIndex >= 6 ? 0.75 : 0.55;
      for (int i = 0; i < rays; i++) {
        final ang = (math.pi * 2 / rays) * i + spin;
        final len = irisR * (lenF + 0.25 * pulse);
        canvas.drawLine(
          c,
          Offset(c.dx + math.cos(ang) * len, c.dy + math.sin(ang) * len),
          burst,
        );
      }
    }

    // Pupille — Stufe 3 "Fokus" zieht scharf (kontrahiert/weitet).
    final pupilScale = tierIndex == 3
        ? (0.7 + 0.5 * (0.5 + 0.5 * math.sin(phase * math.pi * 2)))
        : 1.0;
    canvas.drawCircle(
        c, eyeH * 0.22 * pupilScale, Paint()..color = AppColors.bg);

    // Glanzpunkt (Stufe 6 funkelt zusaetzlich).
    canvas.drawCircle(
      Offset(c.dx - eyeW * 0.12, c.dy - eyeH * 0.18),
      eyeH * 0.09,
      Paint()..color = Colors.white.withAlpha(dimmed ? 77 : 217),
    );
    if (tierIndex >= 6 && !dimmed) {
      final tw = 0.5 + 0.5 * math.sin(phase * math.pi * 2 + 1.0);
      canvas.drawCircle(
        Offset(c.dx + eyeW * 0.16, c.dy - eyeH * 0.05),
        eyeH * 0.05 * tw,
        Paint()..color = Colors.white.withAlpha((tw * 200).round()),
      );
    }

    canvas.restore();

    // Augenkontur-Linie (Stufe 3 "Fokus" crisp & hell).
    canvas.drawPath(
      eyePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tierIndex == 3 ? 2.0 : 1.6
        ..color = dimmed
            ? AppColors.border
            : color.withAlpha(tierIndex == 3 ? 255 : 230),
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
      old.phase != phase ||
      old.color != color ||
      old.tierIndex != tierIndex ||
      old.dimmed != dimmed;
}
