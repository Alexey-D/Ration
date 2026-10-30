import 'meal_layout.dart';
import 'models.dart';

/// Строка рациона: место в приёме пищи + выбранный продукт + порция.
class RationRow {
  final int slotId;
  final int categoryId;
  final Food? food;

  /// Вес строки при делении цели (ккал строки в шаблоне).
  /// Калории делятся между строками пропорционально весам.
  final double weight;
  final double baseGrams;
  final int grams;

  /// Порция задана вручную — фиксирована, остальные строки подстраиваются.
  final bool manual;

  const RationRow({
    required this.slotId,
    required this.categoryId,
    required this.food,
    required this.weight,
    required this.baseGrams,
    required this.grams,
    this.manual = false,
  });

  Nutrients get nutrients => food == null ? Nutrients.zero : food!.per100g.forGrams(grams);

  RationRow copyWith({
    int? categoryId,
    Food? food,
    bool clearFood = false,
    double? weight,
    int? grams,
    bool? manual,
  }) =>
      RationRow(
        slotId: slotId,
        categoryId: categoryId ?? this.categoryId,
        food: clearFood ? null : (food ?? this.food),
        weight: weight ?? this.weight,
        baseGrams: baseGrams,
        grams: grams ?? this.grams,
        manual: manual ?? this.manual,
      );
}

class RationMeal {
  /// id шаблона приёма пищи — по нему приём находится при смене числа приёмов.
  final int id;
  final String name;
  final bool isSnack;
  final List<RationRow> rows;

  const RationMeal({required this.id, required this.name, required this.isSnack, required this.rows});

  factory RationMeal.fromTemplate(MealTemplate m, Catalog catalog) => RationMeal(
        id: m.id,
        name: m.name,
        isSnack: m.isSnack,
        rows: [
          for (final s in m.slots)
            () {
              final food = catalog.food(s.defaultFoodId);
              return RationRow(
                slotId: s.id,
                categoryId: s.categoryId,
                food: food,
                weight: food == null ? 0 : food.per100g.kcal * s.baseGrams / 100,
                baseGrams: s.baseGrams,
                grams: 0,
              );
            }(),
        ],
      );

  RationMeal withRows(List<RationRow> rows) => RationMeal(id: id, name: name, isSnack: isSnack, rows: rows);

  Nutrients get total => rows.fold(Nutrients.zero, (s, r) => s + r.nutrients);
}

/// Рацион на день. Неизменяемый: каждое действие возвращает новый план.
///
/// Подбор порций:
/// 1. калории цели делятся между строками пропорционально весам (долям из шаблона);
/// 2. порции каждой группы продуктов (белковые / жиры / углеводные) умножаются на свой
///    коэффициент так, чтобы итог по ккал, белкам и жирам совпал с целью
///    (углеводы — остаток). Если точного неотрицательного решения нет —
///    остаётся шаг 1 (только калории), [macrosMatched] = false;
/// 3. округление до 1 г; погрешность по калориям собирается в строку
///    с наименее калорийным продуктом.
/// Ручные порции фиксированы — остальные строки подстраиваются под цель.
class RationPlan {
  final Nutrients target;
  final List<RationMeal> meals;

  /// Удалось ли точно попасть в белки и жиры.
  final bool macrosMatched;

  final Map<int, MacroGroup> _groups;

  const RationPlan._(this.target, this.meals, this.macrosMatched, this._groups);

  factory RationPlan.fromTemplate(
    Catalog catalog,
    Nutrients target, {
    int mains = defaultMainMeals,
    int snacks = defaultSnacks,
  }) {
    final meals = [
      for (final m in mealLayout(catalog.meals, mains: mains, snacks: snacks)) RationMeal.fromTemplate(m, catalog),
    ];
    final groups = {for (final c in catalog.foodCategories) c.id: c.macroGroup};
    return _build(target, meals, groups);
  }

  int get mainMealCount => meals.where((m) => !m.isSnack).length;
  int get snackCount => meals.where((m) => m.isSnack).length;

  /// Другое число основных приёмов и перекусов. Приёмы, которые остаются,
  /// сохраняют выбранные продукты и ручные порции; новые берутся из шаблона.
  RationPlan withMealCounts(Catalog catalog, {required int mains, required int snacks}) {
    final existing = {for (final m in meals) m.id: m};
    final layout = mealLayout(catalog.meals, mains: mains, snacks: snacks);
    return _build(
      target,
      [
        for (final t in layout)
          existing[t.id] == null
              ? RationMeal.fromTemplate(t, catalog)
              : RationMeal(id: t.id, name: t.name, isSnack: t.isSnack, rows: existing[t.id]!.rows),
      ],
      _groups,
    );
  }

  static RationPlan _build(Nutrients target, List<RationMeal> meals, Map<int, MacroGroup> groups) {
    final (allocated, matched) = _allocate(meals, target, groups);
    return RationPlan._(target, allocated, matched, groups);
  }

  Nutrients get total => meals.fold(Nutrients.zero, (s, m) => s + m.total);

  /// Отклонение итога от цели по ккал и БЖУ.
  Nutrients get deviation => total - target;

  RationRow row(int slotId) =>
      meals.expand((m) => m.rows).firstWhere((r) => r.slotId == slotId);

  RationPlan withTarget(Nutrients target) => _build(target, meals, _groups);

