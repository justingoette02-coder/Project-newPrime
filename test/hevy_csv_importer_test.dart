import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/models/models.dart';
import 'package:newprime/services/hevy_csv_importer.dart';

// Sichert den extrahierten CSV-Parser (vorher untested in AppState).
void main() {
  test('parse: Sessions, Saetze, Muskel, Warmup, Dauer', () {
    const csv =
        'title,start_time,end_time,exercise_title,set_type,weight_kg,reps\n'
        'Upper A,"21 Aug 2024, 15:00","21 Aug 2024, 16:00",Bankdruecken,normal,100,5\n'
        'Upper A,"21 Aug 2024, 15:00","21 Aug 2024, 16:00",Seitheben,warmup,10,12\n';
    final sessions = HevyCsvImporter.parse(
      utf8.encode(csv),
      muscleByName: const {'Bankdruecken': MuscleGroup.chest},
    );
    expect(sessions, isNotNull);
    expect(sessions!.length, 1);
    final s = sessions.first;
    expect(s.title, 'Upper A');
    expect(s.start, DateTime(2024, 8, 21, 15, 0));
    expect(s.durationMinutes, 60);
    expect(s.sets.length, 2);
    expect(s.sets[0].exerciseName, 'Bankdruecken');
    expect(s.sets[0].muscle, MuscleGroup.chest);
    expect(s.sets[0].isWarmup, false);
    expect(s.sets[1].isWarmup, true);
    expect(s.sets[1].muscle, isNull); // Seitheben nicht in der Map
  });

  test('ungueltiges CSV -> null', () {
    expect(HevyCsvImporter.parse(utf8.encode('nur eine zeile')), isNull);
  });
}
