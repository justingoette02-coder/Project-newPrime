import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/models/models.dart';

// Sichert, dass die neuen Satz-Felder (Tempo/Pause/Notiz/Muskel) persistiert
// werden und Alt-Daten ohne diese weiter laden (Migration).
void main() {
  group('CompletedSet JSON', () {
    test('Roundtrip mit allen neuen Feldern', () {
      final s = CompletedSet(
        exerciseName: 'Bankdruecken',
        weight: 100,
        reps: 5,
        rpe: 9,
        restSeconds: 180,
        tempo: '3-1-1',
        note: 'schwer',
        muscle: MuscleGroup.chest,
        date: DateTime(2024, 1, 1),
      );
      final back = CompletedSet.fromJson(s.toJson());
      expect(back.tempo, '3-1-1');
      expect(back.restSeconds, 180);
      expect(back.note, 'schwer');
      expect(back.muscle, MuscleGroup.chest);
      expect(back.rpe, 9);
    });

    test('Alt-Daten ohne neue Felder laden (Migration)', () {
      final old = {
        'exerciseName': 'Kniebeuge',
        'weight': 120.0,
        'reps': 5,
        'rpe': null,
        'date': '2023-01-01T00:00:00.000',
        'isWarmup': false,
      };
      final s = CompletedSet.fromJson(old);
      expect(s.tempo, isNull);
      expect(s.restSeconds, isNull);
      expect(s.note, isNull);
      expect(s.muscle, isNull);
      expect(s.weight, 120.0);
    });
  });
}
