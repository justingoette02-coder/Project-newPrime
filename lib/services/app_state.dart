import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../data/templates.dart';
import '../data/hevy_seed.dart';
import 'gamification.dart';
import 'local_store.dart';
import 'hevy_csv_importer.dart';

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

// Zentraler App-Zustand (Orchestrator). Persistenz laeuft ueber LocalStore,
// der CSV-Import ueber HevyCsvImporter — AppState selbst kennt weder
// shared_preferences noch das CSV-Format.
class AppState extends ChangeNotifier {
  final LocalStore _store = LocalStore();

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
  DateTime? streakStartDate; // Start des aktuellen Konsistenz-Laufs (Tage-Streak)
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
  // Sichtbare Streak fuers Aura-Widget (sinkt bei laengerer Pause -> Abstieg).
  int get effectiveStreak =>
      AuraDecay.effectiveStreak(streak, lastWorkoutDate, DateTime.now());
  AuraTier get auraTier => AuraTier.forStreak(effectiveStreak);

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

  // Index des als Naechstes faelligen Trainingstags (aus der Historie
  // abgeleitet, rotiert durch die Reihenfolge des aktiven Plans).
  int get nextSessionIndex =>
      Rotation.nextSessionIndex(logs, activeProgram.sessions);

  // Naechster geplanter Trainingstag: eins nach dem zuletzt absolvierten Tag
  // dieses Plans. Steht auf der Startseite ("HEUTE").
  SessionTemplate get nextSession =>
      activeProgram.sessions[nextSessionIndex];

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
      final muscle = s.muscle ?? byName[s.exerciseName];
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
    final persisted = await _store.load();
    if (persisted == null) {
      // Erster Start oder beschaedigte Daten: echte Hevy-Historie als Seed.
      _loadEmbeddedSeedData();
      await save();
      notifyListeners();
      return;
    }
    _apply(persisted);
    // Migration: aeltere (Demo-)Daten -> echte Hevy-Daten automatisch laden.
    if (_appliedSeedVersion < HevySeed.seedVersion) {
      _loadEmbeddedSeedData();
      await save();
    }
    // Streak/Schilde immer aus den (geladenen) Logs ableiten (deckt Alt-Saves ab).
    _applyConsistency();
    notifyListeners();
  }

  // Persistierten Zustand in die Felder uebernehmen.
  void _apply(PersistedState p) {
    xp = p.xp;
    streak = p.streak;
    shields = p.shields;
    displayName = p.displayName;
    lastWorkoutDate = p.lastWorkoutDate;
    streakStartDate = p.streakStartDate;
    _appliedSeedVersion = p.seedVersion;
    _restOverrides
      ..clear()
      ..addAll(p.restOverrides);
    selectedProgramName =
        p.selectedProgramName ?? suggestedPrograms.first.name;
    customPrograms
      ..clear()
      ..addAll(p.customPrograms);
    history
      ..clear()
      ..addAll(p.history);
    logs
      ..clear()
      ..addAll(p.logs);
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
    if (displayName == 'Athlet') displayName = 'Justin';
    _appliedSeedVersion = HevySeed.seedVersion;
    // Streak (Tage) + Schilde aus den Seed-Log-Tagen ableiten.
    _applyConsistency();
  }

  Future<void> save() => _store.save(_snapshot());

  // Momentaufnahme der persistierten Felder fuer den LocalStore.
  PersistedState _snapshot() => PersistedState(
        xp: xp,
        streak: streak,
        shields: shields,
        lastWorkoutDate: lastWorkoutDate,
        streakStartDate: streakStartDate,
        displayName: displayName,
        seedVersion: _appliedSeedVersion,
        restOverrides: _restOverrides,
        selectedProgramName: selectedProgramName,
        customPrograms: customPrograms,
        history: history,
        logs: logs,
      );

  // Streak (Tage), Streak-Start und Schilde aus den Logs ableiten — EINE
  // Quelle der Wahrheit (genutzt von finishWorkout, Replay, Import, Seed, Load).
  void _applyConsistency() {
    final c = StreakPolicy.replay([for (final l in logs) l.date]);
    streak = c.streakDays;
    streakStartDate = c.streakStart;
    shields = c.shields;
    lastWorkoutDate = c.lastDay;
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

  // Satz als erledigt markieren -> Mikro-Reward (Haptik + Ton) + sofort sichtbar.
  void toggleSetDone(int exerciseIndex, int setIndex) {
    final set = activeExercises[exerciseIndex].sets[setIndex];
    set.done = !set.done;
    if (set.done) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
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

    // Erledigte Saetze der Session als CompletedSet sammeln.
    final completed = <CompletedSet>[];
    for (final ex in activeExercises) {
      for (final s in ex.sets) {
        if (!s.done || s.weight == null || s.reps == null) continue;
        completed.add(CompletedSet(
          exerciseName: ex.name,
          weight: s.weight!,
          reps: s.reps!,
          rpe: s.rpe,
          restSeconds: s.restSeconds,
          tempo: s.tempo,
          note: s.note,
          muscle: ex.template.muscle,
          date: now,
          isWarmup: s.isWarmup,
        ));
      }
    }

    // XP + PRs ueber die gemeinsame Bewertung — identische Regeln wie beim
    // Replay (deleteLog) und CSV-Import (gegen die bisherige Historie).
    final score = SessionScorer.scoreSession(
        completed, SessionScorer.bestEst1RMByExercise(history));
    final int xpEarned = score.xp;
    final prs = score.prExercises.toList();

    final beforeLevel = level;
    xp += xpEarned;

    history.addAll(completed);
    logs.add(WorkoutLog(
      sessionName: activeTemplate?.name ?? 'Workout',
      date: now,
      sets: completed,
      xpEarned: xpEarned,
      durationMinutes: durationMinutes,
    ));

    // Streak (Tage) + Schilde aus den Logs ableiten — eine Quelle der Wahrheit
    // (gleiche Policy wie Replay/Import/Seed).
    _applyConsistency();

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
    _applyConsistency(); // leere Logs -> Streak 0, Schild 1, Start null
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
      rebuiltHistory.addAll(log.sets);
      final score = SessionScorer.scoreSession(log.sets, bestEst1RM);
      totalXp += score.xp;
      rebuiltLogs.add(WorkoutLog(
        sessionName: log.sessionName,
        date: log.date,
        sets: log.sets,
        xpEarned: score.xp,
        durationMinutes: log.durationMinutes,
      ));
    }

    history
      ..clear()
      ..addAll(rebuiltHistory);
    logs
      ..clear()
      ..addAll(rebuiltLogs);
    xp = totalXp;
    _applyConsistency();
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
    final sessions =
        HevyCsvImporter.parse(bytes, muscleByName: _muscleByExercise);
    if (sessions == null || sessions.isEmpty) return null;
    return _applyImportedSessions(sessions);
  }

  // Geparste Sessions in den Zustand uebernehmen (Scoring + Streak + speichern).
  Map<String, int> _applyImportedSessions(List<ImportedSession> sessions) {
    final bestEst1RM = <String, double>{};
    int totalXp = 0;
    final newHistory = <CompletedSet>[];
    final newLogs = <WorkoutLog>[];
    for (final s in sessions) {
      newHistory.addAll(s.sets);
      final score = SessionScorer.scoreSession(s.sets, bestEst1RM);
      totalXp += score.xp;
      newLogs.add(WorkoutLog(
        sessionName: s.title,
        date: s.start,
        sets: s.sets,
        xpEarned: score.xp,
        durationMinutes: s.durationMinutes,
      ));
    }
    history
      ..clear()
      ..addAll(newHistory);
    logs
      ..clear()
      ..addAll(newLogs);
    xp = totalXp;
    _applyConsistency();
    save();
    notifyListeners();
    return {
      'sessions': sessions.length,
      'sets': newHistory.length,
      'xp': totalXp,
      'streak': streak,
    };
  }

}
