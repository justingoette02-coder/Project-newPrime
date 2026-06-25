import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/aura_orb.dart';
import '../widgets/aura_eyes.dart';
import 'workout_screen.dart';
import 'history_screen.dart';
import 'program_builder_screen.dart';
import 'session_detail_screen.dart';

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
                const SizedBox(height: 12),
                Center(
                  child: AuraEyes(
                      tier: tier,
                      width: 132,
                      dimmed: state.isStreakAtRisk),
                ),
                const SizedBox(height: 10),
                _auraTitle(tier),
                const SizedBox(height: 16),
                _auraBars(state, tier),
                const SizedBox(height: 18),
                _heroAura(context, state, tier),
                const SizedBox(height: 20),
                _streakCard(state),
                const SizedBox(height: 20),
                _todayCard(context, state),
                const SizedBox(height: 16),
                _programSection(context, state),
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
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => _showImportDialog(context),
              child: const Icon(Icons.file_upload_outlined,
                  size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.bolt, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ],
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final state = context.read<AppState>();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Trainingsdaten laden',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text(
          'Lade die eingebettete Historie (deine vollständigen Hevy-Daten, '
          'kein Datei-Upload nötig) oder importiere eine neue CSV-Datei. '
          'Die bestehende Historie wird ersetzt; XP, Level und Streak werden '
          'neu berechnet.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV wählen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'embedded'),
            child: const Text('Eingebettete Daten',
                style: TextStyle(color: AppColors.aura)),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel' || !context.mounted) return;

    if (choice == 'embedded') {
      final result = state.applyEmbeddedSeed();
      if (!context.mounted) return;
      _showImportResult(context, result);
      return;
    }

    final result = await state.importHevyCsv();
    if (!context.mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import fehlgeschlagen oder abgebrochen.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    _showImportResult(context, result);
  }

  void _showImportResult(BuildContext context, Map<String, int> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Import erfolgreich',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(
          '${result['sessions']} Sessions · ${result['sets']} Sätze\n'
          'XP: ${result['xp']}  ·  Streak: ${result['streak']}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.aura)),
          ),
        ],
      ),
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

  // Zentrierter Aura-Titel unter den Augen (Effekt "entspricht dem Titel").
  Widget _auraTitle(tier) {
    final color = AuraOrb.colorForTier(tier.index);
    return Center(
      child: Text(
        '${tier.name.toUpperCase()} · RANG ${tier.rank}',
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Zwei gestapelte Balken bei den Augen: Aura-Fortschritt + XP.
  Widget _auraBars(AppState state, tier) {
    final auraColor = AuraOrb.colorForTier(tier.index);
    final nextAt = tier.nextAt;
    return Column(
      children: [
        _progressBar(
          label: 'AURA',
          trailing:
              nextAt == null ? 'MAX' : '${state.effectiveStreak} / $nextAt',
          value: tier.progress(state.effectiveStreak),
          color: auraColor,
        ),
        const SizedBox(height: 14),
        _progressBar(
          label: 'XP',
          trailing: '${state.xpIntoLevel} / ${state.xpForNextLevel}',
          value: state.levelProgress,
          color: AppColors.aura,
        ),
      ],
    );
  }

  Widget _progressBar({
    required String label,
    required String trailing,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.label),
            Text(trailing,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // Streak ueber die volle Breite (Aura wird oben durch Augen + Balken gezeigt).
  Widget _streakCard(AppState state) {
    return _statCard(
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
          // Tipp auf den Info-Bereich -> Tag-Uebersicht (Uebungen + letzte Stats).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SessionDetailScreen.planned(session))),
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
                    Row(
                      children: [
                        Text('${session.exercises.length} Uebungen',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textTertiary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textTertiary),
                      ],
                    ),
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
              ],
            ),
          ),
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

  // Kleines Badge fuer den als Naechstes faelligen Trainingstag.
  Widget _nextBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.aura,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('NAECHSTES',
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
                color: AppColors.bg)),
      );

  // Aktiver Plan + frei waehlbare Trainingstage.
  Widget _programSection(BuildContext context, AppState state) {
    final program = state.activeProgram;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('TRAININGSPLAN', style: AppTheme.label),
            const Spacer(),
            GestureDetector(
              onTap: () => _showProgramPicker(context, state),
              child: Row(
                children: [
                  Flexible(
                    child: Text(program.name,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.unfold_more,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              ...List.generate(program.sessions.length, (i) {
                final s = program.sessions[i];
                final isNext = i == state.nextSessionIndex;
                return Column(
                  children: [
                    if (i > 0)
                      const Divider(
                          height: 1, color: AppColors.border, thickness: 1),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  SessionDetailScreen.planned(s))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(s.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      if (isNext) ...[
                                        const SizedBox(width: 8),
                                        _nextBadge(),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${s.exercises.length} Uebungen',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textTertiary)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 22, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // BottomSheet: Plan wechseln, eigene Plaene bearbeiten/loeschen, neuen anlegen.
  void _showProgramPicker(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TRAININGSPLAN WAEHLEN', style: AppTheme.label),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...state.allPrograms.map((p) {
                        final active = p.name == state.activeProgram.name;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: active
                                ? AppColors.aura
                                : AppColors.textTertiary,
                            size: 20,
                          ),
                          title: Text(p.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                          subtitle: Text(
                              '${p.sessions.length} Tage'
                              '${p.isCustom ? " · eigen" : " · Vorschlag"}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary)),
                          trailing: p.isCustom
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 18,
                                          color: AppColors.textSecondary),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ProgramBuilderScreen(
                                                        existing: p)));
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.danger),
                                      onPressed: () {
                                        state.deleteCustomProgram(p.name);
                                        Navigator.of(ctx).pop();
                                      },
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () {
                            state.selectProgram(p.name);
                            Navigator.of(ctx).pop();
                          },
                        );
                      }),
                      const Divider(color: AppColors.border),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_circle_outline,
                            color: AppColors.aura, size: 20),
                        title: const Text('Neuen Plan erstellen',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.aura)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  const ProgramBuilderScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
