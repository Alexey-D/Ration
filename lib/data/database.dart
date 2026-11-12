import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'seed.dart';

const _schemaVersion = 6;

final _schema = [
  '''CREATE TABLE food_category (
       id INTEGER PRIMARY KEY,
       key TEXT NOT NULL UNIQUE,
       name TEXT NOT NULL,
       sort INTEGER NOT NULL)''',
  '''CREATE TABLE food (
       id INTEGER PRIMARY KEY,
       category_id INTEGER NOT NULL REFERENCES food_category(id),
       name TEXT NOT NULL,
       kcal REAL NOT NULL,
       protein REAL NOT NULL,
       fat REAL NOT NULL,
       carbs REAL NOT NULL,
       is_user INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE activity_category (
       id INTEGER PRIMARY KEY,
       name_en TEXT NOT NULL UNIQUE,
       name_ru TEXT NOT NULL)''',
  '''CREATE TABLE activity (
       id INTEGER PRIMARY KEY,
       code TEXT NOT NULL UNIQUE,
       category_id INTEGER NOT NULL REFERENCES activity_category(id),
       met REAL NOT NULL,
       name_en TEXT NOT NULL,
       name_ru TEXT)''',
  '''CREATE TABLE meal (
       id INTEGER PRIMARY KEY,
       name TEXT NOT NULL,
       sort INTEGER NOT NULL)''',
  '''CREATE TABLE meal_slot (
       id INTEGER PRIMARY KEY,
       meal_id INTEGER NOT NULL REFERENCES meal(id),
       sort INTEGER NOT NULL,
       category_id INTEGER NOT NULL REFERENCES food_category(id),
       default_food_id INTEGER REFERENCES food(id),
       base_grams REAL NOT NULL)''',
  _settingTable,
  ..._accountTables,
];

// v2: настройки приложения (тема и т.п.)
const _settingTable = '''CREATE TABLE setting (
       key TEXT PRIMARY KEY,
       value TEXT NOT NULL)''';

// v3: режим тренировки (справочник / браслет) и настройки БЖУ
const _profileV3Columns = [
  "training_mode TEXT NOT NULL DEFAULT 'activity'",
  'manual_training_kcal REAL NOT NULL DEFAULT 500',
  'protein_per_kg REAL NOT NULL DEFAULT 1.4',
  'fat_percent REAL NOT NULL DEFAULT 20',
];

// v4: способ расчёта BMR и процент жира (калиперометрия)
const _profileV4Columns = [
  "bmr_method TEXT NOT NULL DEFAULT 'mifflin'",
  'body_fat_percent REAL',
];

// Столбцы профиля пользователя (кроме ключа).
const _profileColumns = [
  'sex TEXT NOT NULL',
  'weight REAL NOT NULL',
  'height REAL NOT NULL',
  'age INTEGER NOT NULL',
  'activity_code TEXT NOT NULL',
  'training_minutes INTEGER NOT NULL',
  'include_training INTEGER NOT NULL',
  'goal_percent REAL NOT NULL',
];

// v6: учётные записи, профиль каждого пользователя, история замеров.
// Старая таблица profile (один профиль на приложение) остаётся только в обновлённых
// БД: её данные переносятся первому зарегистрированному пользователю.
final _accountTables = [
  '''CREATE TABLE user (
       id INTEGER PRIMARY KEY,
       login TEXT NOT NULL UNIQUE COLLATE NOCASE,
       name TEXT NOT NULL,
       password_hash TEXT NOT NULL,
       created_at TEXT NOT NULL)''',
  '''CREATE TABLE user_profile (
       user_id INTEGER PRIMARY KEY REFERENCES user(id) ON DELETE CASCADE,
       ${[..._profileColumns, ..._profileV3Columns, ..._profileV4Columns, ..._profileV5Columns].join(', ')})''',
  '''CREATE TABLE measurement (
       id INTEGER PRIMARY KEY,
       user_id INTEGER NOT NULL REFERENCES user(id) ON DELETE CASCADE,
       date TEXT NOT NULL,
       weight REAL,
       height REAL,
       age INTEGER,
       body_fat_percent REAL,
       fat_kg REAL,
       lean_kg REAL,
       muscle_kg REAL,
       skinfolds TEXT,
       girths TEXT,
       bmr REAL,
       bmr_method TEXT,
       tdc REAL,
       target_kcal REAL,
       target_protein REAL,
       target_fat REAL,
       target_carbs REAL,
       note TEXT,
       UNIQUE (user_id, date))''',
];

