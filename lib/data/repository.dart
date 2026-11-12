import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/account.dart';
import '../domain/body_composition.dart';
import '../domain/models.dart';

/// Логин уже занят другим пользователем.
class LoginTakenException implements Exception {
  final String login;
  const LoginTakenException(this.login);
}

abstract class AppRepository {
  Future<Catalog> loadCatalog();

  // ---- Учётные записи ----
  Future<AppUser?> userById(int id);

  /// Пользователь и хэш его пароля; null — логин не найден.
  Future<(AppUser, String)?> credentials(String login);

  /// Создаёт пользователя; [LoginTakenException], если логин занят.
  Future<AppUser> createUser({required String login, required String name, required String passwordHash});

  // ---- Данные пользователя ----
  Future<Profile?> loadProfile(int userId);
  Future<void> saveProfile(int userId, Profile profile);

  /// Замеры по возрастанию даты.
  Future<List<Measurement>> loadMeasurements(int userId);

  /// Новый замер ([Measurement.id] == null) объединяется с замером за ту же дату,
  /// если он есть; замер с id заменяет сохранённый.
  Future<Measurement> saveMeasurement(int userId, Measurement m);
  Future<void> deleteMeasurement(int userId, int id);

  // ---- Настройки приложения ----
  Future<String?> loadSetting(String key);
  Future<void> saveSetting(String key, String value);
  Future<void> deleteSetting(String key);
}

/// Тренировки в столбце profile.trainings: «код:минуты;код:минуты».
String encodeTrainings(List<TrainingSession> trainings) =>
    trainings.map((t) => '${t.activityCode}:${t.minutes}').join(';');

/// null — пустое или испорченное значение (тогда берётся activity_code / training_minutes).
List<TrainingSession>? decodeTrainings(String? value) {
  if (value == null || value.isEmpty) return null;
  final result = <TrainingSession>[];
  for (final part in value.split(';')) {
    final i = part.lastIndexOf(':');
    final minutes = i < 1 ? null : int.tryParse(part.substring(i + 1));
    if (minutes == null) return null;
    result.add(TrainingSession(activityCode: part.substring(0, i), minutes: minutes));
  }
  return result.take(trainingCountRange.max).toList();
}

/// Дата в БД: ГГГГ-ММ-ДД.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Object?> measurementToRow(int userId, Measurement m) => {
      if (m.id != null) 'id': m.id,
      'user_id': userId,
      'date': isoDate(m.date),
      'weight': m.weightKg,
      'height': m.heightCm,
      'age': m.age,
      'body_fat_percent': m.bodyFatPercent,
      'fat_kg': m.fatKg,
      'lean_kg': m.leanKg,
      'muscle_kg': m.muscleKg,
      'skinfolds': m.skinfolds.isEmpty ? null : jsonEncode({for (final e in m.skinfolds.entries) e.key.name: e.value}),
      'girths': m.girths.isEmpty ? null : jsonEncode({for (final e in m.girths.entries) e.key.name: e.value}),
      'bmr': m.bmr,
      'bmr_method': m.bmr == null ? null : m.bmrMethod?.name,
      'tdc': m.tdc,
      'target_kcal': m.target?.kcal,
      'target_protein': m.target?.protein,
      'target_fat': m.target?.fat,
      'target_carbs': m.target?.carbs,
      'note': m.note,
    };

