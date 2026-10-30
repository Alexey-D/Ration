import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/body_composition.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'body_fat_screen.dart';
import 'form_widgets.dart';
import 'format.dart';
import 'theme_toggle.dart';
import 'training_screen.dart';

const _instruction = [
  'Выберите, что рассчитать по введённым росту, массе и возрасту.',
  '«Рацион питания» — суточная норма калорий с учётом тренировки, соотношение БЖУ и подбор порций.',
  '«Процент подкожного жира» — состав тела по толщине кожно-жировых складок (калипер): '
      'процент и масса жира, безжировая и мышечная масса, BMR по проценту жира.',
  'Результат калиперометрии можно перенести в расчёт рациона — тогда базовый обмен будет '
      'считаться по проценту жира.',
];

/// Шаг 2 — выбор расчёта.
class ChoiceScreen extends ConsumerWidget {
  const ChoiceScreen({super.key});

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
          : StepFormLayout(
              instructions: _instruction,
              form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const StepTitle(step: 2, of: 3, title: 'Что рассчитать?'),
                const SizedBox(height: 8),
                Text(
                  '${p.sex == Sex.male ? 'Мужчина' : 'Женщина'} · ${numText(p.weightKg)} кг · '
                  '${fmt(p.heightCm)} см · ${p.age} лет · '
                  'площадь тела ${fmt(bodySurfaceArea(heightCm: p.heightCm, weightKg: p.weightKg), 2)} м²',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                _OptionCard(
                  icon: Icons.restaurant_menu,
                  title: 'Рацион питания',
                  subtitle: 'Норма калорий с учётом тренировки, БЖУ и подбор порций на 5 приёмов пищи',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingScreen())),
                ),
                const SizedBox(height: 12),
                _OptionCard(
                  icon: Icons.straighten,
                  title: 'Процент подкожного жира',
                  subtitle: 'Калиперометрия: % и масса жира, безжировая и мышечная масса, BMR по % жира',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BodyFatScreen())),
                ),
              ]),
            ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ]),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.primary),
          ]),
        ),
      ),
    );
  }
}
