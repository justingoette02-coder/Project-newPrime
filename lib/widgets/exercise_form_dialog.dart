import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

/// Geteiltes Formular zum Erstellen/Bearbeiten einer Uebung.
/// Liefert ein [ExerciseTemplate] oder null (Abbrechen).
/// Wird vom Plan-Editor und vom Workout-Screen ("Uebung hinzufuegen") genutzt.
Future<ExerciseTemplate?> showExerciseFormDialog(
  BuildContext context, {
  ExerciseTemplate? initial,
}) {
  return showDialog<ExerciseTemplate>(
    context: context,
    builder: (_) => _ExerciseFormDialog(initial: initial),
  );
}

class _ExerciseFormDialog extends StatefulWidget {
  final ExerciseTemplate? initial;
  const _ExerciseFormDialog({this.initial});

  @override
  State<_ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<_ExerciseFormDialog> {
  late final TextEditingController _name;
  late MuscleGroup _muscle;
  late int _repMin;
  late int _repMax;
  late int _targetSets;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _muscle = i?.muscle ?? MuscleGroup.chest;
    _repMin = i?.repMin ?? 8;
    _repMax = i?.repMax ?? 12;
    _targetSets = i?.targetSets ?? 3;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name darf nicht leer sein.');
      return;
    }
    if (_repMin > _repMax) {
      setState(() => _error = 'Min-Wdh darf nicht groesser als Max sein.');
      return;
    }
    Navigator.of(context).pop(ExerciseTemplate(
      name: name,
      muscle: _muscle,
      repMin: _repMin,
      repMax: _repMax,
      targetSets: _targetSets,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.initial == null ? 'Uebung hinzufuegen' : 'Uebung bearbeiten',
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.aura)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Muskelgruppe', style: AppTheme.label),
            const SizedBox(height: 4),
            DropdownButton<MuscleGroup>(
              value: _muscle,
              isExpanded: true,
              dropdownColor: AppColors.surfaceAlt,
              underline: Container(height: 1, color: AppColors.border),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              items: MuscleGroup.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.label),
                      ))
                  .toList(),
              onChanged: (m) => setState(() => _muscle = m ?? _muscle),
            ),
            const SizedBox(height: 16),
            _stepperRow('Saetze', _targetSets, 1, 8,
                (v) => setState(() => _targetSets = v)),
            _stepperRow('Min Wdh', _repMin, 1, 30,
                (v) => setState(() => _repMin = v)),
            _stepperRow('Max Wdh', _repMax, 1, 30,
                (v) => setState(() => _repMax = v)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Speichern',
              style: TextStyle(color: AppColors.aura)),
        ),
      ],
    );
  }

  Widget _stepperRow(
      String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, color: AppColors.textSecondary),
            onPressed:
                value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, color: AppColors.textSecondary),
            onPressed:
                value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
