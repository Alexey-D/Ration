import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';

/// Ширина колонки с полями формы.
const formColumnWidth = 440.0;

/// Раскладка шага ввода: колонка формы и инструкция сбоку;
/// на узком экране инструкция — сворачиваемый блок над формой.
class StepFormLayout extends StatelessWidget {
  final Widget form;
  final List<String> instructions;

  const StepFormLayout({super.key, required this.form, required this.instructions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 820;
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: 24),
        child: wide
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: formColumnWidth, child: form),
                    const SizedBox(width: 32),
                    Expanded(child: InstructionPanel(steps: instructions)),
                  ]),
                ),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InstructionPanel(steps: instructions, collapsible: true),
                const SizedBox(height: 24),
                form,
              ]),
      );
    });
  }
}

/// «Шаг 1 из 2» + заголовок.
class StepTitle extends StatelessWidget {
  final int step;
  final int of;
  final String title;

  const StepTitle({super.key, required this.step, required this.of, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Шаг $step из $of', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
      const SizedBox(height: 4),
      Text(title, style: theme.textTheme.titleLarge),
    ]);
  }
}

/// Подзаголовок раздела формы.
class FormSection extends StatelessWidget {
  final String title;
  const FormSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: LayoutBuilder(
        builder: (context, c) => Row(children: [
          // длинный заголовок переносится, линия тянется на остаток ширины
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: c.maxWidth * 0.8),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ]),
      ),
    );
  }
}

/// Инструкция: нумерованные шаги в рамке.
class InstructionPanel extends StatelessWidget {
  final List<String> steps;
  final bool collapsible;

  const InstructionPanel({super.key, required this.steps, this.collapsible = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      for (final (i, line) in steps.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Text('${i + 1}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
          ]),
        ),
    ];

    if (collapsible) {
      return ExpansionTile(
        leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
        title: const Text('Как пользоваться'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: items,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Как пользоваться', style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 16),
          ...items,
        ]),
      ),
    );
  }
}

/// Числовое поле с проверкой диапазона; принимает запятую и точку.
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final double min;
  final double max;
  final bool integer;
  final bool signed;
  final bool enabled;
  final String? helper;
  final ValueChanged<double>? onValidChanged;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.min,
    required this.max,
    this.integer = false,
    this.signed = false,
    this.enabled = true,
    this.helper,
    this.onValidChanged,
  });

  String? _validate(String? text) {
    final v = parseNum(text ?? '');
    if (v == null) return 'Введите число';
    if (integer && v != v.roundToDouble()) return 'Целое число';
    if (v < min || v > max) return 'От ${fmt(min)} до ${fmt(max)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 2),
      keyboardType: TextInputType.numberWithOptions(decimal: !integer, signed: signed),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(signed ? r'[-+0-9.,]' : r'[0-9.,]')),
      ],
      validator: (text) => enabled ? _validate(text) : null,
      onChanged: (text) {
        if (onValidChanged != null && _validate(text) == null) onValidChanged!(parseNum(text)!);
      },
    );
  }
}

/// Число для начального текста поля: без лишнего «,0».
String numText(double v) => fmt(v, v == v.roundToDouble() ? 0 : 1);
