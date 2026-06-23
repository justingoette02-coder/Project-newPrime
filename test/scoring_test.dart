import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/models/models.dart';
import 'package:newprime/services/gamification.dart';

// Sichert die EINE Bewertungs-Quelle (SessionScorer), die Live-Logging,
// Replay (deleteLog) und CSV-Import gemeinsam nutzen. Verhindert, dass die
// drei Pfade wieder mit unterschiedlichen XP-/PR-Regeln auseinanderlaufen.
void main() {
  CompletedSet set(String name, double weight, int reps,
          {double? rpe, bool warmup = false}) =>
      CompletedSet(
        exerciseName: name,
        weight: weight,
        reps: reps,
        rpe: rpe,
        date: DateTime(2024, 1, 1),
        isWarmup: warmup,
      );

  group('SessionScorer.scoreSession', () {
    test('Basis-XP pro Arbeitssatz + PR-Bonus; Warmups zaehlen nicht', () {
      final best = <String, double>{};
      final score = SessionScorer.scoreSession([
        set('Bankdruecken', 100, 5),
        set('Bankdruecken', 60, 10, warmup: true),
      ], best);
      // 10 (Arbeitssatz) + 50 (erster Satz der Uebung = PR)
      expect(score.xp, 60);
      expect(score.prExercises, {'Bankdruecken'});
    });

    test('RPE-Bonus wird angewendet (Kern des Bugs: Replay verlor ihn)', () {
      final best = {'Bankdruecken': 999.0}; // schon hoch -> kein PR
      final score = SessionScorer.scoreSession([
        set('Bankdruecken', 100, 5, rpe: 9.5),
      ], best);
      // 10 + 4 (RPE>=8) + 4 (RPE>=9.5), kein PR-Bonus
      expect(score.xp, 18);
      expect(score.prExercises, isEmpty);
    });

    test('PR-Bonus nur einmal pro Uebung und Session', () {
      final best = <String, double>{};
      final score = SessionScorer.scoreSession([
        set('Kniebeuge', 100, 5),
        set('Kniebeuge', 110, 5), // hoeher, aber zweiter PR derselben Uebung
      ], best);
      // 2x10 Basis + 1x50 PR-Bonus
      expect(score.xp, 70);
      expect(score.prExercises, {'Kniebeuge'});
    });

    test('bestEst1RM wird fortgeschrieben -> naechste Session kein PR mehr', () {
      final best = SessionScorer.bestEst1RMByExercise([set('Rudern', 80, 8)]);
      final score = SessionScorer.scoreSession([
        set('Rudern', 80, 8), // gleiches geschaetztes 1RM wie Historie
      ], best);
      expect(score.prExercises, isEmpty);
      expect(score.xp, 10); // nur Basis, kein PR-Bonus
    });
  });
}
