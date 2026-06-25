import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/services/gamification.dart';

// Sichert die tagbasierte Streak + Gnadentag-Logik (eine Quelle der Wahrheit).
void main() {
  DateTime d(int day) => DateTime(2024, 1, day);

  group('StreakPolicy.replay', () {
    test('leer -> 0 Tage, 1 Schild', () {
      final c = StreakPolicy.replay([]);
      expect(c.streakDays, 0);
      expect(c.streakStart, isNull);
      expect(c.shields, 1);
    });

    test('ein Tag -> 1', () {
      final c = StreakPolicy.replay([d(1)]);
      expect(c.streakDays, 1);
      expect(c.streakStart, d(1));
    });

    test('aufeinanderfolgende Tage zaehlen als Tage', () {
      final c = StreakPolicy.replay([d(1), d(2), d(3)]);
      expect(c.streakDays, 3);
      expect(c.streakStart, d(1));
    });

    test('Luecke <= 3 Tage zaehlt weiter', () {
      final c = StreakPolicy.replay([d(1), d(4)]); // Luecke 3
      expect(c.streakDays, 4);
      expect(c.streakStart, d(1));
    });

    test('Luecke > 3: Schild ueberbrueckt, Lauf bleibt', () {
      final c = StreakPolicy.replay([d(1), d(6)]); // Luecke 5
      expect(c.streakDays, 6);
      expect(c.streakStart, d(1));
      expect(c.shields, 0); // Schild verbraucht
    });

    test('Luecke > 3, Schild erschoepft, kein Regen -> Reset', () {
      // d1->d5 (Schild weg), d5->d9 (Regen liefert Schild -> ueberbrueckt),
      // d9->d13 (kein Regen seit d8, kein Schild) -> Reset auf d13.
      final c = StreakPolicy.replay([d(1), d(5), d(9), d(13)]);
      expect(c.streakStart, d(13));
      expect(c.streakDays, 1);
    });

    test('Reihenfolge/Duplikate egal', () {
      final c = StreakPolicy.replay([d(3), d(1), d(2), d(2)]);
      expect(c.streakDays, 3);
      expect(c.streakStart, d(1));
    });
  });

  group('AuraDecay.effectiveStreak', () {
    test('innerhalb der Toleranz: keine Senkung', () {
      expect(
          AuraDecay.effectiveStreak(10, DateTime(2024, 1, 10), DateTime(2024, 1, 12)),
          10);
    });

    test('lange Pause: sinkt Tag fuer Tag', () {
      // 8 Tage seit letztem Workout, Toleranz 3 -> overdue 5 -> 10-5=5
      expect(
          AuraDecay.effectiveStreak(10, DateTime(2024, 1, 1), DateTime(2024, 1, 9)),
          5);
    });

    test('nie unter 0', () {
      expect(
          AuraDecay.effectiveStreak(2, DateTime(2024, 1, 1), DateTime(2024, 2, 1)),
          0);
    });
  });
}
