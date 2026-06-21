// Kern-Datenmodelle fuer Project newPrime.
// Hierarchie: Program -> SessionTemplate -> ExerciseInstance -> SetEntry

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  quads,
  hamstrings,
  glutes,
  calves,
  core,
}

extension MuscleGroupLabel on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.chest:
        return 'Brust';
      case MuscleGroup.back:
        return 'Ruecken';
      case MuscleGroup.shoulders:
        return 'Schulter';
      case MuscleGroup.biceps:
        return 'Bizeps';
      case MuscleGroup.triceps:
        return 'Trizeps';
      case MuscleGroup.quads:
        return 'Quadrizeps';
      case MuscleGroup.hamstrings:
        return 'Beinbeuger';
      case MuscleGroup.glutes:
        return 'Gesaess';
      case MuscleGroup.calves:
        return 'Waden';
      case MuscleGroup.core:
        return 'Core';
    }
  }
}

// Eine Uebung als Vorlage. Wiederholungsbereich ist je Uebung individuell
// (gemischt: schwer bei Grunduebungen, leichter bei Isolation).
class ExerciseTemplate {
  final String name;
  final MuscleGroup muscle;
  final int repMin;
  final int repMax;
  final int targetSets;

  const ExerciseTemplate({
    required this.name,
    required this.muscle,
    required this.repMin,
    required this.repMax,
    this.targetSets = 3,
  });
}

// Ein einzelner Satz — die Kern-Einheit des Trackings.
class SetEntry {
  double? weight; // kg
  int? reps;
  double? rpe; // 1..10
  int? restSeconds;
  String? tempo; // z.B. "3-1-1"
  String? note;
  bool isWarmup;
  bool done;

  SetEntry({
    this.weight,
    this.reps,
    this.rpe,
    this.restSeconds,
    this.tempo,
    this.note,
    this.isWarmup = false,
    this.done = false,
  });

  // Tonnage dieses Satzes (zaehlt nur bei Arbeitssaetzen).
  double get volume {
    if (isWarmup || weight == null || reps == null) return 0;
    return weight! * reps!;
  }
}

// Eine Uebung innerhalb einer laufenden Session, inkl. der geloggten Saetze.
class ExerciseInstance {
  final ExerciseTemplate template;
  final List<SetEntry> sets;

  ExerciseInstance({required this.template, List<SetEntry>? sets})
      : sets = sets ?? <SetEntry>[];

  String get name => template.name;
}

// Ein Trainingstag als Vorlage (z.B. "Upper A").
class SessionTemplate {
  final String name;
  final List<ExerciseTemplate> exercises;

  const SessionTemplate({required this.name, required this.exercises});
}

// Ein vollstaendiges Programm (Split).
class Program {
  final String name;
  final List<SessionTemplate> sessions;

  const Program({required this.name, required this.sessions});
}

// Ein abgeschlossener Satz fuer die Historie (Basis fuer Progression & PR).
class CompletedSet {
  final String exerciseName;
  final double weight;
  final int reps;
  final double? rpe;
  final DateTime date;
  final bool isWarmup;

  CompletedSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
    this.rpe,
    this.isWarmup = false,
  });

  double get volume => isWarmup ? 0 : weight * reps;

  // Geschaetztes 1RM (Epley-Formel) — fuer PR-Vergleich.
  double get estimated1RM => weight * (1 + reps / 30.0);

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'weight': weight,
        'reps': reps,
        'rpe': rpe,
        'date': date.toIso8601String(),
        'isWarmup': isWarmup,
      };

  factory CompletedSet.fromJson(Map<String, dynamic> j) => CompletedSet(
        exerciseName: j['exerciseName'] as String,
        weight: (j['weight'] as num).toDouble(),
        reps: j['reps'] as int,
        rpe: (j['rpe'] as num?)?.toDouble(),
        date: DateTime.parse(j['date'] as String),
        isWarmup: j['isWarmup'] as bool? ?? false,
      );
}

// Ein abgeschlossenes Workout fuer die Historie.
class WorkoutLog {
  final String sessionName;
  final DateTime date;
  final List<CompletedSet> sets;
  final int xpEarned;
  final int? durationMinutes;

  WorkoutLog({
    required this.sessionName,
    required this.date,
    required this.sets,
    required this.xpEarned,
    this.durationMinutes,
  });

  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);

  Map<String, dynamic> toJson() => {
        'sessionName': sessionName,
        'date': date.toIso8601String(),
        'xpEarned': xpEarned,
        'durationMinutes': durationMinutes,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
        sessionName: j['sessionName'] as String,
        date: DateTime.parse(j['date'] as String),
        xpEarned: j['xpEarned'] as int? ?? 0,
        durationMinutes: j['durationMinutes'] as int?,
        sets: (j['sets'] as List)
            .map((e) => CompletedSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
