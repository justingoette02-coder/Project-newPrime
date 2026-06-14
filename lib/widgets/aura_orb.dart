import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/gamification.dart';

// Platzhalter fuer die animierten Aura-Augen (spaeter Rive-Asset).
// Zeigt einen pulsierenden Aura-Ring in der Farbe der aktuellen Stufe,
// mit der Level-Zahl im Zentrum. Aura wird mit hoeherer Stufe "lauter".
class AuraOrb extends StatefulWidget {
  final AuraTier tier;
  final int level;
  final double size;
  final bool dimmed; // true = Aura verblasst (Streak in Gefahr)

  const AuraOrb({
    super.key,
    required this.tier,
    required this.level,
    this.size = 72,
    this.dimmed = false,
  });

  static Color colorForTier(int index) {
    switch (index) {
      case 1:
        return const Color(0xFF5A5570);
      case 2:
        return AppColors.aura;
      case 3:
        return AppColors.auraSoft;
      case 4:
        return AppColors.streak;
      case 5:
        return AppColors.auraBlue;
      default:
        return const Color(0xFF85B7EB);
    }
  }

  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Hoehere Stufe -> schnellerer, intensiverer Puls.
    final seconds = (5 - widget.tier.index * 0.4).clamp(2.0, 5.0);
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (seconds * 1000).round()),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AuraOrb.colorForTier(widget.tier.index);
    final intensity = widget.tier.index / 6.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final glowRadius =
            widget.size * (0.5 + 0.35 * intensity) * (0.85 + 0.3 * t);
        final glowOpacity =
            (widget.dimmed ? 0.12 : (0.25 + 0.45 * intensity)) * (0.7 + 0.3 * t);
        return SizedBox(
          width: widget.size * 1.9,
          height: widget.size * 1.9,
          child: Center(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: widget.dimmed ? AppColors.border : color,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha((glowOpacity * 255).round()),
                    blurRadius: glowRadius,
                    spreadRadius: glowRadius * 0.25,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${widget.level}',
                  style: TextStyle(
                    fontSize: widget.size * 0.34,
                    fontWeight: FontWeight.w600,
                    color: widget.dimmed ? AppColors.textSecondary : color,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
