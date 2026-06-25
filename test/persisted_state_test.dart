import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/models/models.dart';
import 'package:newprime/services/local_store.dart';

// Sichert die Save/Load-Symmetrie nach der Extraktion (gleiche JSON-Keys) —
// das Haupt-Risiko des Persistenz-Refactors.
void main() {
  test('PersistedState JSON-Roundtrip', () {
    final p = PersistedState(
      xp: 1234,
      streak: 12,
      shields: 1,
      lastWorkoutDate: DateTime(2024, 8, 21),
      streakStartDate: DateTime(2024, 8, 10),
      displayName: 'Justin',
      seedVersion: 1,
      restOverrides: const {'Bankdruecken': 180},
      selectedProgramName: 'Upper / Lower',
      customPrograms: const [],
      history: [
        CompletedSet(
            exerciseName: 'Bankdruecken',
            weight: 100,
            reps: 5,
            tempo: '3-1-1',
            muscle: MuscleGroup.chest,
            date: DateTime(2024, 8, 21)),
      ],
      logs: const [],
    );
    final back = PersistedState.fromJson(p.toJson());
    expect(back.xp, 1234);
    expect(back.streak, 12);
    expect(back.shields, 1);
    expect(back.streakStartDate, DateTime(2024, 8, 10));
    expect(back.displayName, 'Justin');
    expect(back.restOverrides['Bankdruecken'], 180);
    expect(back.selectedProgramName, 'Upper / Lower');
    expect(back.history.length, 1);
    expect(back.history.first.tempo, '3-1-1');
    expect(back.history.first.muscle, MuscleGroup.chest);
  });

  test('Fehlende Keys -> Defaults (Alt-Daten)', () {
    final p = PersistedState.fromJson({});
    expect(p.xp, 0);
    expect(p.streak, 0);
    expect(p.shields, 1);
    expect(p.displayName, 'Athlet');
    expect(p.seedVersion, 0);
    expect(p.lastWorkoutDate, isNull);
    expect(p.streakStartDate, isNull);
    expect(p.selectedProgramName, isNull);
    expect(p.customPrograms, isEmpty);
    expect(p.history, isEmpty);
    expect(p.logs, isEmpty);
    expect(p.restOverrides, isEmpty);
  });
}
