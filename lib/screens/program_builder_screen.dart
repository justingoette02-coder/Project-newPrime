import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/exercise_form_dialog.dart';

/// Editor zum Erstellen und Bearbeiten eigener Trainingsplaene.
/// [existing] == null -> neuer Plan, sonst Bearbeiten.
class ProgramBuilderScreen extends StatefulWidget {
  final Program? existing;
  const ProgramBuilderScreen({super.key, this.existing});

  @override
  State<ProgramBuilderScreen> createState() => _ProgramBuilderScreenState();
}

// Veraenderbarer Entwurf eines Trainingstags (waehrend der Bearbeitung).
class _DraftDay {
  String name;
  final List<ExerciseTemplate> exercises;
  _DraftDay(this.name, this.exercises);
}

class _ProgramBuilderScreenState extends State<ProgramBuilderScreen> {
  late final TextEditingController _programName;
  late final List<_DraftDay> _days;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _programName = TextEditingController(text: ex?.name ?? '');
    _days = ex == null
        ? [_DraftDay('Tag 1', [])]
        : ex.sessions
            .map((s) => _DraftDay(s.name, List.of(s.exercises)))
            .toList();
  }

  @override
  void dispose() {
    _programName.dispose();
    super.dispose();
  }

  void _addDay() {
    setState(() => _days.add(_DraftDay('Tag ${_days.length + 1}', [])));
  }

  void _renameDay(int i) async {
    final c = TextEditingController(text: _days[i].name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Tag umbenennen',
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
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
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: const Text('OK', style: TextStyle(color: AppColors.aura)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _days[i].name = result);
    }
  }

  Future<void> _addExercise(int dayIndex) async {
    final ex = await showExerciseFormDialog(context);
    if (ex != null) setState(() => _days[dayIndex].exercises.add(ex));
  }

  Future<void> _editExercise(int dayIndex, int exIndex) async {
    final ex = await showExerciseFormDialog(context,
        initial: _days[dayIndex].exercises[exIndex]);
    if (ex != null) {
      setState(() => _days[dayIndex].exercises[exIndex] = ex);
    }
  }

  void _save() {
    final name = _programName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Bitte einen Plan-Namen vergeben.');
      return;
    }
    final validDays =
        _days.where((d) => d.exercises.isNotEmpty).toList();
    if (validDays.isEmpty) {
      setState(() =>
          _error = 'Mindestens ein Tag mit mindestens einer Uebung noetig.');
      return;
    }
    final state = context.read<AppState>();
    // Namenskonflikt mit vorgeschlagenen Plaenen vermeiden.
    final clashesSuggested =
        state.suggestedPrograms.any((p) => p.name == name);
    final isEditingSame = widget.existing?.name == name;
    if (clashesSuggested && !isEditingSame) {
      setState(() => _error = 'Dieser Name ist bereits vergeben.');
      return;
    }

    final program = Program(
      name: name,
      isCustom: true,
      sessions: validDays
          .map((d) => SessionTemplate(name: d.name, exercises: d.exercises))
          .toList(),
    );
    // Beim Umbenennen den alten Eintrag entfernen.
    if (widget.existing != null && widget.existing!.name != name) {
      state.deleteCustomProgram(widget.existing!.name);
    }
    state.addOrUpdateCustomProgram(program);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Neuer Plan' : 'Plan bearbeiten',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Speichern',
                style: TextStyle(
                    color: AppColors.aura, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _programName,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Plan-Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.aura)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          // Tage per Long-Press umsortieren — die Reihenfolge ist die
          // Rotations-Reihenfolge auf der Startseite.
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _days.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final d = _days.removeAt(oldIndex);
                _days.insert(newIndex, d);
              });
            },
            itemBuilder: (context, i) => _dayCard(i),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addDay,
            icon: const Icon(Icons.add),
            label: const Text('Trainingstag hinzufuegen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.aura,
              side: const BorderSide(color: AppColors.borderAura),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(int i) {
    final day = _days[i];
    return Container(
      key: ObjectKey(day),
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
            children: [
              // Lange auf die Karte druecken zum Umsortieren (Reihenfolge = Rotation).
              const Icon(Icons.drag_indicator,
                  size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => _renameDay(i),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(day.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit,
                          size: 13, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              if (_days.length > 1)
                GestureDetector(
                  onTap: () => setState(() => _days.removeAt(i)),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(day.exercises.length, (ei) {
            final ex = day.exercises[ei];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _editExercise(i, ei),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                          Text(
                              '${ex.muscle.label} · ${ex.targetSets} x ${ex.repMin}-${ex.repMax}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => day.exercises.removeAt(ei)),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _addExercise(i),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Uebung'),
            style: TextButton.styleFrom(foregroundColor: AppColors.aura),
          ),
        ],
      ),
    );
  }
}
