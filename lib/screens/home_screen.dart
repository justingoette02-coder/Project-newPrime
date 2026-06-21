import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/aura_orb.dart';
import 'workout_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            final tier = state.auraTier;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _topBar(context),
                const SizedBox(height: 8),
                _heroAura(context, state, tier),
                const SizedBox(height: 20),
                _xpBar(state),
                const SizedBox(height: 20),
                _statRow(state, tier),
                const SizedBox(height: 20),
                _todayCard(context, state),
                const SizedBox(height: 20),
                _weeklyVolume(state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('newPRIME',
            style: TextStyle(
                fontSize: 13,
                letterSpacing: 3,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
              child: const Icon(Icons.history,
                  size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.bolt, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ],
    );
  }

  Widget _heroAura(BuildContext context, AppState state, tier) {
    return Row(
      children: [
        AuraOrb(
            tier: tier,
            level: state.level,
            size: 68,
            dimmed: state.isStreakAtRisk),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AuraOrb.colorForTier(tier.index),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('RANG ${tier.rank}',
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bg)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _editName(context, state),
                child: Row(
                  children: [
                    Text(state.displayName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit,
                        size: 13, color: AppColors.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text('Level ${state.level} · ${tier.name}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  void _editName(BuildContext context, AppState state) {
    final c = TextEditingController(text: state.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Name ändern',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.aura)),
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
              state.setDisplayName(c.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Speichern',
                style: TextStyle(color: AppColors.aura)),
          ),
        ],
      ),
    );
  }

  Widget _xpBar(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('XP', style: AppTheme.label),
            Text('${state.xpIntoLevel} / ${state.xpForNextLevel}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: state.levelProgress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.aura),
          ),
        ),
      ],
    );
  }

  Widget _statRow(AppState state, tier) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department,
            label: 'STREAK',
            value: '${state.streak}',
            suffix: ' Tage',
            color: AppColors.streak,
            badge: state.shields > 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shield,
                        size: 11, color: AppColors.textTertiary),
                    const SizedBox(width: 2),
                    Text('${state.shields}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textTertiary)),
                  ])
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.auto_awesome,
            label: 'AURA',
            value: tier.name,
            color: AuraOrb.colorForTier(tier.index),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    String suffix = '',
    required Color color,
    Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: AppTheme.label),
            if (badge != null) ...[
              const Spacer(),
              badge,
            ],
          ]),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600, color: color),
              children: [
                TextSpan(
                    text: suffix,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(BuildContext context, AppState state) {
    final session = state.nextSession;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderAura),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HEUTE',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      color: AppColors.aura,
                      fontWeight: FontWeight.w500)),
              Text('${session.exercises.length} Uebungen',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(session.name,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...session.exercises.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.name,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary)),
                    Text('${e.targetSets} x ${e.repMin}-${e.repMax}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              )),
          if (session.exercises.length > 3)
            Text('+ ${session.exercises.length - 3} weitere',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.aura,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
              onPressed: () {
                state.startSession(session);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const WorkoutScreen()));
              },
              child: const Text('Session starten',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyVolume(AppState state) {
    final vol = state.weeklyVolume();
    if (vol.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxVol = vol.values.reduce((a, b) => a > b ? a : b);
    final entries = vol.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('WOCHENVOLUMEN', style: AppTheme.label),
        const SizedBox(height: 10),
        ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(e.key.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: maxVol == 0 ? 0 : e.value / maxVol,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.auraDeep),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value.round()} kg',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            )),
      ],
    );
  }
}
