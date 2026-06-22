import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final logs = state.logs.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verlauf',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              tooltip: 'Gesamte Historie löschen',
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.textSecondary),
              onPressed: () => _confirmClearAll(context, state),
            ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text('Noch keine abgeschlossenen Sessions.',
                  style: TextStyle(color: AppColors.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: logs.length,
              itemBuilder: (context, i) => _logCard(context, state, logs[i]),
            ),
    );
  }

  Future<void> _confirmDeleteLog(
      BuildContext context, AppState state, WorkoutLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Trainingstag löschen?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(
          '«${log.sessionName}» wird entfernt. XP, Level und Streak werden neu berechnet.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) state.deleteLog(log);
  }

  Future<void> _confirmClearAll(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Gesamte Historie löschen?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text(
          'Alle Trainingstage werden entfernt. XP, Level und Streak werden auf 0 zurückgesetzt. Das kann nicht rückgängig gemacht werden.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Alles löschen',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) state.clearAllHistory();
  }

  Widget _logCard(BuildContext context, AppState state, WorkoutLog log) {
    final exercises = _groupByExercise(log.sets);
    final dateLabel = _formatDate(log.date);

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
                child: Text(log.sessionName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text(dateLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _confirmDeleteLog(context, state, log),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2, bottom: 2),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _chip(Icons.bolt, '+${log.xpEarned} XP', AppColors.aura),
              const SizedBox(width: 8),
              _chip(Icons.fitness_center,
                  '${log.totalVolume.round()} kg', AppColors.textSecondary),
              if (log.durationMinutes != null) ...[
                const SizedBox(width: 8),
                _chip(Icons.timer_outlined,
                    '${log.durationMinutes} min', AppColors.textSecondary),
              ],
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...exercises.entries.map((e) => _exerciseRow(e.key, e.value)),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _exerciseRow(String name, List<CompletedSet> sets) {
    final working = sets.where((s) => !s.isWarmup).toList();
    if (working.isEmpty) return const SizedBox.shrink();

    final parts = working.take(4).map((s) {
      final w = s.weight == s.weight.roundToDouble()
          ? s.weight.toStringAsFixed(0)
          : s.weight.toStringAsFixed(1);
      return '$w×${s.reps}';
    }).join('  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Text(parts,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }

  Map<String, List<CompletedSet>> _groupByExercise(List<CompletedSet> sets) {
    final map = <String, List<CompletedSet>>{};
    for (final s in sets) {
      (map[s.exerciseName] ??= []).add(s);
    }
    return map;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return 'heute';
    if (diff == 1) return 'gestern';
    if (diff < 7) return 'vor $diff Tagen';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
