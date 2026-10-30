import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/domain/energy_calculator.dart';
import 'package:ration_planner/domain/meal_layout.dart';
import 'package:ration_planner/domain/models.dart';
import 'package:ration_planner/domain/ration_plan.dart';

import 'support/test_catalog.dart';

void main() {
  final catalog = buildTestCatalog();
  final target = macroTargets(kcal: 3164.7, weightKg: 102, proteinPerKg: 1.4, fatPercent: 20);
  List<String> names(List<MealTemplate> l) => [for (final m in l) m.name];

  test('по умолчанию — как в шаблоне: 3 основных + 2 перекуса', () {
    expect(names(mealLayout(catalog.meals, mains: defaultMainMeals, snacks: defaultSnacks)),
        ['Завтрак', 'Перекус 1', 'Обед', 'Перекус 2', 'Ужин']);
  });

  test('чередование основных приёмов и перекусов', () {
    expect(names(mealLayout(catalog.meals, mains: 3, snacks: 3)),
        ['Завтрак', 'Перекус 1', 'Обед', 'Перекус 2', 'Ужин', 'Перекус 3']);
    expect(names(mealLayout(catalog.meals, mains: 3, snacks: 1)), ['Завтрак', 'Перекус', 'Обед', 'Ужин']);
    expect(names(mealLayout(catalog.meals, mains: 2, snacks: 2)), ['Завтрак', 'Перекус 1', 'Ужин', 'Перекус 2']);
    expect(names(mealLayout(catalog.meals, mains: 1, snacks: 3)), ['Ужин', 'Перекус 1', 'Перекус 2', 'Перекус 3']);
    expect(names(mealLayout(catalog.meals, mains: 1, snacks: 1)), ['Ужин', 'Перекус']);
  });

  test('пустой (2-й) и недостающий (3-й) перекусы — копии первого с уникальными id', () {
    final layout = mealLayout(catalog.meals, mains: 3, snacks: 3);
    final first = layout[1];
    for (final copy in [layout[3], layout[5]]) {
      expect(copy.id, isNegative);
      expect([for (final s in copy.slots) s.defaultFoodId], [for (final s in first.slots) s.defaultFoodId]);
    }
    final slotIds = [for (final m in layout) for (final s in m.slots) s.id];
    expect(slotIds.toSet().length, slotIds.length);
  });

  test('план с любым числом приёмов попадает в цель', () {
    for (var mains = 1; mains <= 3; mains++) {
      for (var snacks = 1; snacks <= 3; snacks++) {
        final p = RationPlan.fromTemplate(catalog, target, mains: mains, snacks: snacks);
        expect(p.mainMealCount, mains);
        expect(p.snackCount, snacks);
        expect(p.deviation.kcal.abs(), lessThan(1), reason: '$mains + $snacks');
        if (p.macrosMatched) {
          expect(p.deviation.protein.abs(), lessThan(2), reason: '$mains + $snacks');
          expect(p.deviation.fat.abs(), lessThan(2), reason: '$mains + $snacks');
        }
      }
    }
  });

  test('смена числа приёмов сохраняет выбранные продукты в оставшихся приёмах', () {
    final quinoa = catalog.foods.firstWhere((f) => f.name == 'Киноа варёная');
    var p = RationPlan.fromTemplate(catalog, target);
    final breakfastGrain = p.meals.first.rows.first.slotId;
    p = p.withFood(breakfastGrain, quinoa);

    final q = p.withMealCounts(catalog, mains: 2, snacks: 3);
    expect(q.meals.map((m) => m.name), ['Завтрак', 'Перекус 1', 'Ужин', 'Перекус 2', 'Перекус 3']);
    expect(q.row(breakfastGrain).food!.name, 'Киноа варёная');
    expect(q.deviation.kcal.abs(), lessThan(1));

    // обратно к 3 + 2: обед возвращается из шаблона, завтрак — с киноа
    final r = q.withMealCounts(catalog, mains: 3, snacks: 2);
    expect(r.meals.map((m) => m.name), ['Завтрак', 'Перекус 1', 'Обед', 'Перекус 2', 'Ужин']);
    expect(r.row(breakfastGrain).food!.name, 'Киноа варёная');
  });
}
