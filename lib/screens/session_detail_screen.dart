import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'workout_screen.dart';

/// Uebersicht eines Trainingstags — geplant (Uebungen + letzte Stats + Start)
/// oder absolviert (geloggte Saetze des Tages). Erreichbar per Tipp von der
/// Startseite und aus der Historie.
class SessionDetailScreen extends StatelessWidget {
  final SessionTemplate? template; // geplanter Tag
  final WorkoutLog? log; // absolvierter Tag

  const SessionDetailScreen.planned(SessionTemplate this.template, {super.key})
      : log = null;
  const SessionDetailScreen.log(WorkoutLog this.log, {super.key})
      : template = null;

  @override
  Widget build(BuildContext context) {
    final isLog = log != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isLog ? log!.sessionName : template!.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: isLog ? _logBody(context) : _plannedBody(context),
    );
  }

  // ---- Geplanter Tag ----

  Widget _plannedBody(BuildContext context) {
    final state = context.watch<AppState>();
    final session = template!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Text('${session.exercises.length} Uebungen',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 12),
              ...session.exercises.map((ex) => _plannedExercise(state, ex)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.aura,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  state.startSession(session);
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => const WorkoutScreen()));
                },
                child: const Text('Session starten',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _plannedExercise(AppState state, ExerciseTemplate ex) {
    final lastSets = state.lastWorkingSetsFor(ex.name);
    final suggestion = state.suggestionFor(ex);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(ex.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text('${ex.targetSets} x ${ex.repMin}-${ex.repMax}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(ex.muscle.label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          if (lastSets.isNotEmpty) ...[
            const SizedBox(height: 8),
            _statLine(Icons.history, 'Zuletzt', _setsLabel(lastSets)),
          ],
          if (suggestion != null) ...[
            const SizedBox(height: 6),
            _statLine(Icons.trending_up, 'Ziel', suggestion.hint,
                color: AppColors.streak),
          ],
        ],
      ),
    );
  }

  // ---- Absolvierter Tag ----

  Widget _logBody(BuildContext context) {
    final l = log!;
    final byExercise = <String, List<CompletedSet>>{};
    for (final s in l.sets) {
      (byExercise[s.exerciseName] ??= []).add(s);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _chip(Icons.bolt, '+${l.xpEarned} XP', AppColors.aura),
            _chip(Icons.fitness_center, '${l.totalVolume.round()} kg',
                AppColors.textSecondary),
            if (l.durationMinutes != null)
              _chip(Icons.timer_outlined, '${l.durationMinutes} min',
                  AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 16),
        ...byExercise.entries.map((e) => _loggedExercise(e.key, e.value)),
      ],
    );
  }

  Widget _loggedExercise(String name, List<CompletedSet> sets) {
    final working = sets.where((s) => !s.isWarmup).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (working.isEmpty)
            const Text('Nur Aufwaermsaetze',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary))
          else
            ...List.generate(working.length, (i) {
              final s = working[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                    ),
                    Text('${_fmt(s.weight)} kg x ${s.reps}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    if (s.rpe != null) ...[
                      const SizedBox(width: 8),
                      Text('RPE ${_fmt(s.rpe!)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---- Helpers ----

  Widget _statLine(IconData icon, String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textTertiary),
        const SizedBox(width: 6),
        Text('$label: ',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12, color: color ?? AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  static String _setsLabel(List<CompletedSet> sets) =>
      sets.take(5).map((s) => '${_fmt(s.weight)}x${s.reps}').join('  ');

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
