import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import '../domain/body_composition.dart';
import '../domain/energy_calculator.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'form_widgets.dart';
import 'format.dart';
import 'measurement_dialogs.dart';
import 'account_button.dart';
import 'training_screen.dart';
import 'energy_widgets.dart';
import 'palette.dart';

const _instruction = [
  'Измерьте калипером толщину кожно-жировых складок в указанных точках, мм. '
      'У женщин складка на груди не измеряется.',
  'Каждую складку измерьте 2–3 раза и введите среднее. Замеры делайте на одной и той же стороне тела '
      'и в одинаковых условиях — так результаты можно сравнивать между собой.',
  'Для расчёта мышечной массы дополнительно введите обхваты бедра, голени и плеча, см (необязательно).',
  'Результаты пересчитываются сразу при вводе.',
  'Кнопка «Использовать в расчёте рациона» перенесёт процент жира в рацион: '
      'базовый обмен будет считаться по Каннингему (по безжировой массе).',
  'Кнопка «Сохранить замер» добавит складки, % жира, LBM и обхваты в историю — динамика видна в личном кабинете.',
];

const _foldRange = (min: 1.0, max: 100.0);
const _girthRange = (min: 10.0, max: 150.0);

/// Шаг 3 — процент подкожного жира (калиперометрия).
class BodyFatScreen extends ConsumerWidget {
  /// true — экран открыт из расчёта рациона: «Использовать» возвращает назад,
  /// иначе открывает расчёт рациона вместо этого экрана.
  final bool returnOnUse;

  const BodyFatScreen({super.key, this.returnOnUse = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileDraftProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const AppLogo(size: 30, showTagline: false),
        actions: const [AppBarActions(trailing: 8)],
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : _BodyFatForm(profile: p, returnOnUse: returnOnUse),
    );
  }
}

class _BodyFatForm extends ConsumerStatefulWidget {
  final Profile profile;
  final bool returnOnUse;
  const _BodyFatForm({required this.profile, required this.returnOnUse});

  @override
  ConsumerState<_BodyFatForm> createState() => _BodyFatFormState();
}

class _BodyFatFormState extends ConsumerState<_BodyFatForm> {
  final _folds = {for (final s in Skinfold.values) s: TextEditingController()};
  final _thigh = TextEditingController();
  final _calf = TextEditingController();
  final _arm = TextEditingController();

  Iterable<TextEditingController> get _all => [..._folds.values, _thigh, _calf, _arm];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  double? _value(TextEditingController c, ({double min, double max}) range) {
    final v = parseNum(c.text);
    return v == null || v < range.min || v > range.max ? null : v;
  }

  /// Складки, если все введены корректно.
  Map<Skinfold, double>? _foldValues(Profile p) {
    final folds = <Skinfold, double>{};
    for (final s in skinfoldsFor(p.sex)) {
      final v = _value(_folds[s]!, _foldRange);
      if (v == null) return null;
      folds[s] = v;
    }
    return folds;
  }

  /// Введённые обхваты (любые из трёх).
  Map<Girth, double> _girthValues() => {
    if (_value(_thigh, _girthRange) case final v?) Girth.thigh: v,
    if (_value(_calf, _girthRange) case final v?) Girth.calf: v,
    if (_value(_arm, _girthRange) case final v?) Girth.arm: v,
  };

  /// Результат, если все складки введены корректно; обхваты — по желанию (нужны все три).
  BodyCompositionResult? _result(Profile p) {
    final folds = _foldValues(p);
    if (folds == null) return null;
    final thigh = _value(_thigh, _girthRange);
    final calf = _value(_calf, _girthRange);
    final arm = _value(_arm, _girthRange);
    return calculateBodyComposition(
      sex: p.sex,
      weightKg: p.weightKg,
      heightCm: p.heightCm,
      age: p.age,
      folds: folds,
      girths: thigh != null && calf != null && arm != null ? Girths(thigh: thigh, calf: calf, arm: arm) : null,
    );
  }

