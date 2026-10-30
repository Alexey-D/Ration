import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';

/// Шаблон рациона из «Конструктора рациона»: (категория, продукт, порция, г).
/// Пустое место — продукт null, порция — базовая при добавлении продукта.
const List<(String, List<(String, String?, double)>)> mealTemplateSeed = [
  ('Завтрак', [
    ('grain', 'Гречка варёная', 300.0),
    ('protein', 'Творог 5%', 100.0),
    ('fat', 'Подсолнечное масло', 10.0),
  ]),
  ('Перекус 1', [
    ('snack', 'Финики', 120.0),
    ('protein', null, 100.0),
    ('fat', null, 10.0),
  ]),
  ('Обед', [
    ('grain', 'Макароны варёные', 250.0),
    ('protein', 'Яйцо куриное', 150.0),
    ('fat', 'Сливочное масло 82,5%', 10.0),
  ]),
  ('Перекус 2', [
    ('snack', null, 100.0),
    ('protein', null, 100.0),
    ('fat', null, 10.0),
  ]),
  ('Ужин', [
    ('grain', 'Рис белый варёный', 250.0),
    ('protein', 'Телятина готовая', 150.0),
    ('fat', 'Сливочное масло 82,5%', 10.0),
  ]),
];

const Map<String, String> activityCategoryRu = {
  'Bicycling': 'Велоспорт',
  'Conditioning Exercise': 'Фитнес и общая физподготовка',
  'Dancing': 'Танцы',
  'Fishing & Hunting': 'Рыбалка и охота',
  'Home Activities': 'Домашние дела',
  'Home Repair': 'Ремонт дома',
  'Inactivity': 'Покой',
  'Lawn & Garden': 'Сад и огород',
  'Miscellaneous': 'Разное',
  'Music Playing': 'Игра на музыкальных инструментах',
  'Occupation': 'Профессиональная деятельность',
  'Running': 'Бег',
  'Self Care': 'Уход за собой',
  'Sexual Activity': 'Сексуальная активность',
  'Sports': 'Спорт',
  'Transportation': 'Транспорт',
  'Walking': 'Ходьба',
  'Water Activities': 'Водные виды',
  'Winter Activities': 'Зимние виды',
  'Religious Activities': 'Религиозная деятельность',
  'Volunteer Activities': 'Волонтёрская деятельность',
  'Video Games': 'Видеоигры',
};

/// Профиль по умолчанию — пример из «Калькулятора».
const defaultProfile = Profile(
  sex: Sex.male,
  weightKg: 102,
  heightCm: 178,
  age: 25,
  includeTraining: true,
  trainingMode: TrainingMode.activity,
  activityCode: '02074',
  trainingMinutes: 30,
  manualTrainingKcal: 500,
  goalPercent: 0,
  proteinPerKg: 1.4,
  fatPercent: 20,
);

class FoodSeed {
  final String name;
  final Nutrients per100g;
  const FoodSeed(this.name, this.per100g);
}

class FoodCategorySeed {
  final String key;
  final String name;
  final int sort;
  final List<FoodSeed> foods;
  const FoodCategorySeed(this.key, this.name, this.sort, this.foods);
}

class ActivitySeed {
  final String category;
  final String code;
  final double met;
  final String name;
  final String? nameRu;
  const ActivitySeed(this.category, this.code, this.met, this.name, this.nameRu);
}

class SeedData {
  final List<FoodCategorySeed> foodCategories;
  final List<ActivitySeed> activities;
  const SeedData(this.foodCategories, this.activities);

  static Future<SeedData> fromAssets() async => SeedData.fromJson(
        await rootBundle.loadString('assets/seed/foods.json'),
        await rootBundle.loadString('assets/seed/activities.json'),
        await loadActivityNamesRu(),
      );

  /// Русские названия видов нагрузки: код → название.
  static Future<Map<String, String>> loadActivityNamesRu() async =>
      parseActivityNamesRu(await rootBundle.loadString('assets/seed/activities_ru.json'));

  static Map<String, String> parseActivityNamesRu(String json) =>
      (jsonDecode(json) as Map<String, dynamic>).cast<String, String>();

  factory SeedData.fromJson(String foodsJson, String activitiesJson, [Map<String, String> namesRu = const {}]) {
    double n(Object? v) => (v as num).toDouble();
    final cats = [
      for (final c in jsonDecode(foodsJson) as List)
        FoodCategorySeed(c['key'] as String, c['name'] as String, c['sort'] as int, [
          for (final f in c['foods'] as List)
            FoodSeed(
              f['name'] as String,
              Nutrients(kcal: n(f['kcal']), protein: n(f['protein']), fat: n(f['fat']), carbs: n(f['carbs'])),
            ),
        ]),
    ];
    final acts = [
      for (final a in jsonDecode(activitiesJson) as List)
        ActivitySeed(
          a['category'] as String,
          a['code'] as String,
          n(a['met']),
          a['name'] as String,
          namesRu[a['code']],
        ),
    ];
    return SeedData(cats, acts);
  }
}
