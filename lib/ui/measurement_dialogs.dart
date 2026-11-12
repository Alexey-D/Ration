import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import '../state/providers.dart';
import 'account_screen.dart';
import 'form_widgets.dart';
import 'format.dart';

/// Выбор даты замера (по умолчанию — сегодня).
Future<DateTime?> pickMeasurementDate(BuildContext context, {DateTime? initial}) {
  final today = dateOnly(DateTime.now());
  return showDatePicker(
    context: context,
    initialDate: initial ?? today,
    firstDate: DateTime(2000),
    lastDate: today,
    helpText: 'Дата замера',
  );
}

/// «Сохранить замер»: дата → запись в историю (объединяется с замером за ту же дату).
Future<void> saveMeasurementFlow(
  BuildContext context,
  WidgetRef ref,
  Measurement Function(DateTime date) build,
) async {
  final date = await pickMeasurementDate(context);
  if (date == null || !context.mounted) return;
  await ref.read(measurementsProvider.notifier).save(build(date));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('Замер за ${fmtDate(date)} сохранён в личном кабинете'),
    action: SnackBarAction(
      label: 'Открыть',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
    ),
  ));
}

/// Ручной ввод нового замера или правка сохранённого ([initial]).
/// Масса, % жира, обхваты и заметка; остальные показатели замера сохраняются как были.
class MeasurementDialog extends StatefulWidget {
  final Measurement? initial;

  /// Масса по умолчанию для нового замера (из профиля).
  final double? defaultWeight;

  const MeasurementDialog({super.key, this.initial, this.defaultWeight});

  static Future<Measurement?> show(BuildContext context, {Measurement? initial, double? defaultWeight}) =>
      showDialog<Measurement>(
        context: context,
        builder: (_) => MeasurementDialog(initial: initial, defaultWeight: defaultWeight),
      );

  @override
  State<MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<MeasurementDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date = widget.initial?.date ?? dateOnly(DateTime.now());
  late final _weight = TextEditingController(text: _num(widget.initial?.weightKg ?? widget.defaultWeight));
  late final _fat = TextEditingController(text: _num(widget.initial?.bodyFatPercent, 1));
  late final _girths = {
    for (final g in Girth.values) g: TextEditingController(text: _num(widget.initial?.girths[g])),
  };
  late final _note = TextEditingController(text: widget.initial?.note ?? '');

  static String _num(double? v, [int digits = 1]) => v == null ? '' : numText(double.parse(v.toStringAsFixed(digits)));

  @override
  void dispose() {
    for (final c in [_weight, _fat, ..._girths.values, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final weight = parseNum(_weight.text);
    final fat = parseNum(_fat.text);
    final girths = {
      for (final e in _girths.entries)
        if (parseNum(e.value.text) case final v?) e.key: v,
    };
    final i = widget.initial;
    // масса жира и LBM следуют за массой и % жира
    final fatKg = weight != null && fat != null ? weight * fat / 100 : (fat == null ? null : i?.fatKg);
    final note = _note.text.trim();
    Navigator.of(context).pop(Measurement(
      id: i?.id,
      date: _date,
      weightKg: weight,
      heightCm: i?.heightCm,
      age: i?.age,
      bodyFatPercent: fat,
      fatKg: fatKg,
      leanKg: weight != null && fatKg != null ? weight - fatKg : (fat == null ? null : i?.leanKg),
      muscleKg: i?.muscleKg,
      skinfolds: i?.skinfolds ?? const {},
      girths: girths,
      bmr: i?.bmr,
      bmrMethod: i?.bmrMethod,
      tdc: i?.tdc,
      target: i?.target,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final editing = widget.initial != null;
    Widget girthField(Girth g) => NumberField(
          key: Key('girth-${g.name}'),
          controller: _girths[g]!,
          label: g.label,
          suffix: 'см',
          min: 10,
          max: 250,
          required: false,
        );

    return AlertDialog(
      title: Text(editing ? 'Замер за ${fmtDate(_date)}' : 'Новый замер'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (!editing) ...[
                OutlinedButton.icon(
                  key: const Key('measurementDate'),
                  icon: const Icon(Icons.event),
                  label: Text('Дата: ${fmtDate(_date)}'),
                  onPressed: () async {
                    final d = await pickMeasurementDate(context, initial: _date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
                gap,
              ],
              NumberField(
                key: const Key('measurementWeight'),
                controller: _weight,
                label: 'Масса тела',
                suffix: 'кг',
                min: 30,
                max: 300,
                required: false,
              ),
              gap,
              NumberField(
                key: const Key('measurementFat'),
                controller: _fat,
                label: 'Процент жира',
                suffix: '%',
                min: 3,
                max: 60,
                required: false,
                helper: 'Например, с умных весов; по складкам — на экране калиперометрии',
              ),
              const SizedBox(height: 4),
              const FormSection('Обхваты, см'),
              for (final pair in [
                [Girth.waist, Girth.hips],
                [Girth.chest, Girth.arm],
                [Girth.thigh, Girth.calf],
              ]) ...[
                Row(children: [
                  Expanded(child: girthField(pair[0])),
                  const SizedBox(width: 12),
                  Expanded(child: girthField(pair[1])),
                ]),
                gap,
              ],
              TextFormField(
                key: const Key('measurementNote'),
                controller: _note,
                decoration: const InputDecoration(labelText: 'Заметка'),
                maxLines: 2,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(key: const Key('measurementSave'), onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
