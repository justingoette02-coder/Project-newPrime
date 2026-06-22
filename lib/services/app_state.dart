import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../data/templates.dart';
import '../data/hevy_seed.dart';
import 'gamification.dart';

// Ergebnis eines abgeschlossenen Workouts (fuer die Belohnungs-Anzeige).
class WorkoutResult {
  final int xpEarned;
  final List<String> prExercises;
  final bool leveledUp;
  final int newLevel;
  final int streak;
  final int? durationMinutes;

  WorkoutResult({
    required this.xpEarned,
    required this.prExercises,
    required this.leveledUp,
    required this.newLevel,
    required this.streak,
    this.durationMinutes,
  });
}

// Zentraler App-Zustand. Wird lokal per shared_preferences gespeichert,
// damit XP, Streak und Historie das Neuladen/Schliessen ueberleben.
class AppState extends ChangeNotifier {
  static const String _storeKey = 'newprime_state_v1';

  // Vorgeschlagene (built-in) Programme + eigene (vom Nutzer erstellte).
  List<Program> get suggestedPrograms => Templates.suggested;
  final List<Program> customPrograms = [];
  String? selectedProgramName;

  List<Program> get allPrograms => [...suggestedPrograms, ...customPrograms];

  // Aktuell gewaehltes Programm (Fallback: erstes vorgeschlagenes).
  Program get activeProgram {
    final name = selectedProgramName;
    if (name != null) {
      for (final p in allPrograms) {
        if (p.name == name) return p;
      }
    }
    return suggestedPrograms.first;
  }

  // Gamification-Zustand
  int xp = 0;
  int streak = 0;
  int shields = 1;
  DateTime? lastWorkoutDate;
  String displayName = 'Athlet';

  // Welche Seed-Version zuletzt in diesen lokalen Speicher geschrieben wurde.
  int _appliedSeedVersion = 0;

  // Benutzerdefinierte Pausenzeiten pro Uebungsname (ueberschreibt den Standardwert).
  final Map<String, int> _restOverrides = {};

  // Historie aller abgeschlossenen Saetze (Basis fuer Progression & PR).
  final List<CompletedSet> history = [];
  final List<WorkoutLog> logs = [];

  // Laufende Session
  SessionTemplate? activeTemplate;
  List<ExerciseInstance> activeExercises = [];
  DateTime? _sessionStart;

  int get level => LevelSystem.levelForXp(xp);
  double get levelProgress => LevelSystem.levelProgress(xp);
  int get xpIntoLevel => LevelSystem.xpIntoLevel(xp);
  int get xpForNextLevel => LevelSystem.xpForNextLevel(xp);
  AuraTier get auraTier => AuraTier.forStreak(streak);

