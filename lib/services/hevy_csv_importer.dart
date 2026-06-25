import 'dart:convert';

import '../models/models.dart';

/// Eine aus dem Hevy-CSV geparste Session (Vorstufe zum WorkoutLog).
class ImportedSession {
  final String title;
  final DateTime start;
  final int? durationMinutes;
  final List<CompletedSet> sets;

  const ImportedSession({
    required this.title,
    required this.start,
    required this.durationMinutes,
    required this.sets,
  });
}

/// Parst einen Hevy-CSV-Export in [ImportedSession]s. Rein (kein State, kein
/// Scoring) und damit testbar. Muskel wird ueber [muscleByName] zugeordnet.
class HevyCsvImporter {
  static List<ImportedSession>? parse(
    List<int> bytes, {
    Map<String, MuscleGroup> muscleByName = const {},
  }) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final rows = _parseCsv(content);
    if (rows.length < 2) return null;

    final header = rows.first;
    int col(String name) => header.indexOf(name);
    final cTitle = col('title');
    final cStart = col('start_time');
    final cEnd = col('end_time');
    final cExercise = col('exercise_title');
    final cSetType = col('set_type');
    final cWeight = col('weight_kg');
    final cReps = col('reps');
    if ([cTitle, cStart, cEnd, cExercise, cSetType, cWeight, cReps]
        .any((i) => i < 0)) {
      return null;
    }

    final sessionsMap = <String, Map<String, dynamic>>{};
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= cReps) continue;
      final reps = int.tryParse(r[cReps].trim()) ?? 0;
      if (reps <= 0) continue;
      final key = '${r[cTitle]}|${r[cStart]}';
      sessionsMap.putIfAbsent(key, () => {
            'title': r[cTitle],
            'start': _parseHevyDate(r[cStart]),
            'end': _parseHevyDate(r[cEnd]),
            'rawSets': <Map<String, dynamic>>[],
          });
      (sessionsMap[key]!['rawSets'] as List).add({
        'exercise': r[cExercise],
        'weight': double.tryParse(r[cWeight].trim()) ?? 0.0,
        'reps': reps,
        'isWarmup': r[cSetType].trim().toLowerCase() == 'warmup',
      });
    }

    final raw = sessionsMap.values.where((s) => s['start'] != null).toList()
      ..sort((a, b) =>
          (a['start'] as DateTime).compareTo(b['start'] as DateTime));
    if (raw.isEmpty) return null;

    final sessions = <ImportedSession>[];
    for (final s in raw) {
      final start = s['start'] as DateTime;
      final endDt = s['end'] as DateTime?;
      int? durMin;
      if (endDt != null) {
        final d = endDt.difference(start).inMinutes;
        if (d >= 1 && d <= 300) durMin = d;
      }
      final sets = <CompletedSet>[];
      for (final st in (s['rawSets'] as List)) {
        final exName = st['exercise'] as String;
        sets.add(CompletedSet(
          exerciseName: exName,
          weight: st['weight'] as double,
          reps: st['reps'] as int,
          muscle: muscleByName[exName],
          date: start,
          isWarmup: st['isWarmup'] as bool,
        ));
      }
      sessions.add(ImportedSession(
        title: s['title'] as String,
        start: start,
        durationMinutes: durMin,
        sets: sets,
      ));
    }
    return sessions;
  }

  static List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    for (final line in content.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final fields = <String>[];
      var inQuotes = false;
      final field = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final c = line[i];
        if (c == '"') {
          inQuotes = !inQuotes;
        } else if (c == ',' && !inQuotes) {
          fields.add(field.toString());
          field.clear();
        } else {
          field.write(c);
        }
      }
      fields.add(field.toString());
      rows.add(fields);
    }
    return rows;
  }

  static const _hevyMonths = {
    'Jan': 1, 'Feb': 2, 'März': 3, 'Apr': 4,
    'Mai': 5, 'Juni': 6, 'Juli': 7, 'Aug': 8,
    'Sept': 9, 'Okt': 10, 'Nov': 11, 'Dez': 12,
  };

  static DateTime? _parseHevyDate(String s) {
    final m =
        RegExp(r'(\d+)\s+(\w+)\s+(\d+),\s+(\d+):(\d+)').firstMatch(s.trim());
    if (m == null) return null;
    final month = _hevyMonths[m.group(2)];
    if (month == null) return null;
    return DateTime(
      int.parse(m.group(3)!), month, int.parse(m.group(1)!),
      int.parse(m.group(4)!), int.parse(m.group(5)!),
    );
  }
}
