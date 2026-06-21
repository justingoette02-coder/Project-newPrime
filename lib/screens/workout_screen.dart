import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/set_row.dart';
import '../widgets/aura_orb.dart';
import '../widgets/exercise_form_dialog.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Timer? _timer;
  int _rest = 0;
  String? _restExerciseName;

  void _startRest(int seconds, String exerciseName) {
    _restExerciseName = exerciseName;
    _timer?.cancel();
    setState(() => _rest = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_rest <= 1) {
        t.cancel();
        setState(() => _rest = 0);
      } else {
        setState(() => _rest--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final exercises = state.activeExercises;
    final template = state.activeTemplate;

    if (template == null) {
      return const Scaffold(body: Center(child: Text('Keine aktive Session')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(template.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => _finish(context, state),
            child: const Text('Fertig',
                style: TextStyle(
                    color: AppColors.aura, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: exercises.length + 1,
              itemBuilder: (context, ei) {
                if (ei == exercises.length) {
                  return _addExerciseButton(context, state);
                }
                return _exerciseCard(context, state, ei, exercises[ei]);
              },
            ),
          ),
          if (_rest > 0) _restBar(context, state),
        ],
      ),
    );
  }

  Widget _exerciseCard(
      BuildContext context, AppState state, int ei, ExerciseInstance ex) {
    final suggestion = state.suggestionFor(ex.template);
    final lastSets = state.lastWorkingSetsFor(ex.name);
    int working = 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text(
                  'Ziel ${ex.template.targetSets} x '
                  '${ex.template.repMin}-${ex.template.repMax}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          // Letzte Einheit als kompakte Referenzzeile
          if (lastSets.isNotEmpty) ...[
            const SizedBox(height: 6),
            _lastSetsRow(lastSets),
          ],
          if (suggestion != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up,
                      size: 14, color: AppColors.streak),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(suggestion.hint,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...List.generate(ex.sets.length, (si) {
            final set = ex.sets[si];
            if (!set.isWarmup) working++;
            return SetRow(
              key: ObjectKey(set),
              displayNumber: working,
              set: set,
              onChanged: ({double? weight, int? reps, double? rpe, String? note}) {
                state.updateSet(ei, si,
                    weight: weight, reps: reps, rpe: rpe, note: note);
              },
              onToggleDone: () {
                state.toggleSetDone(ei, si);
                if (ex.sets[si].done) {
                  _startRest(state.restFor(ex.template), ex.name);
                }
              },
              onToggleWarmup: () =>
                  state.updateSet(ei, si, isWarmup: !set.isWarmup),
              onDelete: () => state.removeSet(ei, si),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => state.addSet(ei),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Satz'),
                style: TextButton.styleFrom(foregroundColor: AppColors.aura),
              ),
              TextButton.icon(
                onPressed: () => state.addSet(ei, warmup: true),
                icon: const Icon(Icons.whatshot, size: 16),
                label: const Text('Aufwaermen'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.streak),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Button am Listenende: spontan eine Uebung zur Session hinzufuegen.
  Widget _addExerciseButton(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: OutlinedButton.icon(
        onPressed: () async {
          final ex = await showExerciseFormDialog(context);
          if (ex != null) state.addExerciseToActiveSession(ex);
        },
        icon: const Icon(Icons.add),
        label: const Text('Uebung hinzufuegen'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.aura,
          side: const BorderSide(color: AppColors.borderAura),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 0),
        ),
      ),
    );
  }

  // Kompakte Anzeige der letzten Session fuer diese Uebung.
  Widget _lastSetsRow(List<CompletedSet> sets) {
    final parts = sets.take(4).map((s) {
      final w = s.weight == s.weight.roundToDouble()
          ? s.weight.toStringAsFixed(0)
          : s.weight.toStringAsFixed(1);
      return '$w×${s.reps}';
    }).join('  ');
    return Row(
      children: [
        const Icon(Icons.history, size: 11, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(parts,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _restBar(BuildContext context, AppState state) {
    final m = (_rest ~/ 60).toString().padLeft(1, '0');
    final s = (_rest % 60).toString().padLeft(2, '0');
    return GestureDetector(
      onTap: () => _editRestTime(context, state),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: AppColors.surface,
        child: Row(
          children: [
            const Icon(Icons.timer_outlined,
                size: 18, color: AppColors.streak),
            const SizedBox(width: 8),
            Text('Pause  $m:$s',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 12, color: AppColors.textTertiary),
            const Spacer(),
            TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() => _rest = 0);
              },
              child: const Text('Skip',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog: Pausenzeit fuer diese Uebung anpassen und speichern.
  void _editRestTime(BuildContext context, AppState state) {
    if (_restExerciseName == null) return;
    final exerciseName = _restExerciseName!;
    int configuredSeconds;
    try {
      final ex = state.activeExercises.firstWhere((e) => e.name == exerciseName);
      configuredSeconds = state.restFor(ex.template);
    } catch (_) {
      configuredSeconds = 90;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          int newSeconds = configuredSeconds;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(exerciseName,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            content: StatefulBuilder(
              builder: (ctx2, setS2) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove,
                        color: AppColors.textSecondary),
                    onPressed: newSeconds > 15
                        ? () => setS2(() => newSeconds -= 15)
                        : null,
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${newSeconds ~/ 60}:${(newSeconds % 60).toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add,
                        color: AppColors.textSecondary),
                    onPressed: () => setS2(() => newSeconds += 15),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  state.setRestOverride(exerciseName, newSeconds);
                  Navigator.of(ctx).pop();
                  _startRest(newSeconds, exerciseName);
                },
                child: const Text('Speichern',
                    style: TextStyle(color: AppColors.aura)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _finish(BuildContext context, AppState state) {
    // Navigator vorab erfassen, damit context nicht ueber den async-Gap genutzt wird.
    final navigator = Navigator.of(context);
    final tierIndex = state.auraTier.index;
    final result = state.finishWorkout();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultDialog(result: result, tierIndex: tierIndex),
    ).then((_) {
      navigator.pop();
    });
  }
}

class _ResultDialog extends StatelessWidget {
  final WorkoutResult result;
  final int tierIndex;
  const _ResultDialog({required this.result, required this.tierIndex});

  @override
  Widget build(BuildContext context) {
    final hasPR = result.prExercises.isNotEmpty;
    final color = AuraOrb.colorForTier(tierIndex);
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPR)
              Text('BOSS-MOMENT',
                  style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                      color: color))
            else
              const Text('SESSION ABGESCHLOSSEN',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Icon(hasPR ? Icons.bolt : Icons.check_circle,
                size: 48, color: color),
            const SizedBox(height: 16),
            Text('+${result.xpEarned} XP',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (result.leveledUp)
              Text('Level Up — Level ${result.newLevel}!',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Streak: ${result.streak} Tage',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                if (result.durationMinutes != null) ...[
                  const Text('  ·  ',
                      style:
                          TextStyle(color: AppColors.textTertiary)),
                  Text('${result.durationMinutes} min',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ],
            ),
            if (hasPR) ...[
              const SizedBox(height: 12),
              Text('Neuer PR: ${result.prExercises.join(", ")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: color)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppColors.bg,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Weiter',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