  /// Замена продукта: доля строки в калориях сохраняется.
  /// Если строка была пустой — продукт входит с базовой порцией шаблона,
  /// доли остальных строк пропорционально уменьшаются.
  RationPlan withFood(int slotId, Food food) => _update(slotId, (r) {
        final weight = r.food == null ? food.per100g.kcal * r.baseGrams / 100 : r.weight;
        return r.copyWith(food: food, categoryId: food.categoryId, weight: weight, manual: false);
      });

  /// Смена категории строки; продукт — первый из новой категории.
  RationPlan withCategory(int slotId, int categoryId, Food? firstFood) {
    if (firstFood == null) {
      return _update(slotId, (r) => r.copyWith(categoryId: categoryId, clearFood: true, weight: 0, manual: false));
    }
    return withFood(slotId, firstFood);
  }

  /// Убрать продукт: доли остальных строк пропорционально растут.
  RationPlan withoutFood(int slotId) =>
      _update(slotId, (r) => r.copyWith(clearFood: true, weight: 0, grams: 0, manual: false));

  /// Ручная порция: фиксируется, остальные строки подстраиваются под цель.
  RationPlan withGrams(int slotId, int grams) =>
      _update(slotId, (r) => r.copyWith(grams: grams < 0 ? 0 : grams, manual: true));

  /// Сбросить ручные правки и подобрать все порции заново.
  RationPlan rebalanced() => _build(
        target,
        [
          for (final m in meals)
            m.withRows([for (final r in m.rows) r.copyWith(manual: false)]),
        ],
        _groups,
      );

  RationPlan _update(int slotId, RationRow Function(RationRow) change) => _build(
        target,
        [
          for (final m in meals)
            m.withRows([
              for (final r in m.rows) r.slotId == slotId ? change(r) : r,
            ]),
        ],
        _groups,
      );

  static (List<RationMeal>, bool) _allocate(
    List<RationMeal> meals,
    Nutrients target,
    Map<int, MacroGroup> groups,
  ) {
    bool isAuto(RationRow r) => r.food != null && !r.manual && r.food!.per100g.kcal > 0;
    MacroGroup groupOf(RationRow r) => groups[r.categoryId] ?? MacroGroup.carbs;

    final rows = meals.expand((m) => m.rows).toList();
    final autos = rows.where(isAuto).toList();
    final fixed = rows.where((r) => r.manual && r.food != null).fold(Nutrients.zero, (s, r) => s + r.nutrients);
    final remaining = target - fixed;
    final totalWeight = autos.fold<double>(0, (s, r) => s + r.weight);

    // 1. порции по долям калорий
    final exact = <int, double>{
      for (final r in autos)
        r.slotId: totalWeight <= 0 || remaining.kcal <= 0
            ? 0
            : remaining.kcal * r.weight / totalWeight / r.food!.per100g.kcal * 100,
    };

    // 2. подгонка БЖУ коэффициентами групп
    final groupSums = <MacroGroup, Nutrients>{};
    for (final r in autos) {
      final n = r.food!.per100g.forGrams(exact[r.slotId]!);
      groupSums[groupOf(r)] = (groupSums[groupOf(r)] ?? Nutrients.zero) + n;
    }
    final scales = _solveGroupScales(groupSums, remaining);
    if (scales != null) {
      for (final r in autos) {
        exact[r.slotId] = exact[r.slotId]! * scales[groupOf(r)]!;
      }
    }

    // 3. округление; погрешность по ккал — в строку с наименее калорийным продуктом
    var residualKcal = 0.0;
    RationRow? balancer;
    for (final r in autos) {
      final g = exact[r.slotId]!;
      residualKcal += (g - g.round()) * r.food!.per100g.kcal / 100;
      if (balancer == null || r.food!.per100g.kcal < balancer.food!.per100g.kcal) balancer = r;
    }
    int gramsFor(RationRow r) {
      var g = exact[r.slotId]!.round();
      if (identical(r, balancer)) g += (residualKcal / r.food!.per100g.kcal * 100).round();
      return g < 0 ? 0 : g;
    }

    final allocated = [
      for (final m in meals)
        m.withRows([
          for (final r in m.rows)
            if (r.food == null)
              r.copyWith(grams: 0)
            else if (r.manual)
              r
            else if (!isAuto(r))
              r.copyWith(grams: 0)
            else
              r.copyWith(grams: gramsFor(r)),
        ]),
    ];
    return (allocated, scales != null);
  }

  /// Коэффициенты групп, при которых сумма по ккал, белкам и жирам равна [goal].
  /// null — нужны все три группы, а решение должно быть неотрицательным.
  static Map<MacroGroup, double>? _solveGroupScales(Map<MacroGroup, Nutrients> sums, Nutrients goal) {
    const order = [MacroGroup.protein, MacroGroup.fat, MacroGroup.carbs];
    if (goal.kcal <= 0 || order.any((g) => (sums[g]?.kcal ?? 0) <= 0)) return null;
    final cols = [for (final g in order) sums[g]!];
    final m = [
      [for (final c in cols) c.kcal],
      [for (final c in cols) c.protein],
      [for (final c in cols) c.fat],
    ];
    final rhs = [goal.kcal, goal.protein, goal.fat];

    double det3(List<List<double>> a) =>
        a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
        a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
        a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]);

    final d = det3(m);
    if (d.abs() < 1e-9) return null;
    final result = <MacroGroup, double>{};
    for (var col = 0; col < 3; col++) {
      final mi = [
        for (var row = 0; row < 3; row++) [for (var c = 0; c < 3; c++) c == col ? rhs[row] : m[row][c]],
      ];
      final s = det3(mi) / d;
      if (s.isNaN || s < 0) return null;
      result[order[col]] = s;
    }
    return result;
  }
}
