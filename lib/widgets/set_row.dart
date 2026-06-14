import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

/// Eine Zeile zum Loggen eines Satzes: Gewicht, Wdh, RPE, Erledigt.
/// Aufwaermsaetze sind farblich markiert und zaehlen nicht ins Volumen.
class SetRow extends StatefulWidget {
  final int displayNumber;
  final SetEntry set;
  final void Function({double? weight, int? reps, double? rpe}) onChanged;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleWarmup;
  final VoidCallback onDelete;

  const SetRow({
    super.key,
    required this.displayNumber,
    required this.set,
    required this.onChanged,
    required this.onToggleDone,
    required this.onToggleWarmup,
    required this.onDelete,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _rpe;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
        text: widget.set.weight != null ? _fmt(widget.set.weight!) : '');
    _reps = TextEditingController(
        text: widget.set.reps?.toString() ?? '');
    _rpe = TextEditingController(
        text: widget.set.rpe != null ? _fmt(widget.set.rpe!) : '');
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rpe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warm = widget.set.isWarmup;
    final accent = warm ? AppColors.streak : AppColors.aura;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.set.done
            ? AppColors.surfaceAlt
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: widget.set.done ? accent : AppColors.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggleWarmup,
            child: SizedBox(
              width: 26,
              child: Text(
                warm ? 'W' : '${widget.displayNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: warm ? AppColors.streak : AppColors.textSecondary),
              ),
            ),
          ),
          _field(_weight, 'kg', (v) {
            widget.onChanged(weight: double.tryParse(v.replaceAll(',', '.')));
          }),
          _field(_reps, 'Wdh', (v) {
            widget.onChanged(reps: int.tryParse(v));
          }, integer: true),
          _field(_rpe, 'RPE', (v) {
            widget.onChanged(rpe: double.tryParse(v.replaceAll(',', '.')));
          }),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              widget.set.done
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: widget.set.done ? accent : AppColors.textTertiary,
              size: 24,
            ),
            onPressed: widget.onToggleDone,
          ),
          GestureDetector(
            onTap: widget.onDelete,
            child: const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.close,
                  size: 16, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
      ValueChanged<String> onChanged,
      {bool integer = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: c,
          onChanged: onChanged,
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.aura)),
          ),
        ),
      ),
    );
  }
}
