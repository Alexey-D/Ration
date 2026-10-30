import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/meal_layout.dart';
import '../domain/models.dart';
import '../domain/ration_plan.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'format.dart';
import 'theme_toggle.dart';

class RationScreen extends ConsumerWidget {
  const RationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(calculationProvider);
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final notifier = ref.read(calculationProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const AppLogo(size: 30, showTagline: false),
          const SizedBox(width: 16),
          Container(width: 1, height: 28, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(width: 16),
          const Flexible(child: Text('Рацион на день', overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Подогнать порции под цель (сбросить ручные правки)',
            icon: const Icon(Icons.balance),
            onPressed: calc == null ? null : notifier.rebalance,
          ),
          IconButton(
            tooltip: 'Вернуть продукты из шаблона',
            icon: const Icon(Icons.restart_alt),
            onPressed: calc == null ? null : notifier.resetToTemplate,
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: calc == null || catalog == null
          ? const Center(child: Text('Сначала заполните параметры'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCard(calc: calc),
                const SizedBox(height: 16),
                _MealCountsCard(plan: calc.plan),
                const SizedBox(height: 16),
                if (!calc.plan.macrosMatched) ...[
                  const _MacroWarning(),
                  const SizedBox(height: 16),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _RationTable(plan: calc.plan, catalog: catalog),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Calculation calc;
  const _SummaryCard({required this.calc});

  @override
  Widget build(BuildContext context) {
    final e = calc.energy;
    final p = calc.profile;
    final t = e.target;
    final goal = p.goalPercent == 0 ? '' : ' (${p.goalPercent > 0 ? '+' : ''}${fmt(p.goalPercent, 0)} %)';
    final title = !p.includeTraining
        ? 'День без тренировки'
        : calc.activity?.displayName ?? 'Тренировка по данным браслета';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 24, runSpacing: 12, children: [
            if (p.includeTraining && e.met != null) ...[
              _Metric('MET', fmt(e.met!, 1)),
              _Metric('Ккал/мин', fmt(e.kcalPerMinute!, 2)),
              _Metric('Ккал за ${p.trainingMinutes} мин', fmt(e.trainingKcal)),
            ],
            if (p.includeTraining && e.met == null) _Metric('Ккал тренировки (браслет)', fmt(e.trainingKcal)),
            _Metric(
              e.bmrMethod == BmrMethod.bodyFat ? 'BMR · по ${fmt(p.bodyFatPercent!, 1)} % жира' : 'BMR · Миффлин',
              fmt(e.bmr),
            ),
            _Metric('TDC без тренировки', fmt(e.tdcRest), active: !p.includeTraining),
            if (p.includeTraining) _Metric('TDC с тренировкой', fmt(e.tdcTraining), active: true),
            _Metric('Цель на день$goal', '${fmt(t.kcal)} ккал', highlight: true),
            _Metric('Белки · ${fmt(p.proteinPerKg, 1)} г/кг', '${fmt(t.protein)} г'),
            _Metric('Жиры · ${fmt(p.fatPercent)} %', '${fmt(t.fat)} г'),
            _Metric('Углеводы', '${fmt(t.carbs)} г'),
          ]),
        ]),
      ),
    );
  }
}

/// Число основных приёмов пищи и перекусов (1–3).
class _MealCountsCard extends ConsumerWidget {
  final RationPlan plan;
  const _MealCountsCard({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(calculationProvider.notifier);
    final mains = plan.mainMealCount;
    final snacks = plan.snackCount;

    Widget counter(String label, String key, int value, void Function(int) onChanged) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 12),
            SegmentedButton<int>(
              key: Key(key),
              showSelectedIcon: false,
              segments: [
                for (var n = mealCountRange.min; n <= mealCountRange.max; n++)
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 32,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Приёмы пищи', style: Theme.of(context).textTheme.titleMedium),
            counter('Основные', 'mainsCount', mains, (n) => notifier.setMealCounts(mains: n, snacks: snacks)),
            counter('Перекусы', 'snacksCount', snacks, (n) => notifier.setMealCounts(mains: mains, snacks: n)),
          ],
        ),
      ),
    );
  }
}

class _MacroWarning extends StatelessWidget {
  const _MacroWarning();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: color),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'С выбранными продуктами не получается точно попасть в белки и жиры — порции подобраны '
            'только по калориям. Добавьте продукты во все группы (белковые, жиры, углеводные), '
            'замените продукты или измените соотношение БЖУ.',
          ),
        ),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final bool highlight;

  const _Metric(this.label, this.value, {this.active = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? theme.colorScheme.primary : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.bodySmall),
      Text(
        value,
        style: theme.textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: highlight || active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ]);
  }
}

class _RationTable extends ConsumerWidget {
  final RationPlan plan;
  final Catalog catalog;

