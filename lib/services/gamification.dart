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

  /// Basis-XP-Konstanten — eine Quelle der Wahrheit fuer alle Pfade.
  static const int baseSetXp = 10; // Mikro-Reward pro Arbeitssatz
  static const int prBonusXp = 50; // Boss-Moment-Bonus je PR

  /// XP fuer einen Arbeitssatz: Basis + leichter Bonus fuer hohe Anstrengung.
  /// Gemeinsamer Kern fuer Live-Logging und Replay aus der Historie.
  static int _xpForWorkingSet(bool isWarmup, int reps, double? rpe) {
    if (isWarmup || reps <= 0) return 0;
    int xp = baseSetXp;
    if (rpe != null && rpe >= 8) xp += 4;
    if (rpe != null && rpe >= 9.5) xp += 4;
    return xp;
  }

  /// XP fuer einen bereits abgeschlossenen Satz aus der Historie.
  static int xpForCompletedSet(CompletedSet s) =>
      _xpForWorkingSet(s.isWarmup, s.reps, s.rpe);
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

/// Standardpause pro Uebung basierend auf dem Rep-Bereich.
class RestDefaults {
  static int forExercise(ExerciseTemplate ex) {
    if (ex.repMax <= 8) return 180; // schwere Grunduebung
    if (ex.repMax <= 12) return 120; // mittlere Verbunduebung
    return 60; // Isolation
  }
}

/// Ergebnis der Bewertung einer Session.
class SessionScore {
  final int xp;
  final Set<String> prExercises;
  const SessionScore(this.xp, this.prExercises);
}

/// EINZIGE Quelle der Wahrheit fuer XP- und PR-Berechnung. Live-Logging,
/// Replay (deleteLog) und CSV-Import rufen alle [scoreSession] auf — damit die
/// drei Pfade nie wieder auseinanderlaufen (gleiche XP-, RPE- und PR-Regeln).
class SessionScorer {
  /// Bestes geschaetztes 1RM je Uebung aus der bisherigen Historie.
  static Map<String, double> bestEst1RMByExercise(List<CompletedSet> history) {
    final best = <String, double>{};
    for (final s in history) {
      if (s.isWarmup) continue;
      final e = s.estimated1RM;
      if (e > (best[s.exerciseName] ?? 0.0)) best[s.exerciseName] = e;
    }
    return best;
  }

  /// Bewertet die Saetze einer Session gegen [bestEst1RM] (wird fortgeschrieben):
  /// XP je Arbeitssatz inkl. RPE-Bonus + einmaliger PR-Bonus je Uebung.
  /// Der erste je gezaehlte Satz einer Uebung ist ein PR; danach zaehlt ein
  /// hoeheres geschaetztes 1RM.
  static SessionScore scoreSession(
    List<CompletedSet> sets,
    Map<String, double> bestEst1RM,
  ) {
    int xp = 0;
    final prs = <String>{};
    for (final s in sets) {
      if (s.isWarmup || s.reps <= 0) continue;
      xp += LevelSystem.xpForCompletedSet(s);
      final e1rm = s.estimated1RM;
      final prev = bestEst1RM[s.exerciseName] ?? 0.0;
      final isPR = prev == 0.0 || e1rm > prev;
      if (isPR && prs.add(s.exerciseName)) {
        xp += LevelSystem.prBonusXp;
      }
      if (e1rm > prev) bestEst1RM[s.exerciseName] = e1rm;
    }
    return SessionScore(xp, prs);
  }
}

/// Bestimmt den als Naechstes faelligen Trainingstag eines Plans aus der
/// Historie: eins nach dem zuletzt absolvierten Tag, rotierend durch die
/// Plan-Reihenfolge. Kein passendes Log (leere/fremde Historie) -> Tag 0.
class Rotation {
  static int nextSessionIndex(
    List<WorkoutLog> logs,
    List<SessionTemplate> sessions,
  ) {
    if (sessions.isEmpty) return 0;
    final names = [for (final s in sessions) s.name];
    for (int i = logs.length - 1; i >= 0; i--) {
      final idx = names.indexOf(logs[i].sessionName);
      if (idx >= 0) return (idx + 1) % sessions.length;
    }
    return 0;
  }
}

