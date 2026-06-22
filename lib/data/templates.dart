import '../models/models.dart';

/// Standard-Template: Upper/Lower 4x pro Woche.
/// Wiederholungsbereiche sind je Uebung gemischt:
/// schwer bei Grunduebungen, leichter bei Isolation.
class Templates {
  /// Justins tatsaechliches aktuelles Programm (aus Hevy-Daten).
  static const Program justinUpperLower = Program(
    name: 'Upper / Lower — Aktuell',
    sessions: [
      SessionTemplate(name: 'Upper A', exercises: [
        ExerciseTemplate(
            name: 'Schrägbankdrücken (Kurzhantel)',
            muscle: MuscleGroup.chest,
            repMin: 8,
            repMax: 12,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Fliegende (Maschine)',
            muscle: MuscleGroup.chest,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Brust Dip (Gewichtet)',
            muscle: MuscleGroup.chest,
            repMin: 8,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Latzug (Kabel)',
            muscle: MuscleGroup.back,
            repMin: 8,
            repMax: 12,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Gerader Lat-Pulldown (Kabel)',
            muscle: MuscleGroup.back,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Seitheben (Kurzhantel)',
            muscle: MuscleGroup.shoulders,
            repMin: 12,
            repMax: 15,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Überkopf-Trizepsstrecken (Kabelzug)',
            muscle: MuscleGroup.triceps,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Incline Curl sitzend (Kurzhantel)',
            muscle: MuscleGroup.biceps,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Lower A', exercises: [
        ExerciseTemplate(
            name: 'Hackenschmidt Squat (Maschine)',
            muscle: MuscleGroup.quads,
            repMin: 8,
            repMax: 12,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Rumänisches Kreuzheben (Langhantel)',
            muscle: MuscleGroup.hamstrings,
            repMin: 8,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinbeugen sitzend',
            muscle: MuscleGroup.hamstrings,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Wadenheben sitzend',
            muscle: MuscleGroup.calves,
            repMin: 12,
            repMax: 20,
            targetSets: 4),
      ]),
      SessionTemplate(name: 'Upper B', exercises: [
        ExerciseTemplate(
            name: 'Bankdrücken (Kurzhantel)',
            muscle: MuscleGroup.chest,
            repMin: 8,
            repMax: 12,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Latzug (Kabel)',
            muscle: MuscleGroup.back,
            repMin: 8,
            repMax: 12,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Gerader Lat-Pulldown (Kabel)',
            muscle: MuscleGroup.back,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Iso-laterales Rudern',
            muscle: MuscleGroup.back,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Face Pull',
            muscle: MuscleGroup.shoulders,
            repMin: 15,
            repMax: 20,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Seitheben (Kabel)',
            muscle: MuscleGroup.shoulders,
            repMin: 12,
            repMax: 15,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Incline Curl sitzend (Kurzhantel)',
            muscle: MuscleGroup.biceps,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Trizepsdrücken',
            muscle: MuscleGroup.triceps,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Lower B', exercises: [
        ExerciseTemplate(
            name: 'Kreuzheben mit gestreckten Beinen',
            muscle: MuscleGroup.hamstrings,
            repMin: 8,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Hip Thrust (Maschine)',
            muscle: MuscleGroup.glutes,
            repMin: 8,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinbeugen sitzend',
            muscle: MuscleGroup.hamstrings,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinstrecken',
            muscle: MuscleGroup.quads,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Wadenheben sitzend',
            muscle: MuscleGroup.calves,
            repMin: 12,
            repMax: 20,
            targetSets: 4),
      ]),
    ],
  );

  static const Program upperLower4x = Program(
    name: 'Upper / Lower — 4x',
    sessions: [
      SessionTemplate(name: 'Upper A', exercises: [
        ExerciseTemplate(
            name: 'Schraegbankdruecken',
            muscle: MuscleGroup.chest,
            repMin: 6,
            repMax: 8,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Latzug',
            muscle: MuscleGroup.back,
            repMin: 8,
            repMax: 10,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Schulterdruecken',
            muscle: MuscleGroup.shoulders,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Rudern am Kabel',
            muscle: MuscleGroup.back,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Trizeps-Pushdown',
            muscle: MuscleGroup.triceps,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Bizeps-Curls',
            muscle: MuscleGroup.biceps,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Lower A', exercises: [
        ExerciseTemplate(
            name: 'Kniebeuge',
            muscle: MuscleGroup.quads,
            repMin: 6,
            repMax: 8,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Rumaenisches Kreuzheben',
            muscle: MuscleGroup.hamstrings,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinpresse',
            muscle: MuscleGroup.quads,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinbeuger liegend',
            muscle: MuscleGroup.hamstrings,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Wadenheben stehend',
            muscle: MuscleGroup.calves,
            repMin: 12,
            repMax: 15,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Plank / Core',
            muscle: MuscleGroup.core,
            repMin: 12,
            repMax: 20,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Upper B', exercises: [
        ExerciseTemplate(
            name: 'Flachbankdruecken',
            muscle: MuscleGroup.chest,
            repMin: 6,
            repMax: 8,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Rudern vorgebeugt',
            muscle: MuscleGroup.back,
            repMin: 8,
            repMax: 10,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Schraegbank Kurzhantel',
            muscle: MuscleGroup.chest,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Seitheben',
            muscle: MuscleGroup.shoulders,
            repMin: 12,
            repMax: 15,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Face Pulls',
            muscle: MuscleGroup.shoulders,
            repMin: 15,
            repMax: 20,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Hammer-Curls',
            muscle: MuscleGroup.biceps,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Lower B', exercises: [
        ExerciseTemplate(
            name: 'Kreuzheben',
            muscle: MuscleGroup.hamstrings,
            repMin: 4,
            repMax: 6,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Front-Kniebeuge',
            muscle: MuscleGroup.quads,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Ausfallschritte',
            muscle: MuscleGroup.glutes,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinbeuger sitzend',
            muscle: MuscleGroup.hamstrings,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Wadenheben sitzend',
            muscle: MuscleGroup.calves,
            repMin: 15,
            repMax: 20,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Hanging Leg Raise',
            muscle: MuscleGroup.core,
            repMin: 10,
            repMax: 15,
            targetSets: 3),
      ]),
    ],
  );

  /// Vorschlag: Push / Pull / Legs — 3 Tage, klassisch.
  static const Program pushPullLegs = Program(
    name: 'Push / Pull / Legs',
    sessions: [
      SessionTemplate(name: 'Push', exercises: [
        ExerciseTemplate(
            name: 'Flachbankdruecken',
            muscle: MuscleGroup.chest,
            repMin: 6,
            repMax: 8,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Schulterdruecken',
            muscle: MuscleGroup.shoulders,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Schraegbank Kurzhantel',
            muscle: MuscleGroup.chest,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Seitheben',
            muscle: MuscleGroup.shoulders,
            repMin: 12,
            repMax: 15,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Trizeps-Pushdown',
            muscle: MuscleGroup.triceps,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Pull', exercises: [
        ExerciseTemplate(
            name: 'Klimmzuege',
            muscle: MuscleGroup.back,
            repMin: 6,
            repMax: 10,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Rudern vorgebeugt',
            muscle: MuscleGroup.back,
            repMin: 8,
            repMax: 10,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Latzug',
            muscle: MuscleGroup.back,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Face Pulls',
            muscle: MuscleGroup.shoulders,
            repMin: 15,
            repMax: 20,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Bizeps-Curls',
            muscle: MuscleGroup.biceps,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Legs', exercises: [
        ExerciseTemplate(
            name: 'Kniebeuge',
            muscle: MuscleGroup.quads,
            repMin: 6,
            repMax: 8,
            targetSets: 4),
        ExerciseTemplate(
            name: 'Rumaenisches Kreuzheben',
            muscle: MuscleGroup.hamstrings,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinpresse',
            muscle: MuscleGroup.quads,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinbeuger liegend',
            muscle: MuscleGroup.hamstrings,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Wadenheben stehend',
            muscle: MuscleGroup.calves,
            repMin: 12,
            repMax: 15,
            targetSets: 4),
      ]),
    ],
  );

  /// Vorschlag: Ganzkoerper 3x — effizient fuer Einsteiger/wenig Zeit.
  static const Program fullBody3x = Program(
    name: 'Ganzkoerper — 3x',
    sessions: [
      SessionTemplate(name: 'Ganzkoerper A', exercises: [
        ExerciseTemplate(
            name: 'Kniebeuge',
            muscle: MuscleGroup.quads,
            repMin: 6,
            repMax: 8,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Flachbankdruecken',
            muscle: MuscleGroup.chest,
            repMin: 6,
            repMax: 8,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Rudern vorgebeugt',
            muscle: MuscleGroup.back,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Seitheben',
            muscle: MuscleGroup.shoulders,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Ganzkoerper B', exercises: [
        ExerciseTemplate(
            name: 'Kreuzheben',
            muscle: MuscleGroup.hamstrings,
            repMin: 4,
            repMax: 6,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Schulterdruecken',
            muscle: MuscleGroup.shoulders,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Latzug',
            muscle: MuscleGroup.back,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Beinpresse',
            muscle: MuscleGroup.quads,
            repMin: 10,
            repMax: 12,
            targetSets: 3),
      ]),
      SessionTemplate(name: 'Ganzkoerper C', exercises: [
        ExerciseTemplate(
            name: 'Front-Kniebeuge',
            muscle: MuscleGroup.quads,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Schraegbankdruecken',
            muscle: MuscleGroup.chest,
            repMin: 8,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Klimmzuege',
            muscle: MuscleGroup.back,
            repMin: 6,
            repMax: 10,
            targetSets: 3),
        ExerciseTemplate(
            name: 'Bizeps-Curls',
            muscle: MuscleGroup.biceps,
            repMin: 12,
            repMax: 15,
            targetSets: 3),
      ]),
    ],
  );

  /// Alle vorgeschlagenen (built-in) Programme.
  static const List<Program> suggested = [
    justinUpperLower,
    upperLower4x,
    pushPullLegs,
    fullBody3x,
  ];
}
