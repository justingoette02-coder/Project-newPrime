import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../data/templates.dart';
import 'gamification.dart';

/// Ergebnis eines abgeschlossenen Workouts (fuer die Belohnungs-Anzeige).
class WorkoutResult {
  final int xpEarned;
  final List<String> prExercises;
  final bool leveledUp;
  final int newLevel;
  final int streak;

  WorkoutResult({
    required this.xpEarned,
    required this.prExercises,
    required this.leveledUp,
    required this.newLevel,
    required this.streak,
  });
}

/// Zentraler App-Zustand (MVP: lokal im Speicher).
/// Spaeter wird hier die Supabase-Sync-Schicht angedockt.
class AppState extends ChangeNotifier {
  final Program program = Templates.upperLower4x;

  // Gamification-Zustand
  int xp = 2600;
  int streak = 12;
  DateTime? lastWorkoutDate;

  // Historie aller abgeschlossenen Saetze (Basis fuer Progression & PR).
  final List<CompletedSet> history = [];
  final List<WorkoutLog> logs = [];

  // Laufende Session
  SessionTemplate? activeTemplate;
  List<ExerciseInstance> activeExercises = [];

  AppState() {
    lastWorkoutDate = DateTime.now().subtract(const Duration(days: 1));
    _seedDemoHistory();
  }

  int get level => LevelSystem.levelForXp(xp);
  double get levelProgress => LevelSystem.levelProgress(xp);
  int get xpIntoLevel => LevelSystem.xpIntoLevel(xp);
  int get xpForNextLevel => LevelSystem.xpForNextLevel(xp);
  AuraTier get auraTier => AuraTier.forStreak(streak);

  /// Naechste geplante Session (rotiert durch Upper A/Lower A/Upper B/Lower B).
  SessionTemplate get nextSession =>
      program.sessions[logs.length % program.sessions.length];

  /// Name -> Muskelgruppe (aus allen Programm-Uebungen).
  Map<String, MuscleGroup> get _muscleByExercise {
    final map = <String, MuscleGroup>{};
    for (final session in program.sessions) {
      for (final ex in session.exercises) {
        map[ex.name] = ex.muscle;
      }
    }
    return map;
  }

  /// Wochenvolumen (Tonnage) pro Muskelgruppe der letzten 7 Tage.
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

  // ---- Session-Ablauf ----

  void startSession(SessionTemplate template) {
    activeTemplate = template;
    activeExercises = template.exercises.map((ex) {
      final sets = List.generate(
        ex.targetSets,
        (_) => SetEntry(),
      );
      return ExerciseInstance(template: ex, sets: sets);
    }).toList();
    notifyListeners();
  }

  void addSet(int exerciseIndex, {bool warmup = false}) {
    activeExercises[exerciseIndex].sets.add(SetEntry(isWarmup: warmup));
    notifyListeners();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    activeExercises[exerciseIndex].sets.removeAt(setIndex);
    notifyListeners();
  }

  /// Satz als erledigt markieren -> Mikro-Reward (Haptik) + sofort sichtbar.
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

  /// Progression-Vorschlag fuer eine Uebung (Double Progression).
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
    final latestDay = DateTime(
        relevant.first.date.year, relevant.first.date.month, relevant.first.date.day);
    return relevant.where((s) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return d == latestDay;
    }).toList();
  }

  /// Workout abschliessen: XP, Streak, PR-Erkennung, Historie schreiben.
  WorkoutResult finishWorkout() {
    final now = DateTime.now();
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

    // Trainings-Streak: bleibt erhalten bei regelmaessigem Training
    // (max 3 Tage Pause), sonst Reset.
    if (lastWorkoutDate != null) {
      final days = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastWorkoutDate!.year, lastWorkoutDate!.month,
              lastWorkoutDate!.day))
          .inDays;
      if (days == 0) {
        // zweites Workout am selben Tag — Streak unveraendert
      } else if (days <= 3) {
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
    ));

    activeTemplate = null;
    activeExercises = [];

    final result = WorkoutResult(
      xpEarned: xpEarned,
      prExercises: prs,
      leveledUp: level > beforeLevel,
      newLevel: level,
      streak: streak,
    );
    notifyListeners();
    return result;
  }

  // ---- Demo-Daten, damit das Dashboard sofort lebt ----
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
