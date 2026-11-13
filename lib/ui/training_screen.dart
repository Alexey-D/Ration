import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/body_composition.dart';
import '../domain/energy_calculator.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'activity_picker.dart';
import 'body_fat_screen.dart';
import 'app_logo.dart';
import 'form_widgets.dart';
import 'format.dart';
import 'ration_screen.dart';
import 'account_button.dart';
import 'energy_widgets.dart';
import 'palette.dart';

const _instruction = [
  'Выберите способ расчёта базового обмена (BMR): по формуле Миффлина — Сан Жеора (рост, масса, возраст) или по формуле Каннингема (по безжировой массе, нужен % жира). '
      'Процент жира можно ввести вручную или рассчитать по складкам (калипер).',
  'Отметьте, учитывать ли тренировку. Без тренировки цель на день = BMR × 1,2.',
  'Калории тренировки задайте одним из способов: выберите число тренировок за день (от 1 до 3), для каждой — вид нагрузки из справочника и длительность '
      'или переключитесь на «Данные браслета» и введите калории, потраченные на тренировках, с фитнес-браслета или часов. Калории всех тренировок складываются.',
  'При необходимости задайте дефицит (например, −10) или профицит (+10) калорий, %.',
  'Настройте соотношение БЖУ: белки — от 0,6 до 2 г на кг массы тела, жиры — от 10 до 30 % калорийности. '
      'Углеводы — оставшиеся калории.',
  'Нажмите «Рассчитать рацион»: порции подберутся так, чтобы итог за день совпал с целью по калориям, белкам и жирам.',
  'В таблице рациона любой продукт можно заменить или поправить его порцию — остальные порции пересчитаются автоматически.',
  'Над таблицей выберите число основных приёмов пищи и перекусов (от 1 до 3) — калории и БЖУ '
      'перераспределятся между приёмами, выбранные продукты сохранятся.',
];

/// Шаг 2 — тренировка, цель, соотношение БЖУ.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final draft = ref.watch(profileDraftProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const AppLogo(size: 30, showTagline: false),
        actions: const [AppBarActions(trailing: 8)],
      ),
      body: catalog == null || draft == null
          ? const Center(child: CircularProgressIndicator())
          : _TrainingForm(catalog: catalog, initial: draft),
    );
  }
}

class _TrainingForm extends ConsumerStatefulWidget {
  final Catalog catalog;
  final Profile initial;
  const _TrainingForm({required this.catalog, required this.initial});

  @override
  ConsumerState<_TrainingForm> createState() => _TrainingFormState();
}

class _TrainingFormState extends ConsumerState<_TrainingForm> {
  final _formKey = GlobalKey<FormState>();