  const _RationTable({required this.plan, required this.catalog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(calculationProvider.notifier);
    final theme = Theme.of(context);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final totalColor = WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest);

    List<DataCell> nutrientCells(Nutrients n, {TextStyle? style}) => [
          DataCell(Text(fmt(n.kcal), style: style)),
          DataCell(Text(fmt(n.protein, 1), style: style)),
          DataCell(Text(fmt(n.fat, 1), style: style)),
          DataCell(Text(fmt(n.carbs, 1), style: style)),
        ];

    final rows = <DataRow>[];
    for (final meal in plan.meals) {
      for (final (i, row) in meal.rows.indexed) {
        rows.add(DataRow(cells: [
          DataCell(Text(i == 0 ? meal.name : '', style: bold)),
          DataCell(_SelectBox(
            width: 290,
            child: DropdownButton<int>(
              value: row.categoryId,
              isExpanded: true,
              isDense: true,
              items: [
                for (final c in catalog.foodCategories)
                  DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (id) {
                if (id != null && id != row.categoryId) notifier.setCategory(row.slotId, id);
              },
            ),
          )),
          DataCell(_SelectBox(
            width: 240,
            // выбранный продукт — с заливкой; пустое место — только рамка
            emphasized: row.food != null,
            borderColor: row.food == null ? theme.colorScheme.primary : null,
            child: DropdownButton<int>(
              value: row.food?.id,
              isExpanded: true,
              isDense: true,
              hint: const Text('— выбрать —'),
              items: [
                for (final f in catalog.foodsOf(row.categoryId))
                  DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (id) {
                final food = catalog.food(id);
                if (food != null) notifier.setFood(row.slotId, food);
              },
            ),
          )),
          DataCell(row.food == null
              ? const Text('—')
              : _GramsField(
                  key: ValueKey('grams-${row.slotId}'),
                  grams: row.grams,
                  manual: row.manual,
                  onChanged: (g) => notifier.setGrams(row.slotId, g),
                )),
          ...nutrientCells(row.nutrients),
          DataCell(row.food == null
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Убрать продукт',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => notifier.clearFood(row.slotId),
                )),
        ]));
      }
      rows.add(DataRow(color: totalColor, cells: [
        const DataCell(Text('')),
        DataCell(Text('Итого за приём', style: bold)),
        const DataCell(Text('')),
        const DataCell(Text('')),
        ...nutrientCells(meal.total, style: bold),
        const DataCell(Text('')),
      ]));
    }

    final total = plan.total;
    final deviation = plan.deviation;
    final headline = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    rows.add(DataRow(color: WidgetStatePropertyAll(theme.colorScheme.primary.withValues(alpha: 0.22)), cells: [
      DataCell(Text('ИТОГО ЗА ДЕНЬ', style: headline)),
      const DataCell(Text('')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      ...nutrientCells(total, style: headline),
      const DataCell(Text('')),
    ]));
    rows.add(DataRow(cells: [
      const DataCell(Text('Цель')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      ...nutrientCells(plan.target),
      const DataCell(Text('')),
    ]));
    // Подсветка: ккал > 1, белки/жиры > 2 г. Углеводы — остаток, расхождение ожидаемо
    // (калорийность продуктов не равна точно 4/9/4 ккал на грамм БЖУ).
    DataCell devCell(double v, int digits, double? limit) {
      final text = fmt(v, digits);
      final isZero = RegExp(r'^0(,0+)?$').hasMatch(text);
      return DataCell(Text(
        v > 0 && !isZero ? '+$text' : text,
        style: TextStyle(color: limit != null && v.abs() > limit ? theme.colorScheme.error : null),
      ));
    }
    rows.add(DataRow(cells: [
      const DataCell(Text('Отклонение')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      devCell(deviation.kcal, 0, 1),
      devCell(deviation.protein, 1, 2),
      devCell(deviation.fat, 1, 2),
      devCell(deviation.carbs, 1, null),
      const DataCell(Text('')),
    ]));

    return DataTable(
      columnSpacing: 16,
      horizontalMargin: 12,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 52,
      border: TableBorder.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      columns: const [
        DataColumn(label: Text('Приём пищи')),
        DataColumn(label: Text('Категория')),
        DataColumn(label: Text('Продукт')),
        DataColumn(label: Text('Порция, г'), numeric: true),
        DataColumn(label: Text('ккал'), numeric: true),
        DataColumn(label: Text('Белки, г'), numeric: true),
        DataColumn(label: Text('Жиры, г'), numeric: true),
        DataColumn(label: Text('Углеводы, г'), numeric: true),
        DataColumn(label: Text('')),
      ],
      rows: rows,
    );
  }
}

/// Ячейка выбора: рамка акцентного цвета; [emphasized] — ещё и заливка
/// (для продуктов, которые подбирает пользователь).
class _SelectBox extends StatelessWidget {
  final Widget child;
  final double width;
  final bool emphasized;
  final Color? borderColor;

  const _SelectBox({required this.child, required this.width, this.emphasized = false, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primary.withValues(alpha: dark ? 0.18 : 0.10) : null,
        border: Border.all(
          color: borderColor ?? (emphasized ? scheme.primary : scheme.outlineVariant),
          width: emphasized ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }
}

/// Поле порции: применяет значение по Enter или при потере фокуса.
class _GramsField extends StatefulWidget {
  final int grams;
  final bool manual;
  final ValueChanged<int> onChanged;

  const _GramsField({super.key, required this.grams, required this.manual, required this.onChanged});

  @override
  State<_GramsField> createState() => _GramsFieldState();
}

class _GramsFieldState extends State<_GramsField> {
  late final _controller = TextEditingController(text: '${widget.grams}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_GramsField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _controller.text != '${widget.grams}') {
      _controller.text = '${widget.grams}';
    }
  }

  void _commit() {
    final v = int.tryParse(_controller.text.trim());
    if (v == null) {
      _controller.text = '${widget.grams}';
    } else if (v != widget.grams) {
      widget.onChanged(v);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tertiary = Theme.of(context).colorScheme.tertiary;
    return _SelectBox(
      width: 92,
      borderColor: widget.manual ? tertiary : null,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.end,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: widget.manual ? TextStyle(color: tertiary, fontWeight: FontWeight.bold) : null,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          // рамку рисует _SelectBox — отключаем рамки темы
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: widget.manual
              ? const Tooltip(message: 'Порция изменена вручную', child: Icon(Icons.edit, size: 14))
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 16),
        ),
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
