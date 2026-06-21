import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../data/templates.dart';
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

  final Program program = Templates.upperLower4x;

  // Gamification-Zustand
  int xp = 0;
  int streak = 0;
  int shields = 1;
  DateTime? lastWorkoutDate;
  String displayName = 'Athlet';

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

  // Naechste geplante Session (rotiert durch Upper A/Lower A/Upper B/Lower B).
  SessionTemplate get nextSession =>
      program.sessions[logs.length % program.sessions.length];

  // Name -> Muskelgruppe (aus allen Programm-Uebungen).
  Map<String, MuscleGroup> get _muscleByExercise {
    final map = <String, MuscleGroup>{};
    for (final session in program.sessions) {
      for (final ex in session.exercises) {
        map[ex.name] = ex.muscle;
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

  // Letzte Arbeitssaetze einer Uebung (public, fuer Inline-History im Workout).
  List<CompletedSet> lastWorkingSetsFor(String exerciseName) =>
      _lastWorkingSetsFor(exerciseName);

  // ---- Laden & Speichern (lokal) ----

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null) {
      // Erster Start: Demo-Daten, damit das Dashboard lebt.
      _seedDemoHistory();
      lastWorkoutDate = DateTime.now().subtract(const Duration(days: 1));
      xp = 2600;
      streak = 12;
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
    } catch (_) {
      // Beschaedigte Daten -> sauberer Neustart mit Demo.
      _seedDemoHistory();
      xp = 2600;
      streak = 12;
      shields = 1;
      displayName = 'Athlet';
      lastWorkoutDate = DateTime.now().subtract(const Duration(days: 1));
    }
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'xp': xp,
      'streak': streak,
      'shields': shields,
      'displayName': displayName,
      'lastWorkoutDate': lastWorkoutDate?.toIso8601String(),
      'restOverrides': _restOverrides,
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

  // ---- Demo-Daten, damit das Dashboard beim ersten Start lebt ----
  void _seedDemoHistory() {
    final past = DateTime.now().subtract(const Duration(days: 3));
    history.addAll([
      CompletedSet(
          exerciseName: 'Schraegbankdruecken',
          weight: 80,
          reps: 8,
          rpe: 8,
          date: past),
      CompletedSet(
          exerciseName: 'Schraegbankdruecken',
          weight: 80,
          reps: 7,
          rpe: 9,
          date: past),
      CompletedSet(
          exerciseName: 'Latzug', weight: 70, reps: 10, rpe: 8, date: past),
      CompletedSet(
          exerciseName: 'Schulterdruecken',
          weight: 45,
          reps: 9,
          rpe: 8,
          date: past),
    ]);
  }
}
