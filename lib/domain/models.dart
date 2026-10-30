enum Sex { male, female }

/// КБЖУ. Для продукта — на 100 г, для строки рациона — на порцию.
class Nutrients {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const Nutrients({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  static const zero = Nutrients(kcal: 0, protein: 0, fat: 0, carbs: 0);

  Nutrients operator +(Nutrients o) => Nutrients(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        fat: fat + o.fat,
        carbs: carbs + o.carbs,
      );

  Nutrients operator -(Nutrients o) => Nutrients(
        kcal: kcal - o.kcal,
        protein: protein - o.protein,
        fat: fat - o.fat,
        carbs: carbs - o.carbs,
      );

  /// Значения на [grams] граммов, если this — значения на 100 г.
  Nutrients forGrams(num grams) => Nutrients(
        kcal: kcal * grams / 100,
        protein: protein * grams / 100,
        fat: fat * grams / 100,
        carbs: carbs * grams / 100,
      );
}

class FoodCategory {
  final int id;
  final String key;
  final String name;

  const FoodCategory({required this.id, required this.key, required this.name});

  /// Группа для подгонки БЖУ: белковые, жиры, остальное — углеводные.
  MacroGroup get macroGroup => switch (key) {
        'protein' => MacroGroup.protein,
        'fat' => MacroGroup.fat,
        _ => MacroGroup.carbs,
      };
}

/// Группы продуктов, порции которых масштабируются при подгонке под БЖУ.
enum MacroGroup { protein, fat, carbs }

class Food {
  final int id;
  final int categoryId;
  final String name;
  final Nutrients per100g;

  const Food({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.per100g,
  });
}

class ActivityCategory {
  final int id;
  final String nameEn;
  final String nameRu;

  const ActivityCategory({required this.id, required this.nameEn, required this.nameRu});
}

class Activity {
  final int id;
  final String code;
  final int categoryId;
  final double met;
  final String nameEn;
  final String? nameRu;

  const Activity({
    required this.id,
    required this.code,
    required this.categoryId,
    required this.met,
    required this.nameEn,
    this.nameRu,
  });

  String get displayName => nameRu ?? nameEn;
}

/// Место под продукт в приёме пищи (строка шаблона рациона).
class SlotTemplate {
  final int id;
  final int categoryId;
  final int? defaultFoodId;

  /// Порция в шаблоне. Для пустых мест — порция, с которой продукт
  /// «входит» в рацион при добавлении.
  final double baseGrams;

  const SlotTemplate({
    required this.id,
    required this.categoryId,
    required this.defaultFoodId,
    required this.baseGrams,
  });
}

class MealTemplate {
  final int id;
  final String name;
  final List<SlotTemplate> slots;

  const MealTemplate({required this.id, required this.name, required this.slots});

  /// Перекус или основной приём пищи (по названию шаблона: «Перекус …»).
  bool get isSnack => name.startsWith('Перекус');
}

/// Как задаются калории тренировки.
enum TrainingMode {
  /// Вид нагрузки из справочника (MET) × длительность.
  activity,

  /// Калории тренировки введены вручную (фитнес-браслет, часы).
  manual,
}

/// Способ расчёта базового обмена.
enum BmrMethod {
  /// Миффлин — Сан Жеор (рост, масса, возраст, пол).
  mifflin,

  /// По проценту жира: масса × 24 × коэффициент пола × коэффициент по % жира.
  bodyFat,
}

/// Диапазоны настроек БЖУ.
const proteinPerKgRange = (min: 0.6, max: 2.0);
const fatPercentRange = (min: 10.0, max: 30.0);

/// Параметры, которые вводит пользователь.
class Profile {
  // Шаг 1 — антропометрия
  final Sex sex;
  final double weightKg;
  final double heightCm;
  final int age;

  // Шаг 2 — тренировка, цель, БЖУ
  final bool includeTraining;
  final TrainingMode trainingMode;
  final String activityCode;
  final int trainingMinutes;

  /// Калории тренировки по данным браслета (режим [TrainingMode.manual]).
  final double manualTrainingKcal;

  /// Дефицит (<0) или профицит (>0) калорий, %.
  final double goalPercent;

  /// Белки, г на кг массы тела.
  final double proteinPerKg;

  /// Жиры, % от калорийности.
  final double fatPercent;

  final BmrMethod bmrMethod;

  /// Процент жира в теле (калиперометрия или ввод вручную); нужен для [BmrMethod.bodyFat].
  final double? bodyFatPercent;

  const Profile({
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.includeTraining,
    required this.trainingMode,
    required this.activityCode,
    required this.trainingMinutes,
    required this.manualTrainingKcal,
    required this.goalPercent,
    required this.proteinPerKg,
    required this.fatPercent,
    this.bmrMethod = BmrMethod.mifflin,
    this.bodyFatPercent,
  });

  Profile copyWith({
    Sex? sex,
    double? weightKg,
    double? heightCm,
    int? age,
    bool? includeTraining,
    TrainingMode? trainingMode,
    String? activityCode,
    int? trainingMinutes,
    double? manualTrainingKcal,
    double? goalPercent,
    double? proteinPerKg,
    double? fatPercent,
    BmrMethod? bmrMethod,
    double? bodyFatPercent,
  }) =>
      Profile(
        sex: sex ?? this.sex,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        age: age ?? this.age,
        includeTraining: includeTraining ?? this.includeTraining,
        trainingMode: trainingMode ?? this.trainingMode,
        activityCode: activityCode ?? this.activityCode,
        trainingMinutes: trainingMinutes ?? this.trainingMinutes,
        manualTrainingKcal: manualTrainingKcal ?? this.manualTrainingKcal,
        goalPercent: goalPercent ?? this.goalPercent,
        proteinPerKg: proteinPerKg ?? this.proteinPerKg,
        fatPercent: fatPercent ?? this.fatPercent,
        bmrMethod: bmrMethod ?? this.bmrMethod,
        bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      );
}

/// Справочники целиком — они небольшие, держим в памяти.
class Catalog {
  final List<FoodCategory> foodCategories;
  final List<Food> foods;
  final List<ActivityCategory> activityCategories;
  final List<Activity> activities;
  final List<MealTemplate> meals;

  Catalog({
    required this.foodCategories,
    required this.foods,
    required this.activityCategories,
    required this.activities,
    required this.meals,
  })  : _foodById = {for (final f in foods) f.id: f},
        _categoryById = {for (final c in foodCategories) c.id: c},
        _activityByCode = {for (final a in activities) a.code: a};

  final Map<int, Food> _foodById;
  final Map<int, FoodCategory> _categoryById;
  final Map<String, Activity> _activityByCode;

  Food? food(int? id) => id == null ? null : _foodById[id];
  FoodCategory category(int id) => _categoryById[id]!;
  Activity? activity(String code) => _activityByCode[code];

  List<Food> foodsOf(int categoryId) =>
      foods.where((f) => f.categoryId == categoryId).toList();
}