// v5: до 3 тренировок в день — «код:минуты;код:минуты». Первая дублируется
// в activity_code / training_minutes.
const _profileV5Columns = [
  'trainings TEXT',
];

/// Открывает БД приложения; при первом запуске создаёт схему и
/// заполняет справочники из assets/seed.
Future<Database> openAppDatabase() async {
  final DatabaseFactory factory =
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ? _ffiFactory() : databaseFactory;
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return openAppDatabaseAt(factory, p.join(dir.path, 'ration_planner.db'));
}

/// Открывает (создаёт или обновляет) БД по пути; [loadSeed] — справочники для заливки.
Future<Database> openAppDatabaseAt(
  DatabaseFactory factory,
  String path, {
  Future<SeedData> Function() loadSeed = SeedData.fromAssets,
}) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: _schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        final seed = await loadSeed();
        await db.transaction((txn) async {
          for (final sql in _schema) {
            await txn.execute(sql);
          }
          await insertSeed(txn, seed);
        });
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await db.execute(_settingTable);
        if (oldVersion < 3) {
          final seed = await loadSeed();
          await db.transaction((txn) async {
            for (final column in _profileV3Columns) {
              await txn.execute('ALTER TABLE profile ADD COLUMN $column');
            }
            // русские названия + записи, восстановленные из склеенной строки 19405
            await syncActivities(txn, seed);
          });
        }
        if (oldVersion < 4) {
          for (final column in _profileV4Columns) {
            await db.execute('ALTER TABLE profile ADD COLUMN $column');
          }
        }
        if (oldVersion < 5) {
          for (final column in _profileV5Columns) {
            await db.execute('ALTER TABLE profile ADD COLUMN $column');
          }
          await db.execute("UPDATE profile SET trainings = activity_code || ':' || training_minutes");
        }
        if (oldVersion < 6) {
          await db.transaction((txn) async {
            for (final sql in _accountTables) {
              await txn.execute(sql);
            }
          });
        }
      },
    ),
  );
}

DatabaseFactory _ffiFactory() {
  ffi.sqfliteFfiInit();
  return ffi.databaseFactoryFfi;
}

Future<void> insertSeed(DatabaseExecutor db, SeedData seed) async {
  final foodIds = <String, Map<String, int>>{}; // ключ категории -> имя -> id
  final categoryIds = <String, int>{};

  for (final c in seed.foodCategories) {
    final catId = await db.insert('food_category', {'key': c.key, 'name': c.name, 'sort': c.sort});
    categoryIds[c.key] = catId;
    final ids = foodIds[c.key] = {};
    for (final f in c.foods) {
      ids[f.name] = await db.insert('food', {
        'category_id': catId,
        'name': f.name,
        'kcal': f.per100g.kcal,
        'protein': f.per100g.protein,
        'fat': f.per100g.fat,
        'carbs': f.per100g.carbs,
      });
    }
  }

  await syncActivities(db, seed);

  var mealSort = 0;
  for (final (mealName, slots) in mealTemplateSeed) {
    final mealId = await db.insert('meal', {'name': mealName, 'sort': mealSort++});
    var slotSort = 0;
    for (final (catKey, foodName, grams) in slots) {
      await db.insert('meal_slot', {
        'meal_id': mealId,
        'sort': slotSort++,
        'category_id': categoryIds[catKey]!,
        'default_food_id': foodName == null ? null : foodIds[catKey]![foodName]!,
        'base_grams': grams,
      });
    }
  }
}

/// Добавляет недостающие и обновляет существующие (по коду) виды нагрузки и их категории.
Future<void> syncActivities(DatabaseExecutor db, SeedData seed) async {
  final categoryIds = {
    for (final r in await db.query('activity_category')) r['name_en'] as String: r['id'] as int,
  };
  final batch = db.batch();
  for (final a in seed.activities) {
    final catId = categoryIds[a.category] ??= await db.insert('activity_category', {
      'name_en': a.category,
      'name_ru': activityCategoryRu[a.category] ?? a.category,
    });
    batch.rawInsert(
      '''INSERT INTO activity (code, category_id, met, name_en, name_ru) VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(code) DO UPDATE SET
           category_id = excluded.category_id, met = excluded.met,
           name_en = excluded.name_en, name_ru = excluded.name_ru''',
      [a.code, catId, a.met, a.name, a.nameRu],
    );
  }
  await batch.commit(noResult: true);
}
