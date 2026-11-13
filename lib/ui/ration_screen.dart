import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import '../domain/meal_layout.dart';
import '../domain/models.dart';
import '../domain/ration_plan.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'format.dart';
import 'measurement_dialogs.dart';
import 'account_button.dart';
import 'energy_widgets.dart';
import 'palette.dart';

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 30, showTagline: false),
            // на узком экране подзаголовок не помещается рядом с кнопками
            if (MediaQuery.sizeOf(context).width >= 600) ...[
              const SizedBox(width: 16),
              Container(width: 1, height: 28, color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(width: 16),
              const Flexible(child: Text('Рацион на день', overflow: TextOverflow.ellipsis)),
            ],
          ],
        ),
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
          const AppBarActions(),
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
                if (!calc.plan.macrosMatched) ...[const _MacroWarning(), const SizedBox(height: 16)],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _RationTable(plan: calc.plan, catalog: catalog),
                ),
              ],
            ),
    );
  }
}

/// Итоги дня: цель и из чего складывается расход, тренировки, БЖУ —
/// три панели с цветовыми маркерами вместо однотипной сетки чисел.
class _SummaryCard extends ConsumerWidget {
  final Calculation calc;
  const _SummaryCard({required this.calc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final e = calc.energy;
    final p = calc.profile;

    final energyPanel = _Panel(
      icon: Icons.local_fire_department_outlined,
      title: 'Энергия',
      children: [
        TargetHero(kcal: e.target.kcal, goalPercent: p.goalPercent),
        const SizedBox(height: 16),
        EnergyBreakdown(energy: e, profile: p),
      ],
    );
    final trainingPanel = p.includeTraining
        ? _Panel(
            icon: Icons.fitness_center,
            title: 'Тренировки',
            children: [_TrainingList(calc: calc)],
          )
        : null;
    final macroPanel = _Panel(
      icon: Icons.pie_chart_outline,
      title: 'Белки, жиры, углеводы',
      children: [MacroBreakdown(target: e.target, profile: p)],
    );
    final panels = [energyPanel, if (trainingPanel != null) trainingPanel, macroPanel];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Итоги дня', style: theme.textTheme.titleLarge)),
                OutlinedButton.icon(
                  key: const Key('saveRationMeasurement'),
                  onPressed: () => saveMeasurementFlow(
                    context,
                    ref,
                    (date) => measurementFromEnergy(date: date, profile: p, energy: e),
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Сохранить замер'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                const gap = 16.0;
                final columns = c.maxWidth >= 1000 ? panels.length : (c.maxWidth >= 640 ? 2 : 1);
                final width = (c.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [for (final panel in panels) SizedBox(width: width, child: panel)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Панель итогов: заголовок с иконкой и содержимое на нейтральной подложке.
class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Panel({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Palette.of(context).section, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Тренировки дня: каждая — отдельной строкой с названием, MET, длительностью и калориями.
class _TrainingList extends StatelessWidget {
  final Calculation calc;
  const _TrainingList({required this.calc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Palette.of(context).training;
    final e = calc.energy;
    final kcalStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (calc.profile.trainingMode == TrainingMode.manual) {
      return Row(
        children: [
          Icon(Icons.watch_outlined, color: color),
          const SizedBox(width: 12),
          const Expanded(child: Text('Тренировка по данным браслета')),
          Text('${fmt(e.trainingKcal)} ккал', style: kcalStyle),
        ],
      );
    }

    final sessions = e.sessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sessions.length > 1) ...[
          StackedBar(
            segments: [for (final (i, s) in sessions.indexed) BarSegment(s.kcal, color.withValues(alpha: 1 - i * 0.3))],
          ),
          const SizedBox(height: 8),
        ],
        for (final (i, s) in sessions.indexed) ...[
          if (i > 0) const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 1 - i * 0.3),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(calc.activities[i]?.displayName ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'MET ${fmt(s.met ?? 0, 1)} · ${s.session.minutes} мин · ${fmt(s.kcalPerMinute ?? 0, 1)} ккал/мин',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${fmt(s.kcal)} ккал', style: kcalStyle),
            ],
          ),
        ],
      ],
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
            for (var n = mealCountRange.min; n <= mealCountRange.max; n++) ButtonSegment(value: n, label: Text('$n')),
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
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'С выбранными продуктами не получается точно попасть в белки и жиры — порции подобраны '
              'только по калориям. Добавьте продукты во все группы (белковые, жиры, углеводные), '
              'замените продукты или измените соотношение БЖУ.',
            ),
          ),
        ],
      ),
    );
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
        rows.add(
          DataRow(
            cells: [
              DataCell(Text(i == 0 ? meal.name : '', style: bold)),
              DataCell(
                _SelectBox(
                  width: 290,
                  child: DropdownButton<int>(
                    value: row.categoryId,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      for (final c in catalog.foodCategories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null && id != row.categoryId) notifier.setCategory(row.slotId, id);
                    },
                  ),
                ),
              ),
              DataCell(
                _SelectBox(
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
                        DropdownMenuItem(
                          value: f.id,
                          child: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      final food = catalog.food(id);
                      if (food != null) notifier.setFood(row.slotId, food);
                    },
                  ),
                ),
              ),
              DataCell(
                row.food == null
                    ? const Text('—')
                    : _GramsField(
                        key: ValueKey('grams-${row.slotId}'),
                        grams: row.grams,
                        manual: row.manual,
                        onChanged: (g) => notifier.setGrams(row.slotId, g),
                      ),
              ),
              ...nutrientCells(row.nutrients),
              DataCell(
                row.food == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Убрать продукт',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => notifier.clearFood(row.slotId),
                      ),
              ),
            ],
          ),
        );
      }
      rows.add(
        DataRow(
          color: totalColor,
          cells: [
            const DataCell(Text('')),
            DataCell(Text('Итого за приём', style: bold)),
            const DataCell(Text('')),
            const DataCell(Text('')),
            ...nutrientCells(meal.total, style: bold),
            const DataCell(Text('')),
          ],
        ),
      );
    }

    final total = plan.total;
    final deviation = plan.deviation;
    final headline = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    rows.add(
      DataRow(
        color: WidgetStatePropertyAll(theme.colorScheme.primary.withValues(alpha: 0.22)),
        cells: [
          DataCell(Text('ИТОГО ЗА ДЕНЬ', style: headline)),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          ...nutrientCells(total, style: headline),
          const DataCell(Text('')),
        ],
      ),
    );
    rows.add(
      DataRow(
        cells: [
          const DataCell(Text('Цель')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          ...nutrientCells(plan.target),
          const DataCell(Text('')),
        ],
      ),
    );
    // Подсветка: ккал > 1, белки/жиры > 2 г. Углеводы — остаток, расхождение ожидаемо
    // (калорийность продуктов не равна точно 4/9/4 ккал на грамм БЖУ).
    DataCell devCell(double v, int digits, double? limit) {
      final text = fmt(v, digits);
      final isZero = RegExp(r'^0(,0+)?$').hasMatch(text);
      return DataCell(
        Text(
          v > 0 && !isZero ? '+$text' : text,
          style: TextStyle(color: limit != null && v.abs() > limit ? theme.colorScheme.error : null),
        ),
      );
    }

    rows.add(
      DataRow(
        cells: [
          const DataCell(Text('Отклонение')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          devCell(deviation.kcal, 0, 1),
          devCell(deviation.protein, 1, 2),
          devCell(deviation.fat, 1, 2),
          devCell(deviation.carbs, 1, null),
          const DataCell(Text('')),
        ],
      ),
    );

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
