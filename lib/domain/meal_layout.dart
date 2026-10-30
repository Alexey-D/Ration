import 'models.dart';

/// Допустимое число основных приёмов пищи и перекусов.
const mealCountRange = (min: 1, max: 3);

/// Как в исходном «Конструкторе рациона»: завтрак, обед, ужин + 2 перекуса.
const defaultMainMeals = 3;
const defaultSnacks = 2;

/// Приёмы пищи для заданного числа основных приёмов и перекусов.
///
/// - основные: 3 — все из шаблона; 2 — первый и последний (завтрак и ужин); 1 — последний (ужин:
///   в шаблоне у него постный белок — с ним достижимы цели по БЖУ);
/// - перекусы: «Перекус k» из шаблона, если в нём есть продукты; пустые и недостающие — копия
///   первого перекуса (с отрицательными id, чтобы не пересекаться с id из БД);
/// - порядок — чередование: основной, перекус, основной, перекус… лишние перекусы — в конце.
List<MealTemplate> mealLayout(List<MealTemplate> template, {required int mains, required int snacks}) {
  final mainTemplates = template.where((m) => !m.isSnack).toList();
  final snackTemplates = template.where((m) => m.isSnack).toList();

  final selectedMains = switch (mains.clamp(0, mainTemplates.length)) {
    0 => <MealTemplate>[],
    1 => [mainTemplates.last],
    2 => [mainTemplates.first, mainTemplates.last],
    final n => mainTemplates.take(n).toList(),
  };

  final snackCount = snackTemplates.isEmpty ? 0 : snacks;
  final selectedSnacks = [
    for (var k = 1; k <= snackCount; k++)
      _renamed(
        k <= snackTemplates.length && _hasFood(snackTemplates[k - 1])
            ? snackTemplates[k - 1]
            : _copy(snackTemplates.first, k),
        snackCount == 1 ? 'Перекус' : 'Перекус $k',
      ),
  ];

  return [
    for (var i = 0; i < selectedMains.length || i < selectedSnacks.length; i++) ...[
      if (i < selectedMains.length) selectedMains[i],
      if (i < selectedSnacks.length) selectedSnacks[i],
    ],
  ];
}

bool _hasFood(MealTemplate m) => m.slots.any((s) => s.defaultFoodId != null);

MealTemplate _renamed(MealTemplate m, String name) => MealTemplate(id: m.id, name: name, slots: m.slots);

MealTemplate _copy(MealTemplate m, int k) => MealTemplate(
      id: -(m.id * 10 + k),
      name: m.name,
      slots: [
        for (final s in m.slots)
          SlotTemplate(
            id: -(s.id * 10 + k),
            categoryId: s.categoryId,
            defaultFoodId: s.defaultFoodId,
            baseGrams: s.baseGrams,
          ),
      ],
    );
