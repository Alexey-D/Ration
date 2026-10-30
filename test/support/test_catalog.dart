import 'dart:io';

import 'package:ration_planner/data/repository.dart';
import 'package:ration_planner/data/seed.dart';
import 'package:ration_planner/domain/models.dart';

/// Справочник в памяти из тех же seed-файлов и шаблона, что и БД.
Catalog buildTestCatalog() {
  final seed = SeedData.fromJson(
    File('assets/seed/foods.json').readAsStringSync(),
    File('assets/seed/activities.json').readAsStringSync(),
    SeedData.parseActivityNamesRu(File('assets/seed/activities_ru.json').readAsStringSync()),
  );
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

class FakeRepository implements AppRepository {
  final Catalog catalog;
  Profile? saved;
  FakeRepository(this.catalog);

  @override
  Future<Catalog> loadCatalog() async => catalog;

  @override
  Future<Profile?> loadProfile() async => saved;

  @override
  Future<void> saveProfile(Profile profile) async => saved = profile;

  final settings = <String, String>{};

  @override
  Future<String?> loadSetting(String key) async => settings[key];

  @override
  Future<void> saveSetting(String key, String value) async => settings[key] = value;
}