  // true, wenn seit dem letzten Workout >= 2 Tage vergangen sind.
  bool get isStreakAtRisk {
    if (lastWorkoutDate == null) return false;
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(lastWorkoutDate!.year, lastWorkoutDate!.month,
            lastWorkoutDate!.day))
        .inDays;
    return diff >= 2;
  }

  // Naechste geplante Session des aktiven Programms (chronologisch rotierend).
  SessionTemplate get nextSession =>
      activeProgram.sessions[logs.length % activeProgram.sessions.length];

  // Name -> Muskelgruppe (aus allen Uebungen aller Programme).
  Map<String, MuscleGroup> get _muscleByExercise {
    final map = <String, MuscleGroup>{};
    for (final program in allPrograms) {
      for (final session in program.sessions) {
        for (final ex in session.exercises) {
          map[ex.name] = ex.muscle;
        }
      }
    }
    return map;
  }

  // Wochenvolumen (Tonnage) pro Muskelgruppe der letzten 7 Tage.
  Map<MuscleGroup, double> weeklyVolume() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final byName = _muscleByExercise;
    final map = <MuscleGroup, double>{};
    for (final s in history) {
      if (s.date.isBefore(cutoff) || s.isWarmup) continue;
      final muscle = byName[s.exerciseName];
      if (muscle == null) continue;
      map[muscle] = (map[muscle] ?? 0) + s.volume;
    }
    return map;
  }

  // Konfigurierte Pausenzeit fuer eine Uebung (Custom-Wert oder Standardwert).
  int restFor(ExerciseTemplate ex) =>
      _restOverrides[ex.name] ?? RestDefaults.forExercise(ex);

  // Pausenzeit fuer eine Uebung speichern.
  void setRestOverride(String exerciseName, int seconds) {
    _restOverrides[exerciseName] = seconds;
    save();
    notifyListeners();
  }

  // Benutzernamen aendern.
  void setDisplayName(String name) {
    if (name.isEmpty) return;
    displayName = name;
    save();
    notifyListeners();
  }

  // ---- Programm-Verwaltung ----

  // Aktives Programm waehlen (vorgeschlagen oder eigen).
  void selectProgram(String name) {
    selectedProgramName = name;
    save();
    notifyListeners();
  }

  // Eigenen Plan anlegen oder (bei Namensgleichheit) ersetzen = Bearbeiten.
  void addOrUpdateCustomProgram(Program program) {
    final idx = customPrograms.indexWhere((p) => p.name == program.name);
    if (idx >= 0) {
      customPrograms[idx] = program;
    } else {
      customPrograms.add(program);
    }
    selectedProgramName = program.name;
    save();
    notifyListeners();
  }

  // Eigenen Plan loeschen. War er aktiv, faellt die Auswahl auf den ersten Vorschlag.
  void deleteCustomProgram(String name) {
    customPrograms.removeWhere((p) => p.name == name);
    if (selectedProgramName == name) {
      selectedProgramName = suggestedPrograms.first.name;
    }
    save();
    notifyListeners();
  }

  // Mid-Session eine Uebung zur laufenden Session hinzufuegen (Werte vorbelegt).
  void addExerciseToActiveSession(ExerciseTemplate ex) {
    final lastSets = _lastWorkingSetsFor(ex.name);
    final sets = List.generate(ex.targetSets, (i) {
      final prev = i < lastSets.length ? lastSets[i] : null;
      return SetEntry(weight: prev?.weight, reps: prev?.reps);
    });
    activeExercises.add(ExerciseInstance(template: ex, sets: sets));
    notifyListeners();
  }

  // Letzte Arbeitssaetze einer Uebung (public, fuer Inline-History im Workout).
  List<CompletedSet> lastWorkingSetsFor(String exerciseName) =>
      _lastWorkingSetsFor(exerciseName);

  // ---- Laden & Speichern (lokal) ----

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null) {
      // Erster Start: echte Hevy-Historie als Seed laden.
      _loadEmbeddedSeedData();
      await save();
      notifyListeners();
      return;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      xp = data['xp'] as int? ?? 0;
      streak = data['streak'] as int? ?? 0;
      shields = data['shields'] as int? ?? 1;
      displayName = data['displayName'] as String? ?? 'Athlet';
      final lwd = data['lastWorkoutDate'] as String?;
      lastWorkoutDate = lwd != null ? DateTime.tryParse(lwd) : null;
      history
        ..clear()
        ..addAll((data['history'] as List? ?? [])
            .map((e) => CompletedSet.fromJson(e as Map<String, dynamic>)));
      logs
        ..clear()
        ..addAll((data['logs'] as List? ?? [])
            .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>)));
      final ro = data['restOverrides'] as Map<String, dynamic>? ?? {};
      _restOverrides
        ..clear()
        ..addAll(ro.map((k, v) => MapEntry(k, v as int)));
      customPrograms
        ..clear()
        ..addAll((data['customPrograms'] as List? ?? [])
            .map((e) => Program.fromJson(e as Map<String, dynamic>)));
      selectedProgramName =
          data['selectedProgramName'] as String? ?? suggestedPrograms.first.name;
      _appliedSeedVersion = data['seedVersion'] as int? ?? 0;

      // Migration: liegen noch aeltere (Demo-)Daten im Speicher, werden die
      // echten Hevy-Daten automatisch geladen — ohne dass der Nutzer den
      // Import-Button tippen muss.
      if (_appliedSeedVersion < HevySeed.seedVersion) {
        _loadEmbeddedSeedData();
        await save();
      }
    } catch (_) {
      // Beschaedigte Daten -> sauberer Neustart mit echten Seed-Daten.
      _loadEmbeddedSeedData();
      await save();
    }
    notifyListeners();
  }

  // Setzt den Zustand auf die eingebetteten Hevy-Daten (ohne save/notify).
  // Gemeinsame Basis fuer First-Launch, Migration und manuelles Laden.
  void _loadEmbeddedSeedData() {
    history
      ..clear()
      ..addAll(HevySeed.buildHistory());
    logs
      ..clear()
      ..addAll(HevySeed.buildLogs());
    xp = HevySeed.seedXp;
    streak = HevySeed.seedStreak;
    shields = 0;
    lastWorkoutDate = DateTime.parse(HevySeed.seedLastWorkoutDate);
    if (displayName == 'Athlet') displayName = 'Justin';
    _appliedSeedVersion = HevySeed.seedVersion;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'xp': xp,
      'streak': streak,
      'shields': shields,
      'displayName': displayName,
      'seedVersion': _appliedSeedVersion,
      'lastWorkoutDate': lastWorkoutDate?.toIso8601String(),
      'restOverrides': _restOverrides,
      'selectedProgramName': selectedProgramName,
      'customPrograms': customPrograms.map((p) => p.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_storeKey, jsonEncode(data));
  }

  // ---- Session-Ablauf ----

  void startSession(SessionTemplate template) {
    _sessionStart = DateTime.now();
    activeTemplate = template;
    activeExercises = template.exercises.map((ex) {
      final lastSets = _lastWorkingSetsFor(ex.name);
      final sets = List.generate(ex.targetSets, (i) {
        final prev = i < lastSets.length ? lastSets[i] : null;
        return SetEntry(
          weight: prev?.weight,
          reps: prev?.reps,
        );
      });
      return ExerciseInstance(template: ex, sets: sets);
    }).toList();
    notifyListeners();
  }

  void addSet(int exerciseIndex, {bool warmup = false}) {
    final ex = activeExercises[exerciseIndex];
    // Letzten Arbeitssatz als Vorlage fuer den neuen Satz verwenden.
    final lastWorking = ex.sets.lastWhere(
      (s) => !s.isWarmup,
      orElse: () => SetEntry(),
    );
    activeExercises[exerciseIndex].sets.add(SetEntry(
      isWarmup: warmup,
      weight: warmup ? null : lastWorking.weight,
      reps: warmup ? null : lastWorking.reps,
    ));
    notifyListeners();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    activeExercises[exerciseIndex].sets.removeAt(setIndex);
    notifyListeners();
  }

  // Satz als erledigt markieren -> Mikro-Reward (Haptik) + sofort sichtbar.
  void toggleSetDone(int exerciseIndex, int setIndex) {
    final set = activeExercises[exerciseIndex].sets[setIndex];
    set.done = !set.done;
    if (set.done) {
      HapticFeedback.mediumImpact();
    }
    notifyListeners();
  }

  void updateSet(
    int exerciseIndex,
    int setIndex, {
    double? weight,
    int? reps,
    double? rpe,
    String? tempo,
    String? note,
    int? restSeconds,
    bool? isWarmup,
  }) {
    final s = activeExercises[exerciseIndex].sets[setIndex];
    if (weight != null) s.weight = weight;
    if (reps != null) s.reps = reps;
    if (rpe != null) s.rpe = rpe;
    if (tempo != null) s.tempo = tempo;
    if (note != null) s.note = note;
    if (restSeconds != null) s.restSeconds = restSeconds;
    if (isWarmup != null) s.isWarmup = isWarmup;
    notifyListeners();
  }

  // Progression-Vorschlag fuer eine Uebung (Double Progression).
  ProgressionSuggestion? suggestionFor(ExerciseTemplate ex) {
    final last = _lastWorkingSetsFor(ex.name);
    return Progression.suggest(last, ex.repMin, ex.repMax);
  }

  List<CompletedSet> _lastWorkingSetsFor(String exerciseName) {
    final relevant = history
        .where((s) => s.exerciseName == exerciseName && !s.isWarmup)
        .toList();
    if (relevant.isEmpty) return [];
    relevant.sort((a, b) => b.date.compareTo(a.date));
    final latestDay = DateTime(relevant.first.date.year,
        relevant.first.date.month, relevant.first.date.day);
    return relevant.where((s) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return d == latestDay;
    }).toList();
  }

  // Workout abschliessen: XP, Streak, PR-Erkennung, Historie schreiben, speichern.
  WorkoutResult finishWorkout() {
    final now = DateTime.now();
    final durationMinutes = _sessionStart != null
        ? now.difference(_sessionStart!).inMinutes
        : null;
    _sessionStart = null;

    final completed = <CompletedSet>[];
    final prs = <String>[];
    int xpEarned = 0;

    for (final ex in activeExercises) {
      for (final s in ex.sets) {
        if (!s.done || s.weight == null || s.reps == null) continue;
        xpEarned += LevelSystem.xpForSet(s);
        final cs = CompletedSet(
          exerciseName: ex.name,
          weight: s.weight!,
          reps: s.reps!,
          rpe: s.rpe,
          date: now,
          isWarmup: s.isWarmup,
        );
        if (!s.isWarmup && PRChecker.isPR(history, cs)) {
          if (!prs.contains(ex.name)) prs.add(ex.name);
          xpEarned += 50; // Boss-Moment-Bonus
        }
        completed.add(cs);
      }
    }

    final beforeLevel = level;
    xp += xpEarned;

    // Trainings-Streak mit Shield-System:
    // - Gleicher Tag: unveraendert
    // - <= 3 Tage Pause: Streak erhoehen
    // - > 3 Tage Pause, Schild vorhanden: Schild verbrauchen, Streak erhoehen
    // - > 3 Tage Pause, kein Schild: Reset auf 1
    if (lastWorkoutDate != null) {
      final days = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastWorkoutDate!.year, lastWorkoutDate!.month,
              lastWorkoutDate!.day))
          .inDays;
      if (days == 0) {
        // zweites Workout am selben Tag — Streak unveraendert
      } else if (days <= 3) {
        streak++;
      } else if (shields > 0) {
        shields--;
        streak++;
      } else {
        streak = 1;
      }
    } else {
      streak = 1;
    }
    lastWorkoutDate = now;

    history.addAll(completed);
    logs.add(WorkoutLog(
      sessionName: activeTemplate?.name ?? 'Workout',
      date: now,
      sets: completed,
      xpEarned: xpEarned,
      durationMinutes: durationMinutes,
    ));

    activeTemplate = null;
    activeExercises = [];

    final result = WorkoutResult(
      xpEarned: xpEarned,
      prExercises: prs,
      leveledUp: level > beforeLevel,
      newLevel: level,
      streak: streak,
      durationMinutes: durationMinutes,
    );
    save(); // lokal sichern (Fire-and-forget)
    notifyListeners();
    return result;
  }

  // ---- Historie bearbeiten ----

  // Einen Trainingstag aus der Historie loeschen. Danach werden XP, Level,
  // Streak und Historie vollstaendig aus den verbleibenden Logs neu berechnet,
  // damit auch wegfallende PRs korrekt beruecksichtigt werden.
  void deleteLog(WorkoutLog log) {
    logs.remove(log);
    _recomputeFromLogs();
    save();
    notifyListeners();
  }

  // Komplette Historie loeschen und alle Werte zuruecksetzen.
  void clearAllHistory() {
    logs.clear();
    history.clear();
    xp = 0;
    streak = 0;
    shields = 1;
    lastWorkoutDate = null;
    save();
    notifyListeners();
  }

  // XP, Streak und Historie aus der Logs-Liste neu aufbauen (Replay).
  // Gleiche PR-/XP-/Streak-Logik wie beim CSV-Import.
  void _recomputeFromLogs() {
    // Chronologisch (aelteste zuerst) fuer korrektes PR- und Streak-Replay.
    logs.sort((a, b) => a.date.compareTo(b.date));

    final bestEst1RM = <String, double>{};
    int totalXp = 0;
    final rebuiltHistory = <CompletedSet>[];
    final rebuiltLogs = <WorkoutLog>[];

    for (final log in logs) {
      int sessionXp = 0;
      final prExercises = <String>{};
      for (final s in log.sets) {
        rebuiltHistory.add(s);
        if (!s.isWarmup && s.reps > 0) {
          sessionXp += 10;
          final e1rm = s.estimated1RM;
          final prev = bestEst1RM[s.exerciseName] ?? 0.0;
          final isPR = (e1rm > prev && prev > 0) || prev == 0.0;
          if (isPR && !prExercises.contains(s.exerciseName)) {
            prExercises.add(s.exerciseName);
            sessionXp += 50;
          }
          if (e1rm > prev) bestEst1RM[s.exerciseName] = e1rm;
        }
      }
      totalXp += sessionXp;
      rebuiltLogs.add(WorkoutLog(
        sessionName: log.sessionName,
        date: log.date,
        sets: log.sets,
        xpEarned: sessionXp,
        durationMinutes: log.durationMinutes,
      ));
    }

    int newStreak = 0;
    int newShields = 1;
    DateTime? lastDay;
    for (final log in rebuiltLogs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (lastDay == null) {
        newStreak = 1;
      } else {
        final days = day.difference(lastDay).inDays;
        if (days == 0) {
          // selber Tag
        } else if (days <= 3) {
          newStreak++;
        } else if (newShields > 0) {
          newShields--;
          newStreak++;
        } else {
          newStreak = 1;
        }
      }
      lastDay = day;
    }

    history
      ..clear()
      ..addAll(rebuiltHistory);
    logs
      ..clear()
      ..addAll(rebuiltLogs);
    xp = totalXp;
    streak = newStreak;
    shields = newShields;
    lastWorkoutDate = rebuiltLogs.isNotEmpty ? rebuiltLogs.last.date : null;
  }

  // ---- Hevy CSV Import ----

  // Die eingebettete Hevy-Historie laden (ueberschreibt die aktuellen Daten).
  // Hilft, wenn bereits (alte) Daten im lokalen Speicher liegen und der
  // First-Launch-Seed deshalb nicht griff.
  Map<String, int> applyEmbeddedSeed() {
    _loadEmbeddedSeedData();
    save();
    notifyListeners();
    return {
      'sessions': logs.length,
      'sets': history.length,
      'xp': xp,
      'streak': streak,
    };
  }

  Future<Map<String, int>?> importHevyCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final bytes = picked.files.first.bytes;
    if (bytes == null) return null;
    return _applyHevyCsvBytes(bytes);
  }

  Map<String, int>? _applyHevyCsvBytes(List<int> bytes) {
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

    final sessions = sessionsMap.values
        .where((s) => s['start'] != null)
        .toList()
      ..sort((a, b) =>
          (a['start'] as DateTime).compareTo(b['start'] as DateTime));
    if (sessions.isEmpty) return null;

    final bestEst1RM = <String, double>{};
    int totalXp = 0;
    final newHistory = <CompletedSet>[];
    final newLogs = <WorkoutLog>[];

    for (final s in sessions) {
      final start = s['start'] as DateTime;
      final endDt = s['end'] as DateTime?;
      int? durMin;
      if (endDt != null) {
        final d = endDt.difference(start).inMinutes;
        if (d >= 1 && d <= 300) durMin = d;
      }
      int sessionXp = 0;
      final sessionSets = <CompletedSet>[];
      final prExercises = <String>{};

      for (final st in (s['rawSets'] as List)) {
        final exercise = st['exercise'] as String;
        final weight = st['weight'] as double;
        final reps = st['reps'] as int;
        final isWarmup = st['isWarmup'] as bool;
        final cs = CompletedSet(
          exerciseName: exercise,
          weight: weight,
          reps: reps,
          date: start,
          isWarmup: isWarmup,
        );
        sessionSets.add(cs);
        newHistory.add(cs);
        if (!isWarmup && reps > 0) {
          sessionXp += 10;
          final e1rm = weight * (1 + reps / 30.0);
          final prev = bestEst1RM[exercise] ?? 0.0;
          final isPR = (e1rm > prev && prev > 0) || prev == 0.0;
          if (isPR && !prExercises.contains(exercise)) {
            prExercises.add(exercise);
            sessionXp += 50;
          }
          if (e1rm > prev) bestEst1RM[exercise] = e1rm;
        }
      }

      totalXp += sessionXp;
      newLogs.add(WorkoutLog(
        sessionName: s['title'] as String,
        date: start,
        sets: sessionSets,
        xpEarned: sessionXp,
        durationMinutes: durMin,
      ));
    }

    int newStreak = 0;
    int newShields = 1;
    DateTime? lastDay;
    for (final log in newLogs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (lastDay == null) {
        newStreak = 1;
      } else {
        final days = day.difference(lastDay).inDays;
        if (days == 0) {
          // selber Tag
        } else if (days <= 3) {
          newStreak++;
        } else if (newShields > 0) {
          newShields--;
          newStreak++;
        } else {
          newStreak = 1;
        }
      }
      lastDay = day;
    }

    history
      ..clear()
      ..addAll(newHistory);
    logs
      ..clear()
      ..addAll(newLogs);
    xp = totalXp;
    streak = newStreak;
    shields = newShields;
    lastWorkoutDate = newLogs.last.date;
    save();
    notifyListeners();

    return {
      'sessions': sessions.length,
      'sets': newHistory.length,
      'xp': totalXp,
      'streak': newStreak,
    };
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
