import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/models/models.dart';
import 'package:newprime/services/gamification.dart';

// Sichert die History-basierte Trainingstag-Rotation: der naechste Tag ist
// eins nach dem zuletzt absolvierten, rotierend durch die Plan-Reihenfolge.
void main() {
  SessionTemplate sess(String name) =>
      SessionTemplate(name: name, exercises: const []);
  WorkoutLog log(String name) => WorkoutLog(
        sessionName: name,
        date: DateTime(2024, 1, 1),
        sets: const [],
        xpEarned: 0,
      );

  group('Rotation.nextSessionIndex', () {
    final plan = [sess('Upper A'), sess('Lower A'), sess('Upper B'), sess('Lower B')];

    test('Leere Historie -> Tag 0', () {
      expect(Rotation.nextSessionIndex([], plan), 0);
    });

    test('Zuletzt Upper A -> Lower A (Index 1)', () {
      expect(Rotation.nextSessionIndex([log('Upper A')], plan), 1);
    });

    test('Zuletzt Lower B -> wieder Upper A (Wrap auf 0)', () {
      expect(Rotation.nextSessionIndex([log('Lower B')], plan), 0);
    });

    test('Nutzt das neueste passende Log (zuletzt = Liste am Ende)', () {
      final logs = [log('Upper B'), log('Lower A')];
      expect(Rotation.nextSessionIndex(logs, plan), 2); // nach Lower A -> Upper B
    });

    test('Fremder Session-Name -> Fallback 0', () {
      expect(Rotation.nextSessionIndex([log('Push Day')], plan), 0);
    });

    test('Leerer Plan -> 0', () {
      expect(Rotation.nextSessionIndex([log('Upper A')], const []), 0);
    });
  });
}
