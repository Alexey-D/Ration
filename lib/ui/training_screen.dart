import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/energy_calculator.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'activity_picker.dart';
import 'body_fat_screen.dart';
import 'app_logo.dart';
import 'form_widgets.dart';
import 'format.dart';
import 'ration_screen.dart';
import 'theme_toggle.dart';

const _instruction = [
  'Выберите способ расчёта базового обмена (BMR): по формуле Миффлина — Сан Жеора или по проценту жира. '
      'Процент жира можно ввести вручную или рассчитать по складкам (калипер).',
  'Отметьте, учитывать ли тренировку. Без тренировки цель на день = BMR × 1,2.',
  'Калории тренировки задайте одним из способов: выберите вид нагрузки из справочника и укажите длительность '
      'или переключитесь на «Данные браслета» и введите калории, потраченные на тренировке, с фитнес-браслета или часов.',
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
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
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
  late final _minutes = TextEditingController(text: '${widget.initial.trainingMinutes}');
  late final _manualKcal = TextEditingController(text: numText(widget.initial.manualTrainingKcal));
  late final _goal = TextEditingController(text: numText(widget.initial.goalPercent));
  late final _bodyFat = TextEditingController(
    text: widget.initial.bodyFatPercent == null ? '' : numText(widget.initial.bodyFatPercent!),
  );
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_minutes, _manualKcal, _goal, _bodyFat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(Profile Function(Profile) change) => ref.read(profileDraftProvider.notifier).update(change);

  Future<void> _submit(Profile draft, Activity? activity) async {
    final activityMissing =
        draft.includeTraining && draft.trainingMode == TrainingMode.activity && activity == null;
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
    final activity = widget.catalog.activity(p.activityCode);
    final byActivity = p.trainingMode == TrainingMode.activity;
    final energy = calculateEnergy(p, met: activity?.met);
    const gap = SizedBox(height: 16);

    return StepFormLayout(
      instructions: _instruction,
      form: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const StepTitle(step: 3, of: 3, title: 'Рацион: тренировка и цели'),
          const SizedBox(height: 12),

          // ---- Базовый обмен ----
          const FormSection('Базовый обмен (BMR)'),
          SegmentedButton<BmrMethod>(
            segments: const [
              ButtonSegment(value: BmrMethod.mifflin, label: Text('Миффлин — Сан Жеор')),
              ButtonSegment(value: BmrMethod.bodyFat, label: Text('По % жира')),
            ],
            selected: {p.bmrMethod},
            onSelectionChanged: (s) => _update((d) => d.copyWith(bmrMethod: s.first)),
          ),
          if (p.bmrMethod == BmrMethod.bodyFat) ...[
            gap,
            NumberField(
              key: const Key('bodyFatField'),
              controller: _bodyFat,
              label: 'Процент жира в теле',
              suffix: '%',
              min: 3,
              max: 60,
              onValidChanged: (v) => _update((d) => d.copyWith(bodyFatPercent: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BodyFatScreen(returnOnUse: true)),
                ),
                icon: const Icon(Icons.straighten),
                label: const Text('Рассчитать по складкам'),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              energy.bmrMethod == BmrMethod.bodyFat
                  ? 'BMR ${fmt(energy.bmr)} ккал — по ${fmt(p.bodyFatPercent!, 1)} % жира'
                  : 'BMR ${fmt(energy.bmr)} ккал — по формуле Миффлина — Сан Жеора',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),

          // ---- Тренировка ----
          const FormSection('Тренировка'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Учитывать тренировку'),
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
              InkWell(
                key: const Key('activityField'),
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final picked = await ActivityPickerDialog.show(context, widget.catalog, activity);
                  if (picked != null) _update((d) => d.copyWith(activityCode: picked.code));
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
              ),
              gap,
              NumberField(
                controller: _minutes,
                label: 'Длительность тренировки',
                suffix: 'мин',
                min: 0,
                max: 600,
                integer: true,
                onValidChanged: (v) => _update((d) => d.copyWith(trainingMinutes: v.round())),
              ),
            ] else
              NumberField(
                controller: _manualKcal,
                label: 'Калории тренировки',
                suffix: 'ккал',
                min: 0,
                max: 5000,
                helper: 'Потрачено за тренировку по данным фитнес-браслета или часов',
                onValidChanged: (v) => _update((d) => d.copyWith(manualTrainingKcal: v)),
              ),
          ],

          // ---- Цель ----
          const SizedBox(height: 8),
          const FormSection('Цель'),
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

          // ---- БЖУ ----
          const SizedBox(height: 8),
          const FormSection('Соотношение БЖУ'),
          _MacroSlider(
            key: const Key('proteinSlider'),
            label: 'Белки',
            valueText: '${fmt(p.proteinPerKg, 1)} г/кг',
            gramsText: '${fmt(energy.target.protein)} г',
            value: p.proteinPerKg,
            min: proteinPerKgRange.min,
            max: proteinPerKgRange.max,
            divisions: 14,
            onChanged: (v) => _update((d) => d.copyWith(proteinPerKg: (v * 10).round() / 10)),
          ),
          _MacroSlider(
            key: const Key('fatSlider'),
            label: 'Жиры',
            valueText: '${fmt(p.fatPercent)} % калорий',
            gramsText: '${fmt(energy.target.fat)} г',
            value: p.fatPercent,
            min: fatPercentRange.min,
            max: fatPercentRange.max,
            divisions: 20,
            onChanged: (v) => _update((d) => d.copyWith(fatPercent: v.roundToDouble())),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Expanded(child: Text('Углеводы — остаток калорий')),
              Text('${fmt(energy.target.carbs)} г', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),

          // ---- Итог ----
          const SizedBox(height: 20),
          _TargetPreview(energy: energy),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : () => _submit(p, activity),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Рассчитать рацион'),
          ),
        ]),
      ),
    );
  }
}

class _MacroSlider extends StatelessWidget {
  final String label;
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('$label — $valueText')),
        Text(gramsText, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: valueText,
        onChanged: onChanged,
      ),
    ]);
  }
}

/// Цель на день, пересчитывается при каждом изменении формы.
class _TargetPreview extends StatelessWidget {
  final EnergyResult energy;
  const _TargetPreview({required this.energy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = energy.target;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Цель на день', style: theme.textTheme.bodySmall),
          Text(
            '${fmt(t.kcal)} ккал',
            style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Б ${fmt(t.protein)} г  ·  Ж ${fmt(t.fat)} г  ·  У ${fmt(t.carbs)} г'),
        ]),
      ),
    );
  }
}
