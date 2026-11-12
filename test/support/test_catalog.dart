import 'dart:io';

import 'package:ration_planner/data/password_hasher.dart';
import 'package:ration_planner/data/repository.dart';
import 'package:ration_planner/domain/account.dart';
import 'package:ration_planner/data/seed.dart';
import 'package:ration_planner/domain/models.dart';

/// Справочник в памяти из тех же seed-файлов и шаблона, что и БД.
/// Справочники из assets/seed (как при первом запуске приложения).
SeedData loadTestSeed() => SeedData.fromJson(
      File('assets/seed/foods.json').readAsStringSync(),
      File('assets/seed/activities.json').readAsStringSync(),
      SeedData.parseActivityNamesRu(File('assets/seed/activities_ru.json').readAsStringSync()),
    );

Catalog buildTestCatalog() {
  final seed = loadTestSeed();
  var id = 0;
  final categories = <FoodCategory>[];
  final foods = <Food>[];
  final foodByKeyName = <String, Food>{};
  for (final c in seed.foodCategories) {
    final cat = FoodCategory(id: ++id, key: c.key, name: c.name);
    categories.add(cat);
    for (final f in c.foods) {
      final food = Food(id: ++id, categoryId: cat.id, name: f.name, per100g: f.per100g);
      foods.add(food);
      foodByKeyName['${c.key}/${f.name}'] = food;
    }
  }
  final actCats = <String, ActivityCategory>{};
  final activities = [
    for (final a in seed.activities)
      Activity(
        id: ++id,
        code: a.code,
        categoryId: (actCats[a.category] ??=
                ActivityCategory(id: ++id, nameEn: a.category, nameRu: activityCategoryRu[a.category] ?? a.category))
            .id,
        met: a.met,
        nameEn: a.name,
        nameRu: a.nameRu,
      ),
  ];
  final catByKey = {for (final c in categories) c.key: c};
  final meals = [
    for (final (name, slots) in mealTemplateSeed)
      MealTemplate(id: ++id, name: name, slots: [
        for (final (key, foodName, grams) in slots)
          SlotTemplate(
            id: ++id,
            categoryId: catByKey[key]!.id,
            defaultFoodId: foodName == null ? null : foodByKeyName['$key/$foodName']!.id,
            baseGrams: grams,
          ),
      ]),
  ];
  return Catalog(
    foodCategories: categories,
    foods: foods,
    activityCategories: actCats.values.toList(),
    activities: activities,
    meals: meals,
  );
}

/// Репозиторий в памяти. По умолчанию уже есть вошедший пользователь «test»
/// (пароль «test»; хэш — от [testHasher]).
class FakeRepository implements AppRepository {
  final Catalog catalog;
  FakeRepository(this.catalog, {bool signedIn = true}) {
    if (signedIn) {
      users.add((AppUser(id: 1, login: 'test', name: 'Тест', createdAt: DateTime(2026, 1, 1)), testHasher.hash('test')));
      settings['session_user_id'] = '1';
    }
  }

  final users = <(AppUser, String)>[];
  final profiles = <int, Profile>{};
  final measurements = <int, List<Measurement>>{};
  final settings = <String, String>{};
  var _nextId = 100;

  /// Профиль первого пользователя (для проверок в тестах).
  Profile? get saved => profiles[1];

  @override
  Future<Catalog> loadCatalog() async => catalog;

  @override
  Future<AppUser?> userById(int id) async => users.where((u) => u.$1.id == id).firstOrNull?.$1;

  @override
  Future<(AppUser, String)?> credentials(String login) async =>
      users.where((u) => u.$1.login.toLowerCase() == login.trim().toLowerCase()).firstOrNull;

  @override
  Future<AppUser> createUser({required String login, required String name, required String passwordHash}) async {
    if (await credentials(login) != null) throw LoginTakenException(login);
    final user = AppUser(id: _nextId++, login: login.trim(), name: name.trim(), createdAt: DateTime.now());
    users.add((user, passwordHash));
    return user;
  }

  @override
  Future<Profile?> loadProfile(int userId) async => profiles[userId];

  @override
  Future<void> saveProfile(int userId, Profile profile) async => profiles[userId] = profile;

  @override
  Future<List<Measurement>> loadMeasurements(int userId) async =>
      [...?measurements[userId]]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<Measurement> saveMeasurement(int userId, Measurement m) async {
    final list = measurements.putIfAbsent(userId, () => []);
    final i = m.id != null ? list.indexWhere((x) => x.id == m.id) : list.indexWhere((x) => x.date == m.date);
    final saved = i < 0
        ? m.mergedWith(Measurement(id: _nextId++, date: m.date))
        : (m.id != null ? m : list[i].mergedWith(m));
    if (i < 0) {
      list.add(saved);
    } else {
      list[i] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteMeasurement(int userId, int id) async => measurements[userId]?.removeWhere((m) => m.id == id);

  @override
  Future<String?> loadSetting(String key) async => settings[key];

  @override
  Future<void> saveSetting(String key, String value) async => settings[key] = value;

  @override
  Future<void> deleteSetting(String key) async => settings.remove(key);
}

/// Быстрое хэширование для тестов.
const testHasher = PasswordHasher(iterations: 2);
