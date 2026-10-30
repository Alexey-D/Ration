import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/domain/energy_calculator.dart';
import 'package:ration_planner/domain/models.dart';
import 'package:ration_planner/domain/ration_plan.dart';

import 'support/test_catalog.dart';

void main() {
  final catalog = buildTestCatalog();
  // мужчина 102 кг / 178 см / 25 лет, гребля 30 мин; белки 1,4 г/кг, жиры 20 %
  final target = macroTargets(kcal: 3164.7, weightKg: 102, proteinPerKg: 1.4, fatPercent: 20);
  Food food(String name) => catalog.foods.firstWhere((f) => f.name == name);
  RationRow rowOf(RationPlan p, String foodName) =>
      p.meals.expand((m) => m.rows).firstWhere((r) => r.food?.name == foodName);

  /// Итог совпадает с целью: ккал (< 1), белки и жиры (< 2 г).
  void expectOnTarget(RationPlan p) {
    expect(p.macrosMatched, isTrue);
    expect(p.deviation.kcal.abs(), lessThan(1), reason: 'ккал');
    expect(p.deviation.protein.abs(), lessThan(2), reason: 'белки');
    expect(p.deviation.fat.abs(), lessThan(2), reason: 'жиры');
  }

  test('шаблон: при цели = КБЖУ шаблона порции как в Excel', () {
    // в Excel второй перекус пустой — то есть 3 основных приёма + 1 перекус
    const templateTarget = Nutrients(kcal: 2152.4, protein: 115.85, fat: 60.53, carbs: 291.11);
    final p = RationPlan.fromTemplate(catalog, templateTarget, mains: 3, snacks: 1);
    expect(p.meals.map((m) => m.name), ['Завтрак', 'Перекус', 'Обед', 'Ужин']);
    expect(p.meals.every((m) => m.rows.length == 3), isTrue);
    expect(rowOf(p, 'Гречка варёная').grams, 300);
    expect(rowOf(p, 'Финики').grams, 120);
    expect(rowOf(p, 'Телятина готовая').grams, 150);
    expect(rowOf(p, 'Подсолнечное масло').grams, 10);
    expectOnTarget(p);
  });

  test('итог за день совпадает с целью по ккал, белкам и жирам', () {
    final p = RationPlan.fromTemplate(catalog, target);
    expectOnTarget(p);
    expect(p.meals.expand((m) => m.rows).where((r) => r.food != null).every((r) => r.grams > 0), isTrue);
  });

  test('другое соотношение БЖУ меняет порции групп', () {
    final base = RationPlan.fromTemplate(catalog, target);
    final highProtein = RationPlan.fromTemplate(
      catalog,
      macroTargets(kcal: 3164.7, weightKg: 102, proteinPerKg: 2.0, fatPercent: 20),
    );
    expectOnTarget(highProtein);
    expect(rowOf(highProtein, 'Телятина готовая').grams, greaterThan(rowOf(base, 'Телятина готовая').grams));
    expect(rowOf(highProtein, 'Гречка варёная').grams, lessThan(rowOf(base, 'Гречка варёная').grams));
  });

  test('замена продукта — итог остаётся в цели', () {
    final p = RationPlan.fromTemplate(catalog, target);
    final slot = rowOf(p, 'Гречка варёная').slotId;
    final q = p.withFood(slot, food('Рис белый варёный'));
    expect(q.row(slot).food!.name, 'Рис белый варёный');
    expectOnTarget(q);
  });

  test('добавление продукта в пустое место перераспределяет доли', () {
    final p = RationPlan.fromTemplate(catalog, target);
    final emptySlot = p.meals[1].rows[1]; // Перекус 1, белковый
    expect(emptySlot.food, isNull);
    final q = p.withFood(emptySlot.slotId, food('Творог 2%'));
    expect(q.row(emptySlot.slotId).grams, greaterThan(0));
    expect(rowOf(q, 'Творог 5%').grams, lessThan(rowOf(p, 'Творог 5%').grams));
    expectOnTarget(q);
  });

  test('удаление продукта — остальные порции растут, итог в цели', () {
    final p = RationPlan.fromTemplate(catalog, target);
    final q = p.withoutFood(rowOf(p, 'Финики').slotId);
    expect(rowOf(q, 'Гречка варёная').grams, greaterThan(rowOf(p, 'Гречка варёная').grams));
    expectOnTarget(q);
  });

  test('ручная порция фиксируется, остальные подстраиваются; «подогнать» сбрасывает', () {
    final p = RationPlan.fromTemplate(catalog, target);
    final slot = rowOf(p, 'Гречка варёная').slotId;
    final q = p.withGrams(slot, 600);
    expect(q.row(slot).manual, isTrue);
    expect(q.row(slot).grams, 600);
    expect(rowOf(q, 'Рис белый варёный').grams, lessThan(rowOf(p, 'Рис белый варёный').grams));
    expectOnTarget(q);
    final r = q.rebalanced();
    expect(r.row(slot).manual, isFalse);
    expect(r.row(slot).grams, p.row(slot).grams);
  });

  test('новая цель сохраняет выбранные продукты', () {
    final p = RationPlan.fromTemplate(catalog, target);
    final slot = rowOf(p, 'Гречка варёная').slotId;
    final newTarget = macroTargets(kcal: 2000, weightKg: 102, proteinPerKg: 1.2, fatPercent: 25);
    final q = p.withFood(slot, food('Киноа варёная')).withTarget(newTarget);
    expect(q.row(slot).food!.name, 'Киноа варёная');
    expect(q.target.kcal, 2000);
    expectOnTarget(q);
  });

  test('смена категории подставляет первый продукт категории', () {
    final p = RationPlan.fromTemplate(catalog, target);
    final slot = rowOf(p, 'Гречка варёная').slotId;
    final snack = catalog.foodCategories.firstWhere((c) => c.key == 'snack');
    final first = catalog.foodsOf(snack.id).first;
    final q = p.withCategory(slot, snack.id, first);
    expect(q.row(slot).categoryId, snack.id);
    expect(q.row(slot).food!.id, first.id);
    expectOnTarget(q);
  });

  test('без продуктов группы «жиры» БЖУ не подогнать — порции только по калориям', () {
    var p = RationPlan.fromTemplate(catalog, target);
    for (final r in p.meals.expand((m) => m.rows).toList()) {
      if (r.food != null && catalog.category(r.categoryId).key == 'fat') p = p.withoutFood(r.slotId);
    }
    expect(p.macrosMatched, isFalse);
    expect(p.deviation.kcal.abs(), lessThan(1));
  });
}