/// Ergebnis der Konsistenz-Auswertung: Streak in **Tagen**, Start des Laufs
/// und verbleibende Gnadentage (Schilde).
class ConsistencyState {
  final int streakDays;
  final DateTime? streakStart;
  final int shields;
  final DateTime? lastDay;
  const ConsistencyState(
      this.streakDays, this.streakStart, this.shields, this.lastDay);
}

/// EINZIGE Quelle der Wahrheit fuer Streak (in Tagen) und Gnadentage.
/// Streak = vergangene Tage des aktuellen Konsistenz-Laufs (BAUPLAN §5).
/// - Luecke <= [graceMaxGapDays]: Lauf laeuft weiter.
/// - Groessere Luecke: ein Schild ueberbrueckt sie; ohne Schild -> Reset.
/// - Schilde wachsen um 1 je [shieldRegenDays] (ein Gnadentag pro Woche),
///   gedeckelt auf [maxShields]; jeder neue Lauf startet mit einem Schild.
class StreakPolicy {
  static const int graceMaxGapDays = 3;
  static const int maxShields = 1;
  static const int shieldRegenDays = 7;

  static ConsistencyState replay(List<DateTime> dates) {
    final days = dates.map((d) => DateTime(d.year, d.month, d.day)).toList()
      ..sort();
    final uniq = <DateTime>[];
    for (final d in days) {
      if (uniq.isEmpty || uniq.last != d) uniq.add(d);
    }
    if (uniq.isEmpty) return const ConsistencyState(0, null, 1, null);

    DateTime runStart = uniq.first;
    DateTime shieldAnchor = uniq.first;
    int shields = 1;

    for (int i = 1; i < uniq.length; i++) {
      // Woechentlicher Schild-Nachschub seit dem letzten Anker.
      final weeks = uniq[i].difference(shieldAnchor).inDays ~/ shieldRegenDays;
      if (weeks > 0) {
        final grown = shields + weeks;
        shields = grown > maxShields ? maxShields : grown;
        shieldAnchor = shieldAnchor.add(Duration(days: weeks * shieldRegenDays));
      }
      final gap = uniq[i].difference(uniq[i - 1]).inDays;
      if (gap <= graceMaxGapDays) {
        // Lauf laeuft weiter
      } else if (shields > 0) {
        shields -= 1; // Gnadentag eingesetzt
      } else {
        runStart = uniq[i]; // Reset: neuer Lauf
        shieldAnchor = uniq[i];
        shields = 1;
      }
    }

    final last = uniq.last;
    return ConsistencyState(
        last.difference(runStart).inDays + 1, runStart, shields, last);
  }
}

/// Sichtbarer Aura-Abstieg bei laengerer Pause (BAUPLAN §4): die "effektive"
/// Streak sinkt Tag fuer Tag, sobald die Toleranz ueberschritten ist, sodass
/// die Aura-Stufe absteigt. Die echte Streak wird erst beim naechsten Workout
/// neu bestimmt (dort greifen die Schilde).
class AuraDecay {
  static int effectiveStreak(
      int streak, DateTime? lastWorkoutDate, DateTime now) {
    if (lastWorkoutDate == null) return streak;
    final daysSince = DateTime(now.year, now.month, now.day)
        .difference(DateTime(
            lastWorkoutDate.year, lastWorkoutDate.month, lastWorkoutDate.day))
        .inDays;
    final overdue = daysSince - StreakPolicy.graceMaxGapDays;
    if (overdue <= 0) return streak;
    final eff = streak - overdue;
    return eff < 0 ? 0 : eff;
  }
}
