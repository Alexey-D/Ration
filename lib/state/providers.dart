import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../data/seed.dart';
import '../domain/energy_calculator.dart';
import '../domain/meal_layout.dart';
import '../domain/models.dart';
import '../domain/ration_plan.dart';

/// Подменяется в main() (SQLite) и в тестах (фейк).
final repositoryProvider = Provider<AppRepository>((ref) => throw UnimplementedError());

final catalogProvider = FutureProvider<Catalog>((ref) => ref.watch(repositoryProvider).loadCatalog());

final savedProfileProvider = FutureProvider<Profile>(
  (ref) async => await ref.watch(repositoryProvider).loadProfile() ?? defaultProfile,
);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Тема: по умолчанию как в системе; выбор пользователя сохраняется в БД.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    ref.read(repositoryProvider).loadSetting(_key).then((saved) {
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null) state = mode;
    }, onError: (_) {});
    return ThemeMode.system;
  }

  /// Переключить на противоположную текущей отображаемой теме.
  void toggle(Brightness current) {
    state = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    ref.read(repositoryProvider).saveSetting(_key, state.name);
  }
}

/// Черновик профиля, общий для двух шагов ввода. Инициализируется сохранённым
/// профилем; поля шагов пишут сюда при каждом изменении.
final profileDraftProvider = NotifierProvider<ProfileDraftNotifier, Profile?>(ProfileDraftNotifier.new);

class ProfileDraftNotifier extends Notifier<Profile?> {
  @override
  Profile? build() => ref.watch(savedProfileProvider).valueOrNull;

  void update(Profile Function(Profile) change) {
    final p = state;
    if (p != null) state = change(p);
  }
}

class Calculation {
  final Profile profile;

  /// Вид нагрузки; null — калории тренировки введены вручную.
  final Activity? activity;
  final EnergyResult energy;
  final RationPlan plan;

  const Calculation({
    required this.profile,
    required this.activity,
    required this.energy,
    required this.plan,
  });

  Calculation withPlan(RationPlan plan) =>
      Calculation(profile: profile, activity: activity, energy: energy, plan: plan);
}

final calculationProvider =
    NotifierProvider<CalculationNotifier, Calculation?>(CalculationNotifier.new);

class CalculationNotifier extends Notifier<Calculation?> {
  @override
  Calculation? build() => null;

  Catalog get _catalog => ref.read(catalogProvider).requireValue;

  /// Расчёт по кнопке «Рассчитать». Если рацион уже есть — сохраняем выбор
  /// продуктов пользователя и только подгоняем порции под новую цель.
  Future<void> calculate(Profile profile) async {
    final activity =
        profile.trainingMode == TrainingMode.activity ? _catalog.activity(profile.activityCode) : null;
    final energy = calculateEnergy(profile, met: activity?.met);
    final previous = state;
    final (mains, snacks) = previous == null ? await _savedMealCounts() : (0, 0);
    state = Calculation(
      profile: profile,
      activity: activity,
      energy: energy,
      plan: previous == null
          ? RationPlan.fromTemplate(_catalog, energy.target, mains: mains, snacks: snacks)
          : previous.plan.withTarget(energy.target),
    );
    await ref.read(repositoryProvider).saveProfile(profile);
  }

  static const _mainsKey = 'ration_main_meals';
  static const _snacksKey = 'ration_snacks';

  Future<(int, int)> _savedMealCounts() async {
    final repo = ref.read(repositoryProvider);
    int read(String? v, int fallback) =>
        (int.tryParse(v ?? '') ?? fallback).clamp(mealCountRange.min, mealCountRange.max);
    return (
      read(await repo.loadSetting(_mainsKey), defaultMainMeals),
      read(await repo.loadSetting(_snacksKey), defaultSnacks),
    );
  }

  /// Число основных приёмов пищи и перекусов (1–3); запоминается для следующих расчётов.
  Future<void> setMealCounts({required int mains, required int snacks}) async {
    _setPlan((p) => p.withMealCounts(_catalog, mains: mains, snacks: snacks));
    final repo = ref.read(repositoryProvider);
    await repo.saveSetting(_mainsKey, '$mains');
    await repo.saveSetting(_snacksKey, '$snacks');
  }

  void _setPlan(RationPlan Function(RationPlan) change) {
    final s = state;
    if (s != null) state = s.withPlan(change(s.plan));
  }

  void setFood(int slotId, Food food) => _setPlan((p) => p.withFood(slotId, food));

  void setCategory(int slotId, int categoryId) =>
      _setPlan((p) => p.withCategory(slotId, categoryId, _catalog.foodsOf(categoryId).firstOrNull));

  void clearFood(int slotId) => _setPlan((p) => p.withoutFood(slotId));

  void setGrams(int slotId, int grams) => _setPlan((p) => p.withGrams(slotId, grams));

  void rebalance() => _setPlan((p) => p.rebalanced());

  void resetToTemplate() => _setPlan((p) => RationPlan.fromTemplate(
        _catalog,
        p.target,
        mains: p.mainMealCount,
        snacks: p.snackCount,
      ));
}
