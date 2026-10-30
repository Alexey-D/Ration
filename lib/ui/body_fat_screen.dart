import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/body_composition.dart';
import '../domain/energy_calculator.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'form_widgets.dart';
import 'format.dart';
import 'theme_toggle.dart';
import 'training_screen.dart';

const _instruction = [
  'Измерьте калипером толщину кожно-жировых складок в указанных точках, мм. '
      'У женщин складка на груди не измеряется.',
  'Каждую складку измерьте 2–3 раза и введите среднее. Замеры делайте на одной и той же стороне тела '
      'и в одинаковых условиях — так результаты можно сравнивать между собой.',
  'Для расчёта мышечной массы дополнительно введите обхваты бедра, голени и плеча, см (необязательно).',
  'Результаты пересчитываются сразу при вводе.',
  'Кнопка «Использовать в расчёте рациона» перенесёт процент жира в рацион: '
      'базовый обмен будет считаться по проценту жира.',
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
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : StepFormLayout(instructions: _instruction, form: _BodyFatForm(profile: p, returnOnUse: returnOnUse)),
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

  /// Результат, если все складки введены корректно; обхваты — по желанию (нужны все три).
  BodyCompositionResult? _result(Profile p) {
    final sites = skinfoldsFor(p.sex);
    final folds = <Skinfold, double>{};
    for (final s in sites) {
      final v = _value(_folds[s]!, _foldRange);
      if (v == null) return null;
      folds[s] = v;
    }
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
    ref.read(profileDraftProvider.notifier).update((d) => d.copyWith(
          bmrMethod: BmrMethod.bodyFat,
          bodyFatPercent: (r.fatPercent * 10).round() / 10,
        ));
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

    Widget field(TextEditingController c, String label, String suffix, ({double min, double max}) range) =>
        NumberField(
          key: Key('field-$label'),
          controller: c,
          label: label,
          suffix: suffix,
          min: range.min,
          max: range.max,
        );

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StepTitle(step: 3, of: 3, title: 'Процент подкожного жира'),
        const SizedBox(height: 4),
        Text(
          '${p.sex == Sex.male ? 'Мужчина, 8 складок' : 'Женщина, 7 складок'} · '
          '${numText(p.weightKg)} кг · ${numText(p.heightCm)} см · ${p.age} лет',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        const FormSection('Кожно-жировые складки, мм'),
        _TwoColumns(children: [for (final s in sites) field(_folds[s]!, s.label, 'мм', _foldRange)]),
        const SizedBox(height: 8),
        const FormSection('Обхваты, см — для мышечной массы'),
        _TwoColumns(children: [
          field(_thigh, 'Обхват бедра', 'см', _girthRange),
          field(_calf, 'Обхват голени', 'см', _girthRange),
          field(_arm, 'Обхват плеча', 'см', _girthRange),
        ]),
        const SizedBox(height: 20),
        if (result == null)
          Text(
            'Введите все ${sites.length} складок, чтобы увидеть результат.',
            style: Theme.of(context).textTheme.bodyMedium,
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
        ],
      ]),
    );
  }
}

/// Поля в две колонки; на очень узком экране — в одну.
class _TwoColumns extends StatelessWidget {
  final List<Widget> children;
  const _TwoColumns({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      final width = c.maxWidth < 360 ? c.maxWidth : (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final w in children) SizedBox(width: width, child: w)],
      );
    });
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

    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label)),
            Text(value, style: strong ? const TextStyle(fontWeight: FontWeight.bold) : null),
          ]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Процент жира', style: theme.textTheme.bodySmall),
          Text(
            '${fmt(r.fatPercent, 1)} %',
            key: const Key('fatPercent'),
            style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Divider(),
          row('Масса жира', '${fmt(r.fatKg, 1)} кг', strong: true),
          row('Безжировая масса (LBM)', '${fmt(r.leanKg, 1)} кг', strong: true),
          row('Мышечная масса (МСМ)', r.muscleKg == null ? 'введите обхваты' : '${fmt(r.muscleKg!, 1)} кг',
              strong: r.muscleKg != null),
          const Divider(),
          row('Сумма складок', '${fmt(r.skinfoldSum, 1)} мм'),
          row('Средняя полутолщина складки', '${fmt(r.meanHalfSkinfold, 2)} мм'),
          row('Площадь поверхности тела', '${fmt(r.bodySurfaceArea, 2)} м²'),
          const Divider(),
          row('Коэффициент по % жира', fmt(r.leanFactor, 2)),
          row('BMR по % жира', '${fmt(r.bmr)} ккал', strong: true),
          row('BMR по Миффлину — Сан Жеору', '${fmt(mifflin)} ккал'),
        ]),
      ),
    );
  }
}
