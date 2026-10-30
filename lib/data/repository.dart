import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

abstract class AppRepository {
  Future<Catalog> loadCatalog();
  Future<Profile?> loadProfile();
  Future<void> saveProfile(Profile profile);
  Future<String?> loadSetting(String key);
  Future<void> saveSetting(String key, String value);
}

class SqliteRepository implements AppRepository {
  final Database db;
  SqliteRepository(this.db);

  @override
  Future<Catalog> loadCatalog() async {
    double d(Object? v) => (v as num).toDouble();

    final foodCategories = [
      for (final r in await db.query('food_category', orderBy: 'sort'))
        FoodCategory(id: r['id'] as int, key: r['key'] as String, name: r['name'] as String),
    ];
    final foods = [
      for (final r in await db.query('food', orderBy: 'category_id, id'))
        Food(
          id: r['id'] as int,
          categoryId: r['category_id'] as int,
          name: r['name'] as String,
          per100g: Nutrients(kcal: d(r['kcal']), protein: d(r['protein']), fat: d(r['fat']), carbs: d(r['carbs'])),
        ),
    ];
    final activityCategories = [
      for (final r in await db.query('activity_category', orderBy: 'name_ru'))
        ActivityCategory(id: r['id'] as int, nameEn: r['name_en'] as String, nameRu: r['name_ru'] as String),
    ];
    final activities = [
      for (final r in await db.query('activity', orderBy: 'code'))
        Activity(
          id: r['id'] as int,
          code: r['code'] as String,
          categoryId: r['category_id'] as int,
          met: d(r['met']),
          nameEn: r['name_en'] as String,
          nameRu: r['name_ru'] as String?,
        ),
    ];
    final slotRows = await db.query('meal_slot', orderBy: 'meal_id, sort');
    final meals = [
      for (final m in await db.query('meal', orderBy: 'sort'))
        MealTemplate(id: m['id'] as int, name: m['name'] as String, slots: [
          for (final s in slotRows.where((s) => s['meal_id'] == m['id']))
            SlotTemplate(
              id: s['id'] as int,
              categoryId: s['category_id'] as int,
              defaultFoodId: s['default_food_id'] as int?,
              baseGrams: d(s['base_grams']),
            ),
        ]),
    ];
    return Catalog(
      foodCategories: foodCategories,
      foods: foods,
      activityCategories: activityCategories,
      activities: activities,
      meals: meals,
    );
  }

  @override
  Future<Profile?> loadProfile() async {
    final rows = await db.query('profile', where: 'id = 1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    double d(String column) => (r[column] as num).toDouble();
    return Profile(
      sex: r['sex'] == 'female' ? Sex.female : Sex.male,
      weightKg: d('weight'),
      heightCm: d('height'),
      age: r['age'] as int,
      includeTraining: r['include_training'] == 1,
      trainingMode: r['training_mode'] == TrainingMode.manual.name ? TrainingMode.manual : TrainingMode.activity,
      activityCode: r['activity_code'] as String,
      trainingMinutes: r['training_minutes'] as int,
      manualTrainingKcal: d('manual_training_kcal'),
      goalPercent: d('goal_percent'),
      proteinPerKg: d('protein_per_kg'),
      fatPercent: d('fat_percent'),
      bmrMethod: r['bmr_method'] == BmrMethod.bodyFat.name ? BmrMethod.bodyFat : BmrMethod.mifflin,
      bodyFatPercent: (r['body_fat_percent'] as num?)?.toDouble(),
    );
  }

  @override
  Future<void> saveProfile(Profile p) => db.insert(
        'profile',
        {
          'id': 1,
          'sex': p.sex.name,
          'weight': p.weightKg,
          'height': p.heightCm,
          'age': p.age,
          'include_training': p.includeTraining ? 1 : 0,
          'training_mode': p.trainingMode.name,
          'activity_code': p.activityCode,
          'training_minutes': p.trainingMinutes,
          'manual_training_kcal': p.manualTrainingKcal,
          'goal_percent': p.goalPercent,
          'protein_per_kg': p.proteinPerKg,
          'fat_percent': p.fatPercent,
          'bmr_method': p.bmrMethod.name,
          'body_fat_percent': p.bodyFatPercent,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<String?> loadSetting(String key) async {
    final rows = await db.query('setting', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> saveSetting(String key, String value) =>
      db.insert('setting', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
