import '../models/models.dart';

/// Aura-Stufe, abgeleitet aus der Streak (Konsistenz ist das Rueckgrat).
class AuraTier {
  final int index; // 1..6
  final String name;
  final String rank; // E..S
  final int streakMin;
  final int streakMax; // -1 = offen

  const AuraTier(this.index, this.name, this.rank, this.streakMin, this.streakMax);

  static const List<AuraTier> tiers = [
    AuraTier(1, 'Flacker', 'E', 0, 6),
    AuraTier(2, 'Glut', 'D', 7, 20),
    AuraTier(3, 'Fokus', 'C', 21, 45),
    AuraTier(4, 'Durchbruch', 'B', 46, 89),
    AuraTier(5, 'Flow-State', 'A', 90, 179),
    AuraTier(6, 'Sovereign', 'S', 180, -1),
  ];

  static AuraTier forStreak(int streak) {
    for (final t in tiers) {
      if (streak >= t.streakMin && (t.streakMax == -1 || streak <= t.streakMax)) {
        return t;
      }
    }
    return tiers.first;
  }

  /// Fortschritt (0..1) innerhalb der aktuellen Stufe bis zur naechsten.
  double progress(int streak) {
    if (streakMax == -1) return 1.0;
    final span = streakMax - streakMin + 1;
    final into = (streak - streakMin + 1).clamp(0, span);
    return into / span;
  }

  int? get nextAt => streakMax == -1 ? null : streakMax + 1;
}

/// Level- und XP-System. XP kommt aus echter Leistung, nicht aus Einloggen.
class LevelSystem {
  /// Kumulative XP, um Level [level] zu erreichen (Level 1 = 0 XP).
  static int xpAtLevelStart(int level) {
    final n = level - 1;
    return 300 * n + 50 * n * n;
  }

  static int levelForXp(int xp) {
    int level = 1;
    while (xp >= xpAtLevelStart(level + 1)) {
      level++;
    }
    return level;
  }

  static int xpIntoLevel(int xp) => xp - xpAtLevelStart(levelForXp(xp));

  static int xpForNextLevel(int xp) {
    final level = levelForXp(xp);
    return xpAtLevelStart(level + 1) - xpAtLevelStart(level);
  }

  static double levelProgress(int xp) {
    final span = xpForNextLevel(xp);
    if (span <= 0) return 1.0;
    return xpIntoLevel(xp) / span;
  }

  /// XP fuer einen abgeschlossenen Arbeitssatz.
  /// Basis + leichter Bonus fuer hohe Anstrengung (RPE).
  static int xpForSet(SetEntry s) {
    if (!s.done || s.isWarmup) return 0;
    int xp = 10; // Mikro-Reward pro Satz
    if (s.rpe != null && s.rpe! >= 8) xp += 4;
    if (s.rpe != null && s.rpe! >= 9.5) xp += 4;
    return xp;
  }
}

/// Double Progression: erst Wdh bis zum oberen Limit, dann Gewicht rauf.
class ProgressionSuggestion {
  final double weight;
  final int reps;
  final String hint;
  final bool increaseWeight;

  ProgressionSuggestion(this.weight, this.reps, this.hint, this.increaseWeight);
}

class Progression {
  static const double smallestIncrementKg = 2.5;

  /// Vorschlag fuer die naechste Einheit basierend auf den letzten
  /// Arbeitssaetzen einer Uebung.
  static ProgressionSuggestion? suggest(
    List<CompletedSet> lastWorkingSets,
    int repMin,
    int repMax,
  ) {
    if (lastWorkingSets.isEmpty) return null;

    // Schwerster Arbeitssatz der letzten Einheit als Referenz.
    final ref = lastWorkingSets.reduce((a, b) => a.weight >= b.weight ? a : b);

    if (ref.reps >= repMax) {
      // Oberes Limit erreicht -> Gewicht hoch, Wdh zurueck auf Minimum.
      final newWeight = ref.weight + smallestIncrementKg;
      return ProgressionSuggestion(
        newWeight,
        repMin,
        'Top erreicht! Steigere auf ${_fmt(newWeight)} kg x $repMin.',
        true,
      );
    } else {
      // Gleiches Gewicht, eine Wiederholung mehr anpeilen.
      final target = (ref.reps + 1).clamp(repMin, repMax);
      return ProgressionSuggestion(
        ref.weight,
        target,
        'Bleib bei ${_fmt(ref.weight)} kg, ziel auf $target Wdh.',
        false,
      );
    }
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// PR-Erkennung ueber geschaetztes 1RM pro Uebung.
class PRChecker {
  /// true, wenn [candidate] das bisher beste geschaetzte 1RM dieser Uebung
  /// in [history] uebertrifft.
  static bool isPR(List<CompletedSet> history, CompletedSet candidate) {
    if (candidate.isWarmup) return false;
    double best = 0;
    for (final s in history) {
      if (s.isWarmup) continue;
      if (s.exerciseName == candidate.exerciseName &&
          s.estimated1RM > best) {
        best = s.estimated1RM;
      }
    }
    return candidate.estimated1RM > best && best > 0
        ? true
        : best == 0; // erster echte Satz zaehlt ebenfalls als PR
  }
}
