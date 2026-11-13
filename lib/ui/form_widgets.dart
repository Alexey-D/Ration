import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'palette.dart';

/// Ширина колонки с полями формы.
const formColumnWidth = 440.0;

/// Раскладка шага ввода. Справка не занимает место на экране — она открывается
/// кнопкой «Как пользоваться» в [StepTitle].
///
/// [side] — второй столбец (на узком экране уходит под [form], либо порядок
/// разделов задаёт [narrow]); [header] — над столбцами; [bottomBar] —
/// закреплённая панель внизу экрана.
class StepFormLayout extends StatelessWidget {
  final Widget form;
  final Widget? side;
  final Widget? narrow;
  final Widget? header;
  final Widget? bottomBar;

  const StepFormLayout({super.key, required this.form, this.side, this.narrow, this.header, this.bottomBar});

  /// С этой ширины второй столбец стоит рядом с первым.
  static const twoColumnWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoColumns = side != null && c.maxWidth >= twoColumnWidth;
        final maxWidth = side != null ? 1080.0 : formColumnWidth + 80;
        final hPad = c.maxWidth >= 600 ? 32.0 : 16.0;
        final body = twoColumns
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  const SizedBox(width: 24),
                  Expanded(child: side!),
                ],
              )
            : narrow ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      form,
                      if (side != null) ...[const SizedBox(height: 16), side!],
                    ],
                  );
        Widget constrained(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
        final scroll = SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          child: constrained(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[header!, const SizedBox(height: 20)],
                body,
              ],
            ),
          ),
        );
        if (bottomBar == null) return scroll;
        final theme = Theme.of(context);
        return Column(
          children: [
            Expanded(child: scroll),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                  child: constrained(bottomBar!),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// «Шаг 1 из 3» + заголовок; справа — кнопка справки, если задан [help].
class StepTitle extends StatelessWidget {
  final int step;
  final int of;
  final String title;
  final List<String>? help;

  const StepTitle({super.key, required this.step, required this.of, required this.title, this.help});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Шаг $step из $of', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        if (help != null) ...[
          const SizedBox(width: 12),
          TextButton.icon(
            key: const Key('helpButton'),
            onPressed: () => showInstructions(context, help!),
            icon: const Icon(Icons.help_outline),
            label: const Text('Как пользоваться'),
          ),
        ],
      ],
    );
  }
}

/// Справка во всплывающем окне.
Future<void> showInstructions(BuildContext context, List<String> steps) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.help_outline),
    title: const Text('Как пользоваться'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(child: InstructionList(steps: steps)),
    ),
    actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Понятно'))],
  ),
);

/// Подзаголовок внутри диалога или раздела: текст и линия до края.
class FormSection extends StatelessWidget {
  final String title;
  const FormSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            // длинный заголовок переносится, линия тянется на остаток ширины
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.8),
              child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider()),
          ],
        ),
      ),
    );
  }
}

/// Нумерованные шаги справки.
class InstructionList extends StatelessWidget {
  final List<String> steps;

  const InstructionList({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, line) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Раздел формы: иконка в цветной плашке, заголовок, итог раздела справа.
/// Нейтральная заливка отделяет разделы друг от друга без лишних рамок.
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final Widget? trailing;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    // Material, а не Container: переключатели и плитки рисуют отклик на ближайшем Material
    return Material(
      color: Palette.of(context).section,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Итог раздела в заголовке [SectionCard]: «750 ккал».
class SectionValue extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionValue(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: color ?? theme.colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
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

  /// false — пустое поле допустимо.
  final bool required;
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
    this.required = true,
    this.helper,
    this.onValidChanged,
  });

  String? _validate(String? text) {
    if (!required && (text ?? '').trim().isEmpty) return null;
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
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(signed ? r'[-+0-9.,]' : r'[0-9.,]'))],
      validator: (text) => enabled ? _validate(text) : null,
      onChanged: (text) {
        final v = parseNum(text);
        if (onValidChanged != null && v != null && _validate(text) == null) onValidChanged!(v);
      },
    );
  }
}

/// Число для начального текста поля: без лишнего «,0».
String numText(double v) => fmt(v, v == v.roundToDouble() ? 0 : 1);
