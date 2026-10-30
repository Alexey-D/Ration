import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'choice_screen.dart';
import 'form_widgets.dart';
import 'format.dart';
import 'theme_toggle.dart';

const _instruction = [
  'Укажите пол, массу тела, рост и возраст.',
  'По этим данным рассчитывается базовый обмен веществ (BMR) — по формуле Миффлина — Сан Жеора.',
  'Нажмите «Далее» и выберите, что рассчитать: рацион питания или процент подкожного жира.',
];

/// Шаг 1 — антропометрия.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final saved = ref.watch(savedProfileProvider);
    final draft = ref.watch(profileDraftProvider);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compact ? 72 : 96,
        titleSpacing: compact ? 16 : 32,
        title: AppLogo(size: compact ? 34 : 46),
        actions: const [ThemeToggleButton(), SizedBox(width: 16)],
      ),
      body: switch ((catalog, saved, draft)) {
        (AsyncError(:final error), _, _) || (_, AsyncError(:final error), _) =>
          Center(child: Text('Ошибка загрузки данных: $error')),
        (AsyncData(), AsyncData(), final Profile p) => _AnthropometryForm(initial: p),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _AnthropometryForm extends ConsumerStatefulWidget {
  final Profile initial;
  const _AnthropometryForm({required this.initial});

  @override
  ConsumerState<_AnthropometryForm> createState() => _AnthropometryFormState();
}

class _AnthropometryFormState extends ConsumerState<_AnthropometryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _weight = TextEditingController(text: numText(widget.initial.weightKg));
  late final _height = TextEditingController(text: numText(widget.initial.heightCm));
  late final _age = TextEditingController(text: '${widget.initial.age}');
  late Sex _sex = widget.initial.sex;

  @override
  void dispose() {
    for (final c in [_weight, _height, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(profileDraftProvider.notifier).update((p) => p.copyWith(
          sex: _sex,
          weightKg: parseNum(_weight.text),
          heightCm: parseNum(_height.text),
          age: parseNum(_age.text)!.round(),
        ));
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChoiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return StepFormLayout(
      instructions: _instruction,
      form: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const StepTitle(step: 1, of: 3, title: 'Антропометрия'),
          const SizedBox(height: 20),
          SegmentedButton<Sex>(
            segments: const [
              ButtonSegment(value: Sex.male, label: Text('Мужской'), icon: Icon(Icons.male)),
              ButtonSegment(value: Sex.female, label: Text('Женский'), icon: Icon(Icons.female)),
            ],
            selected: {_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.first),
          ),
          gap,
          NumberField(controller: _weight, label: 'Масса тела', suffix: 'кг', min: 30, max: 300),
          gap,
          NumberField(controller: _height, label: 'Рост', suffix: 'см', min: 100, max: 250),
          gap,
          NumberField(controller: _age, label: 'Возраст', suffix: 'лет', min: 14, max: 100, integer: true),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _next,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Далее'),
          ),
        ]),
      ),
    );
  }
}