  void _useInRation(BodyCompositionResult r) {
    ref
        .read(profileDraftProvider.notifier)
        .update((d) => d.copyWith(bmrMethod: BmrMethod.bodyFat, bodyFatPercent: (r.fatPercent * 10).round() / 10));
    if (widget.returnOnUse) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TrainingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final sites = skinfoldsFor(p.sex);
    final result = _result(p);

    Widget field(TextEditingController c, String label, String suffix, ({double min, double max}) range, {bool required = true}) => NumberField(
      key: Key('field-$label'),
      controller: c,
      label: label,
      suffix: suffix,
      min: range.min,
      max: range.max,
      required: required,
    );

    final theme = Theme.of(context);
    final filled = sites.where((s) => parseNum(_folds[s]!.text) != null).length;
    final girthsFilled = [_thigh, _calf, _arm].where((c) => parseNum(c.text) != null).length;

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: StepFormLayout(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepTitle(step: 3, of: 3, title: 'Процент подкожного жира', help: _instruction),
            const SizedBox(height: 4),
            Text(
              '${p.sex == Sex.male ? 'Мужчина, 8 складок' : 'Женщина, 7 складок'} · '
              '${numText(p.weightKg)} кг · ${numText(p.heightCm)} см · ${p.age} лет',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              icon: Icons.pinch_outlined,
              title: 'Кожно-жировые складки, мм',
              trailing: SectionValue(
                '$filled из ${sites.length}',
                color: filled == sites.length ? theme.colorScheme.primary : null,
              ),
              children: [
                _TwoColumns(children: [for (final s in sites) field(_folds[s]!, s.label, 'мм', _foldRange)]),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              icon: Icons.straighten,
              title: 'Обхваты, см',
              trailing: SectionValue('$girthsFilled из 3', color: girthsFilled == 3 ? theme.colorScheme.primary : null),
              children: [
                Text('Необязательно — нужны для расчёта мышечной массы', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                _TwoColumns(
                  children: [
                    field(_thigh, 'Обхват бедра', 'см', _girthRange, required: false),
                    field(_calf, 'Обхват голени', 'см', _girthRange, required: false),
                    field(_arm, 'Обхват плеча', 'см', _girthRange, required: false),
                  ],
                ),
              ],
            ),
          ],
        ),
        side: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result == null)
              SectionCard(
                icon: Icons.analytics_outlined,
                title: 'Результат',
                children: [
                  Text(
                    'Введите все ${sites.length} складок, чтобы увидеть результат.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: filled / sites.length, borderRadius: BorderRadius.circular(4)),
                ],
              )
            else ...[
              _ResultCard(result: result, profile: p),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => _useInRation(result),
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Использовать в расчёте рациона'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('saveBodyFatMeasurement'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => saveMeasurementFlow(
                  context,
                  ref,
                  (date) => Measurement.fromBodyComposition(
                    date: date,
                    profile: p,
                    result: result,
                    skinfolds: _foldValues(p)!,
                    girths: _girthValues(),
                  ),
                ),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Сохранить замер'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Поля в две колонки; на очень узком экране — в одну.
class _TwoColumns extends StatelessWidget {
  final List<Widget> children;
  const _TwoColumns({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        final width = c.maxWidth < 360 ? c.maxWidth : (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final w in children) SizedBox(width: width, child: w)],
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final BodyCompositionResult result;
  final Profile profile;

  const _ResultCard({required this.result, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final mifflin = bmr(sex: profile.sex, weightKg: profile.weightKg, heightCm: profile.heightCm, age: profile.age);
    final colors = Palette.of(context);

    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: strong ? const TextStyle(fontWeight: FontWeight.bold) : null),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Процент жира', style: theme.textTheme.bodySmall),
            Text(
              '${fmt(r.fatPercent, 1)} %',
              key: const Key('fatPercent'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            StackedBar(
              height: 12,
              segments: [
                BarSegment(r.fatKg, colors.training, 'Жир'),
                BarSegment(r.leanKg, colors.bmr, 'Безжировая масса'),
              ],
            ),
            const SizedBox(height: 8),
            LegendRow(color: colors.training, label: 'Масса жира', value: '${fmt(r.fatKg, 1)} кг', strong: true),
            LegendRow(
              color: colors.bmr,
              label: 'Безжировая масса (LBM)',
              value: '${fmt(r.leanKg, 1)} кг',
              strong: true,
            ),
            LegendRow(
              label: 'Мышечная масса (МСМ)',
              hint: r.muscleKg == null ? 'нужны все три обхвата' : 'входит в LBM',
              value: r.muscleKg == null ? 'введите обхваты' : '${fmt(r.muscleKg!, 1)} кг',
              strong: r.muscleKg != null,
            ),
            const Divider(height: 24),
            _caption(context, Icons.monitor_heart_outlined, 'Базовый обмен'),
            row('По Каннингему (500 + 22 × LBM)', '${fmt(r.bmr)} ккал', strong: true),
            row('По Миффлину — Сан Жеору', '${fmt(mifflin)} ккал'),
            const Divider(height: 24),
            _caption(context, Icons.info_outline, 'Промежуточные значения'),
            row('Сумма складок', '${fmt(r.skinfoldSum, 1)} мм'),
            row('Средняя полутолщина складки', '${fmt(r.meanHalfSkinfold, 2)} мм'),
            row('Площадь поверхности тела', '${fmt(r.bodySurfaceArea, 2)} м²'),
          ],
        ),
      ),
    );
  }
}

Widget _caption(BuildContext context, IconData icon, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
      ],
    ),
  );
}