  /// Поля длительности — по одному на каждую возможную тренировку.
  late final _minutes = [
    for (var i = 0; i < trainingCountRange.max; i++)
      TextEditingController(
        text: '${widget.initial.trainings[i.clamp(0, widget.initial.trainings.length - 1)].minutes}',
      ),
  ];
  late final _manualKcal = TextEditingController(text: numText(widget.initial.manualTrainingKcal));
  late final _goal = TextEditingController(text: numText(widget.initial.goalPercent));
  late final _bodyFat = TextEditingController(
    text: widget.initial.bodyFatPercent == null ? '' : numText(widget.initial.bodyFatPercent!),
  );
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [..._minutes, _manualKcal, _goal, _bodyFat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(Profile Function(Profile) change) => ref.read(profileDraftProvider.notifier).update(change);

  void _updateSession(int index, TrainingSession Function(TrainingSession) change) =>
      _update((d) => d.copyWith(trainings: [for (final (i, s) in d.trainings.indexed) i == index ? change(s) : s]));

  /// Новые тренировки — копия последней (вид нагрузки и длительность), их можно поменять.
  void _setTrainingCount(int count) => _update((d) {
    final list = [...d.trainings.take(count)];
    while (list.length < count) {
      list.add(list.last);
      _minutes[list.length - 1].text = '${list.last.minutes}';
    }
    return d.copyWith(trainings: list);
  });

  Future<void> _submit(Profile draft) async {
    final activityMissing =
        draft.includeTraining &&
        draft.trainingMode == TrainingMode.activity &&
        draft.trainings.any((t) => widget.catalog.activity(t.activityCode) == null);
    if (!_formKey.currentState!.validate() || activityMissing) return;
    setState(() => _busy = true);
    try {
      await ref.read(calculationProvider.notifier).calculate(draft);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileDraftProvider)!;
    // % жира мог прийти с экрана калиперометрии — обновляем поле, если оно отстало
    ref.listen(profileDraftProvider.select((d) => d?.bodyFatPercent), (_, next) {
      if (next != null && parseNum(_bodyFat.text) != next) _bodyFat.text = numText(next);
    });
    final theme = Theme.of(context);
    final colors = Palette.of(context);
    final byActivity = p.trainingMode == TrainingMode.activity;
    final energy = calculateEnergy(p, metOf: (code) => widget.catalog.activity(code)?.met);
    const gap = SizedBox(height: 16);
    const sectionGap = SizedBox(height: 16);

    // ---- Базовый обмен ----
    final bmrSection = SectionCard(
      icon: Icons.monitor_heart_outlined,
      title: 'Базовый обмен (BMR)',
      color: colors.bmr,
      trailing: SectionValue('${fmt(energy.bmr)} ккал', color: colors.bmr),
      children: [
        SegmentedButton<BmrMethod>(
          segments: const [
            ButtonSegment(value: BmrMethod.mifflin, label: Text('Миффлин — Сан Жеор')),
            ButtonSegment(value: BmrMethod.bodyFat, label: Text('Каннингем (по % жира)')),
          ],
          selected: {p.bmrMethod},
          onSelectionChanged: (s) => _update((d) => d.copyWith(bmrMethod: s.first)),
        ),
        if (p.bmrMethod == BmrMethod.bodyFat) ...[
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NumberField(
                  key: const Key('bodyFatField'),
                  controller: _bodyFat,
                  label: 'Процент жира в теле',
                  suffix: '%',
                  min: 3,
                  max: 60,
                  onValidChanged: (v) => _update((d) => d.copyWith(bodyFatPercent: v)),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const BodyFatScreen(returnOnUse: true))),
                  icon: const Icon(Icons.straighten),
                  label: const Text('По складкам'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Text(
          energy.bmrMethod == BmrMethod.bodyFat
              ? 'BMR ${fmt(energy.bmr)} ккал — по Каннингему: LBM ${fmt(leanMass(weightKg: p.weightKg, fatPercent: p.bodyFatPercent!), 1)} кг (${fmt(p.bodyFatPercent!, 1)} % жира)'
              : 'BMR ${fmt(energy.bmr)} ккал — по формуле Миффлина — Сан Жеора',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    // ---- Тренировка ----
    final trainingSection = SectionCard(
      icon: Icons.fitness_center,
      title: 'Тренировка',
      color: colors.training,
      trailing: p.includeTraining ? SectionValue('${fmt(energy.trainingKcal)} ккал', color: colors.training) : null,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Учитывать тренировку'),
          subtitle: p.includeTraining ? null : const Text('Цель на день = BMR × 1,2'),
          value: p.includeTraining,
          onChanged: (v) => _update((d) => d.copyWith(includeTraining: v)),
        ),
        if (p.includeTraining) ...[
          const SizedBox(height: 8),
          SegmentedButton<TrainingMode>(
            segments: const [
              ButtonSegment(
                value: TrainingMode.activity,
                label: Text('Вид нагрузки'),
                icon: Icon(Icons.directions_run),
              ),
              ButtonSegment(
                value: TrainingMode.manual,
                label: Text('Данные браслета'),
                icon: Icon(Icons.watch_outlined),
              ),
            ],
            selected: {p.trainingMode},
            onSelectionChanged: (s) => _update((d) => d.copyWith(trainingMode: s.first)),
          ),
          gap,
          if (byActivity) ...[
            Row(
              children: [
                const Expanded(child: Text('Количество тренировок')),
                SegmentedButton<int>(
                  key: const Key('trainingCount'),
                  showSelectedIcon: false,
                  segments: [
                    for (var n = trainingCountRange.min; n <= trainingCountRange.max; n++)
                      ButtonSegment(value: n, label: Text('$n')),
                  ],
                  selected: {p.trainings.length},
                  onSelectionChanged: (s) => _setTrainingCount(s.first),
                ),
              ],
            ),
            if (energy.sessions.length > 1) ...[
              const SizedBox(height: 12),
              StackedBar(
                segments: [
                  for (final (i, s) in energy.sessions.indexed)
                    BarSegment(s.kcal, colors.training.withValues(alpha: 1 - i * 0.3), 'Тренировка ${i + 1}'),
                ],
              ),
            ],
            for (final (i, s) in energy.sessions.indexed) ...[
              gap,
              _SessionCard(
                index: i,
                showHeader: energy.sessions.length > 1,
                kcal: s.kcal,
                color: colors.training.withValues(alpha: 1 - i * 0.3),
                children: [
                  _ActivityField(
                    key: Key('activityField-$i'),
                    catalog: widget.catalog,
                    energy: s,
                    onPicked: (a) => _updateSession(i, (t) => t.copyWith(activityCode: a.code)),
                  ),
                  gap,
                  NumberField(
                    key: Key('minutesField-$i'),
                    controller: _minutes[i],
                    label: 'Длительность тренировки',
                    suffix: 'мин',
                    min: 0,
                    max: 600,
                    integer: true,
                    onValidChanged: (v) => _updateSession(i, (t) => t.copyWith(minutes: v.round())),
                  ),
                ],
              ),
            ],
          ] else
            NumberField(
              controller: _manualKcal,
              label: 'Калории тренировки',
              suffix: 'ккал',
              min: 0,
              max: 5000,
              helper: 'Потрачено за тренировки по данным фитнес-браслета или часов',
              onValidChanged: (v) => _update((d) => d.copyWith(manualTrainingKcal: v)),
            ),
        ],
      ],
    );

    // ---- Цель ----
    final goalSection = SectionCard(
      icon: Icons.flag_outlined,
      title: 'Цель',
      trailing: SectionValue(goalLabel(p.goalPercent), color: theme.colorScheme.primary),
      children: [
        NumberField(
          controller: _goal,
          label: 'Дефицит / профицит',
          suffix: '%',
          min: -50,
          max: 50,
          signed: true,
          helper: '−10 — дефицит, +10 — профицит, 0 — поддержание веса',
          onValidChanged: (v) => _update((d) => d.copyWith(goalPercent: v)),
        ),
      ],
    );

    // ---- БЖУ ----
    final t = energy.target;
    final macroSection = SectionCard(
      icon: Icons.pie_chart_outline,
      title: 'Соотношение БЖУ',
      children: [
        StackedBar(
          segments: [
            BarSegment(t.protein * 4, colors.protein, 'Белки'),
            BarSegment(t.fat * 9, colors.fat, 'Жиры'),
            BarSegment(t.carbs * 4, colors.carbs, 'Углеводы'),
          ],
        ),
        const SizedBox(height: 12),
        _MacroSlider(
          key: const Key('proteinSlider'),
          label: 'Белки',
          color: colors.protein,
          valueText: '${fmt(p.proteinPerKg, 1)} г/кг',
          gramsText: '${fmt(t.protein)} г',
          value: p.proteinPerKg,
          min: proteinPerKgRange.min,
          max: proteinPerKgRange.max,
          divisions: 14,
          onChanged: (v) => _update((d) => d.copyWith(proteinPerKg: (v * 10).round() / 10)),
        ),
        _MacroSlider(
          key: const Key('fatSlider'),
          label: 'Жиры',
          color: colors.fat,
          valueText: '${fmt(p.fatPercent)} % калорий',
          gramsText: '${fmt(t.fat)} г',
          value: p.fatPercent,
          min: fatPercentRange.min,
          max: fatPercentRange.max,
          divisions: 20,
          onChanged: (v) => _update((d) => d.copyWith(fatPercent: v.roundToDouble())),
        ),
        LegendRow(
          color: colors.carbs,
          label: 'Углеводы',
          hint: 'остаток калорий',
          value: '${fmt(t.carbs)} г',
          strong: true,
        ),
      ],
    );

    return Form(
      key: _formKey,
      child: StepFormLayout(
        header: const StepTitle(step: 3, of: 3, title: 'Рацион: тренировка и цели', help: _instruction),
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [bmrSection, sectionGap, goalSection, sectionGap, macroSection],
        ),
        side: trainingSection,
        narrow: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [bmrSection, sectionGap, trainingSection, sectionGap, goalSection, sectionGap, macroSection],
        ),
        bottomBar: _TargetBar(energy: energy, profile: p, busy: _busy, onSubmit: () => _submit(p)),
      ),
    );
  }
}

/// Карточка одной тренировки; при нескольких — с номером и калориями.
class _SessionCard extends StatelessWidget {
  final int index;
  final bool showHeader;
  final double kcal;
  final Color color;
  final List<Widget> children;

