import 'package:flutter/material.dart';

import '../domain/energy_calculator.dart';
import '../domain/models.dart';
import 'format.dart';
import 'palette.dart';

const _tabular = [FontFeature.tabularFigures()];

class BarSegment {
  final double value;
  final Color color;
  final String? tooltip;
  const BarSegment(this.value, this.color, [this.tooltip]);
}

/// Горизонтальная полоса из долей — наглядно показывает, из чего складывается итог.
class StackedBar extends StatelessWidget {
  final List<BarSegment> segments;
  final double height;

  const StackedBar({super.key, required this.segments, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final s in segments)
        if (s.value > 0) s,
    ];
    final total = visible.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return SizedBox(height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final (i, s) in visible.indexed)
              Expanded(
                flex: (s.value / total * 1000).round().clamp(1, 1000),
                child: Padding(
                  padding: EdgeInsets.only(right: i == visible.length - 1 ? 0 : 2),
                  child: Tooltip(
                    message: s.tooltip ?? '',
                    child: ColoredBox(color: s.color, child: const SizedBox.expand()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Цветная точка-маркер.
class Dot extends StatelessWidget {
  final Color color;
  final double size;
  const Dot(this.color, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Строка легенды: маркер · подпись (и пояснение) · значение справа.
class LegendRow extends StatelessWidget {
  final Color? color;
  final String label;
  final String? hint;
  final String value;
  final bool strong;
  final Color? valueColor;

  const LegendRow({
    super.key,
    this.color,
    required this.label,
    this.hint,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: color == null ? null : Align(alignment: Alignment.centerLeft, child: Dot(color!)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: strong ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) : null),
                if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: (strong ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)?.copyWith(
              fontWeight: strong ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Цель на день» крупно + подпись дефицита / профицита.
class TargetHero extends StatelessWidget {
  final double kcal;
  final double goalPercent;
  final bool compact;

  const TargetHero({super.key, required this.kcal, required this.goalPercent, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Цель на день', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(
          '${fmt(kcal)} ккал',
          style: (compact ? theme.textTheme.headlineSmall : theme.textTheme.headlineMedium)?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontFeatures: _tabular,
          ),
        ),
        Text(goalLabel(goalPercent), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

String goalLabel(double goalPercent) => goalPercent == 0
    ? 'поддержание веса'
    : goalPercent < 0
    ? 'дефицит ${fmt(-goalPercent)} %'
    : 'профицит ${fmt(goalPercent)} %';

/// Из чего складывается суточный расход: BMR + бытовая активность + тренировки.
class EnergyBreakdown extends StatelessWidget {
  final EnergyResult energy;
  final Profile profile;

  const EnergyBreakdown({super.key, required this.energy, required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final e = energy;
    final p = profile;
    final activity = e.tdcRest - e.bmr;
    final training = p.includeTraining ? e.trainingKcal : 0.0;
    final tdc = p.includeTraining ? e.tdcTraining : e.tdcRest;
    final correction = e.target.kcal - tdc;
    final bmrHint = e.bmrMethod == BmrMethod.bodyFat
        ? 'Каннингем, ${fmt(p.bodyFatPercent!, 1)} % жира'
        : 'Миффлин — Сан Жеор';
    final trainingHint = p.trainingMode == TrainingMode.manual
        ? 'по данным браслета'
        : e.sessions.length == 1
        ? '1 тренировка'
        : '${e.sessions.length} тренировки';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StackedBar(
          segments: [
            BarSegment(e.bmr, c.bmr, 'BMR'),
            BarSegment(activity, c.activity, 'Бытовая активность'),
            BarSegment(training, c.training, 'Тренировки'),
          ],
        ),
        const SizedBox(height: 8),
        LegendRow(color: c.bmr, label: 'Базовый обмен (BMR)', hint: bmrHint, value: fmt(e.bmr)),
        LegendRow(color: c.activity, label: 'Бытовая активность', hint: '+20 % к BMR', value: fmt(activity)),
        if (p.includeTraining)
          LegendRow(color: c.training, label: 'Тренировки', hint: trainingHint, value: fmt(training)),
        const Divider(height: 12),
        LegendRow(label: 'Расход за день (TDC)', value: fmt(tdc), strong: true),
        if (p.goalPercent != 0)
          LegendRow(
            label: p.goalPercent < 0 ? 'Дефицит' : 'Профицит',
            hint: '${fmtDelta(p.goalPercent, 0)} % к расходу',
            value: fmtDelta(correction, 0),
          ),
      ],
    );
  }
}

/// Доли белков, жиров и углеводов в калорийности + граммы.
class MacroBreakdown extends StatelessWidget {
  final Nutrients target;
  final Profile profile;

  const MacroBreakdown({super.key, required this.target, required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final t = target;
    final kcal = (p: t.protein * 4, f: t.fat * 9, c: t.carbs * 4);
    final sum = kcal.p + kcal.f + kcal.c;
    String share(double v) => sum <= 0 ? '0' : fmt(v / sum * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StackedBar(
          segments: [
            BarSegment(kcal.p, c.protein, 'Белки'),
            BarSegment(kcal.f, c.fat, 'Жиры'),
            BarSegment(kcal.c, c.carbs, 'Углеводы'),
          ],
        ),
        const SizedBox(height: 8),
        LegendRow(
          color: c.protein,
          label: 'Белки',
          hint: '${fmt(profile.proteinPerKg, 1)} г/кг · ${share(kcal.p)} % ккал',
          value: '${fmt(t.protein)} г',
        ),
        LegendRow(color: c.fat, label: 'Жиры', hint: '${share(kcal.f)} % ккал', value: '${fmt(t.fat)} г'),
        LegendRow(
          color: c.carbs,
          label: 'Углеводы',
          hint: 'остаток калорий · ${share(kcal.c)} % ккал',
          value: '${fmt(t.carbs)} г',
        ),
      ],
    );
  }
}

/// Компактная строка БЖУ: «● Б 143 г  ● Ж 104 г  ● У 790 г».
class MacroChips extends StatelessWidget {
  final Nutrients target;
  const MacroChips({super.key, required this.target});

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontFeatures: _tabular);
    Widget chip(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Dot(color, size: 8),
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        chip(c.protein, 'Б ${fmt(target.protein)} г'),
        chip(c.fat, 'Ж ${fmt(target.fat)} г'),
        chip(c.carbs, 'У ${fmt(target.carbs)} г'),
      ],
    );
  }
}
