import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/password_hasher.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../domain/account.dart';
import '../domain/energy_calculator.dart';
import '../domain/meal_layout.dart';
import '../domain/models.dart';
import '../domain/ration_plan.dart';

/// Подменяется в main() (SQLite) и в тестах (фейк).
final repositoryProvider = Provider<AppRepository>((ref) => throw UnimplementedError());

final catalogProvider = FutureProvider<Catalog>((ref) => ref.watch(repositoryProvider).loadCatalog());

/// Хэширование паролей; в тестах подменяется на быстрое (меньше итераций).
final passwordHasherProvider = Provider<PasswordHasher>((ref) => const PasswordHasher());

/// Вошедший пользователь; null — нужен вход. Сессия запоминается до «Выйти».
final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AppUser?> {
  static const _sessionKey = 'session_user_id';

  AppRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<AppUser?> build() async {
    final id = int.tryParse(await _repo.loadSetting(_sessionKey) ?? '');
    return id == null ? null : _repo.userById(id);
  }

  /// null — вход выполнен, иначе текст ошибки.
  Future<String?> login(String login, String password) async {
    final found = await _repo.credentials(login);
    if (found == null || !ref.read(passwordHasherProvider).verify(password, found.$2)) {
      return 'Неверный логин или пароль';
    }
    await _start(found.$1);
    return null;
  }

  /// null — пользователь создан и вошёл, иначе текст ошибки.
  Future<String?> register({required String login, required String name, required String password}) async {
    final error = validateLogin(login) ?? validatePassword(password);
    if (error != null) return error;
    try {
      final user = await _repo.createUser(
        login: login,
        name: name.trim().isEmpty ? login.trim() : name,
        passwordHash: ref.read(passwordHasherProvider).hash(password),
      );
      await _start(user);
      return null;
    } on LoginTakenException {
      return 'Логин «${login.trim()}» уже занят';
    }
  }

  Future<void> logout() async {
    await _repo.deleteSetting(_sessionKey);
    state = const AsyncData(null);
  }

  Future<void> _start(AppUser user) async {
    await _repo.saveSetting(_sessionKey, '${user.id}');
    state = AsyncData(user);
  }
}

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authProvider).valueOrNull);

/// Сохранённый профиль текущего пользователя (у нового — профиль по умолчанию).
final savedProfileProvider = FutureProvider<Profile>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return defaultProfile;
  return await ref.watch(repositoryProvider).loadProfile(user.id) ?? defaultProfile;
});

/// История замеров текущего пользователя (по возрастанию даты).
final measurementsProvider =
    AsyncNotifierProvider<MeasurementsNotifier, List<Measurement>>(MeasurementsNotifier.new);

class MeasurementsNotifier extends AsyncNotifier<List<Measurement>> {
  @override
  Future<List<Measurement>> build() async {
    final user = ref.watch(currentUserProvider);
    return user == null ? const [] : ref.read(repositoryProvider).loadMeasurements(user.id);
  }

  /// Новый замер объединяется с замером за ту же дату; возвращает сохранённый замер.
  Future<Measurement> save(Measurement m) async {
    final user = ref.read(currentUserProvider)!;
    final repo = ref.read(repositoryProvider);
    final saved = await repo.saveMeasurement(user.id, m);
    state = AsyncData(await repo.loadMeasurements(user.id));
    return saved;
  }

  Future<void> delete(int id) async {
    final user = ref.read(currentUserProvider)!;
    final repo = ref.read(repositoryProvider);
    await repo.deleteMeasurement(user.id, id);
    state = AsyncData(await repo.loadMeasurements(user.id));
  }
}

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

  /// Виды нагрузки тренировок (по порядку [EnergyResult.sessions]); пусто — данные браслета.
  final List<Activity?> activities;
  final EnergyResult energy;
  final RationPlan plan;

  const Calculation({
    required this.profile,
    required this.activities,
    required this.energy,
    required this.plan,
  });

  Calculation withPlan(RationPlan plan) =>
      Calculation(profile: profile, activities: activities, energy: energy, plan: plan);
}

final calculationProvider =
    NotifierProvider<CalculationNotifier, Calculation?>(CalculationNotifier.new);

class CalculationNotifier extends Notifier<Calculation?> {
  @override
  Calculation? build() {
    ref.watch(currentUserProvider); // другой пользователь — расчёт сбрасывается
    return null;
  }

  Catalog get _catalog => ref.read(catalogProvider).requireValue;

  /// Расчёт по кнопке «Рассчитать». Если рацион уже есть — сохраняем выбор
  /// продуктов пользователя и только подгоняем порции под новую цель.
  Future<void> calculate(Profile profile) async {
    final energy = calculateEnergy(profile, metOf: (code) => _catalog.activity(code)?.met);
    final previous = state;
    final (mains, snacks) = previous == null ? await _savedMealCounts() : (0, 0);
    state = Calculation(
      profile: profile,
      activities: [for (final s in energy.sessions) _catalog.activity(s.session.activityCode)],
      energy: energy,
      plan: previous == null
          ? RationPlan.fromTemplate(_catalog, energy.target, mains: mains, snacks: snacks)
          : previous.plan.withTarget(energy.target),
    );
    final user = ref.read(currentUserProvider);
    if (user != null) await ref.read(repositoryProvider).saveProfile(user.id, profile);
  }

  /// Настройки числа приёмов — свои у каждого пользователя.
  String get _userPrefix => 'user:${ref.read(currentUserProvider)?.id ?? 0}:';
  String get _mainsKey => '${_userPrefix}ration_main_meals';
  String get _snacksKey => '${_userPrefix}ration_snacks';

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