Measurement measurementFromRow(Map<String, Object?> r) {
  double? d(String column) => (r[column] as num?)?.toDouble();
  Map<E, double> decode<E extends Enum>(String column, List<E> values) {
    final json = r[column] as String?;
    if (json == null) return {};
    final map = jsonDecode(json) as Map<String, dynamic>;
    return {
      for (final e in values)
        if (map[e.name] is num) e: (map[e.name] as num).toDouble(),
    };
  }

  final kcal = d('target_kcal');
  return Measurement(
    id: r['id'] as int?,
    date: DateTime.parse(r['date'] as String),
    weightKg: d('weight'),
    heightCm: d('height'),
    age: r['age'] as int?,
    bodyFatPercent: d('body_fat_percent'),
    fatKg: d('fat_kg'),
    leanKg: d('lean_kg'),
    muscleKg: d('muscle_kg'),
    skinfolds: decode('skinfolds', Skinfold.values),
    girths: decode('girths', Girth.values),
    bmr: d('bmr'),
    bmrMethod: BmrMethod.values.where((m) => m.name == r['bmr_method']).firstOrNull,
    tdc: d('tdc'),
    target: kcal == null
        ? null
        : Nutrients(
            kcal: kcal,
            protein: d('target_protein') ?? 0,
            fat: d('target_fat') ?? 0,
            carbs: d('target_carbs') ?? 0,
          ),
    note: r['note'] as String?,
  );
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

  // ---- Учётные записи ----

  AppUser _user(Map<String, Object?> r) => AppUser(
        id: r['id'] as int,
        login: r['login'] as String,
        name: r['name'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  @override
  Future<AppUser?> userById(int id) async {
    final rows = await db.query('user', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _user(rows.first);
  }

  @override
  Future<(AppUser, String)?> credentials(String login) async {
    final rows = await db.query('user', where: 'login = ?', whereArgs: [login.trim()]);
    return rows.isEmpty ? null : (_user(rows.first), rows.first['password_hash'] as String);
  }

  @override
  Future<AppUser> createUser({required String login, required String name, required String passwordHash}) async {
    final createdAt = DateTime.now();
    final int id;
    try {
      id = await db.insert('user', {
        'login': login.trim(),
        'name': name.trim(),
        'password_hash': passwordHash,
        'created_at': createdAt.toIso8601String(),
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw LoginTakenException(login);
      rethrow;
    }
    // первый пользователь получает профиль, сохранённый до появления учётных записей
    if (Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user')) == 1) {
      final legacy = await db.query('sqlite_master', where: "type = 'table' AND name = 'profile'");
      if (legacy.isNotEmpty) {
        final rows = await db.query('profile', where: 'id = 1');
        if (rows.isNotEmpty) await saveProfile(id, _profile(rows.first));
      }
    }
    return AppUser(id: id, login: login.trim(), name: name.trim(), createdAt: createdAt);
  }

  // ---- Профиль ----

  Profile _profile(Map<String, Object?> r) {
    double d(String column) => (r[column] as num).toDouble();
    return Profile(
      sex: r['sex'] == 'female' ? Sex.female : Sex.male,
      weightKg: d('weight'),
      heightCm: d('height'),
      age: r['age'] as int,
      includeTraining: r['include_training'] == 1,
      trainingMode: r['training_mode'] == TrainingMode.manual.name ? TrainingMode.manual : TrainingMode.activity,
      trainings: decodeTrainings(r['trainings'] as String?) ??
          [TrainingSession(activityCode: r['activity_code'] as String, minutes: r['training_minutes'] as int)],
      manualTrainingKcal: d('manual_training_kcal'),
      goalPercent: d('goal_percent'),
      proteinPerKg: d('protein_per_kg'),
      fatPercent: d('fat_percent'),
      bmrMethod: r['bmr_method'] == BmrMethod.bodyFat.name ? BmrMethod.bodyFat : BmrMethod.mifflin,
      bodyFatPercent: (r['body_fat_percent'] as num?)?.toDouble(),
    );
  }

  @override
  Future<Profile?> loadProfile(int userId) async {
    final rows = await db.query('user_profile', where: 'user_id = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : _profile(rows.first);
  }

  @override
  Future<void> saveProfile(int userId, Profile p) => db.insert(
        'user_profile',
        {
          'user_id': userId,
          'sex': p.sex.name,
          'weight': p.weightKg,
          'height': p.heightCm,
          'age': p.age,
          'include_training': p.includeTraining ? 1 : 0,
          'training_mode': p.trainingMode.name,
          'activity_code': p.trainings.first.activityCode,
          'training_minutes': p.trainings.first.minutes,
          'trainings': encodeTrainings(p.trainings),
          'manual_training_kcal': p.manualTrainingKcal,
          'goal_percent': p.goalPercent,
          'protein_per_kg': p.proteinPerKg,
          'fat_percent': p.fatPercent,
          'bmr_method': p.bmrMethod.name,
          'body_fat_percent': p.bodyFatPercent,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // ---- Замеры ----

  @override
  Future<List<Measurement>> loadMeasurements(int userId) async => [
        for (final r in await db.query('measurement', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date'))
          measurementFromRow(r),
      ];

  @override
  Future<Measurement> saveMeasurement(int userId, Measurement m) => db.transaction((txn) async {
        if (m.id != null) {
          await txn.update('measurement', measurementToRow(userId, m),
              where: 'id = ? AND user_id = ?', whereArgs: [m.id, userId]);
          return m;
        }
        final existing = await txn.query('measurement',
            where: 'user_id = ? AND date = ?', whereArgs: [userId, isoDate(m.date)]);
        if (existing.isEmpty) {
          final row = measurementToRow(userId, m);
          return measurementFromRow({...row, 'id': await txn.insert('measurement', row)});
        }
        final merged = measurementFromRow(existing.first).mergedWith(m);
        await txn.update('measurement', measurementToRow(userId, merged), where: 'id = ?', whereArgs: [merged.id]);
        return merged;
      });

  @override
  Future<void> deleteMeasurement(int userId, int id) =>
      db.delete('measurement', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);

  // ---- Настройки ----

  @override
  Future<String?> loadSetting(String key) async {
    final rows = await db.query('setting', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> saveSetting(String key, String value) =>
      db.insert('setting', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> deleteSetting(String key) => db.delete('setting', where: 'key = ?', whereArgs: [key]);
}