  const _SessionCard({
    required this.index,
    required this.showHeader,
    required this.kcal,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!showHeader) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Тренировка ${index + 1}', style: theme.textTheme.titleSmall)),
              Text(
                '${fmt(kcal)} ккал',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Поле выбора вида нагрузки (открывает справочник с поиском).
class _ActivityField extends StatelessWidget {
  final Catalog catalog;
  final SessionEnergy energy;
  final ValueChanged<Activity> onPicked;

  const _ActivityField({super.key, required this.catalog, required this.energy, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final activity = catalog.activity(energy.session.activityCode);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await ActivityPickerDialog.show(context, catalog, activity);
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Вид нагрузки',
          suffixIcon: const Icon(Icons.search),
          helperText: activity == null
              ? null
              : 'MET ${fmt(activity.met, 1)} · ${fmt(energy.kcalPerMinute ?? 0, 2)} ккал/мин',
          errorText: activity == null ? 'Выберите вид нагрузки' : null,
        ),
        child: Text(activity?.displayName ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _MacroSlider extends StatelessWidget {
  final String label;
  final Color color;
  final String valueText;
  final String gramsText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _MacroSlider({
    super.key,
    required this.label,
    required this.color,
    required this.valueText,
    required this.gramsText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Dot(color),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(
              '  ·  $valueText',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(gramsText, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.25),
            valueIndicatorColor: color,
            overlayColor: color.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Закреплённая внизу панель: цель на день (пересчитывается при каждом изменении
/// формы), БЖУ и кнопка расчёта.
class _TargetBar extends StatelessWidget {
  final EnergyResult energy;
  final Profile profile;
  final bool busy;
  final VoidCallback onSubmit;

  const _TargetBar({required this.energy, required this.profile, required this.busy, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(240, 52)),
      onPressed: busy ? null : onSubmit,
      icon: const Icon(Icons.restaurant_menu),
      label: const Text('Рассчитать рацион'),
    );
    final hero = TargetHero(kcal: energy.target.kcal, goalPercent: profile.goalPercent, compact: true);
    final macros = MacroChips(target: energy.target);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 640) {
          return Row(
            children: [
              hero,
              const SizedBox(width: 32),
              Expanded(child: macros),
              const SizedBox(width: 16),
              button,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                hero,
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(padding: const EdgeInsets.only(bottom: 4), child: macros),
                ),
              ],
            ),
            const SizedBox(height: 12),
            button,
          ],
        );
      },
    );
  }
}
