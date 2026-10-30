import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/app.dart';
import 'package:ration_planner/domain/models.dart';
import 'package:ration_planner/state/providers.dart';

import 'support/test_catalog.dart';

void main() {
  Future<FakeRepository> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepository(buildTestCatalog());
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: const RationApp(),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('шаг 1 → выбор → рацион → таблица', (tester) async {
    final repo = await pumpApp(tester);

    expect(find.text('Шаг 1 из 3'), findsOneWidget);
    expect(find.text('Как пользоваться'), findsOneWidget);
    await tapText(tester, 'Далее');

    expect(find.text('Шаг 2 из 3'), findsOneWidget);
    await tapText(tester, 'Рацион питания');

    expect(find.text('Шаг 3 из 3'), findsOneWidget);
    expect(find.textContaining('Гребной тренажёр, ≥ 200 Вт'), findsOneWidget); // русское название
    expect(find.text('3165 ккал'), findsOneWidget); // предпросмотр цели
    await tapText(tester, 'Рассчитать рацион');

    expect(find.text('Рацион на день'), findsOneWidget);
    expect(find.text('ИТОГО ЗА ДЕНЬ'), findsOneWidget);
    expect(find.text('3165 ккал'), findsOneWidget);
    expect(repo.saved!.proteinPerKg, 1.4);
    expect(repo.saved!.bmrMethod, BmrMethod.mifflin);
  });

  testWidgets('режим «Данные браслета»: калории вводятся вручную, длительности нет', (tester) async {
    final repo = await pumpApp(tester);
    await tapText(tester, 'Далее');
    await tapText(tester, 'Рацион питания');

    expect(find.text('Длительность тренировки'), findsOneWidget);
    await tapText(tester, 'Данные браслета');
    expect(find.text('Длительность тренировки'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Калории тренировки'), '600');
    await tester.pumpAndSettle();
    expect(find.text('3015 ккал'), findsOneWidget); // 2415 + 600

    await tapText(tester, 'Рассчитать рацион');
    expect(find.text('Тренировка по данным браслета'), findsOneWidget);
    expect(repo.saved!.trainingMode, TrainingMode.manual);
    expect(repo.saved!.manualTrainingKcal, 600);
  });

  testWidgets('калиперометрия → % жира → BMR по % жира в рационе', (tester) async {
    final repo = await pumpApp(tester);
    await tapText(tester, 'Далее');
    await tapText(tester, 'Процент подкожного жира');

    expect(find.text('Шаг 3 из 3'), findsOneWidget);
    expect(find.text('Грудь'), findsOneWidget); // мужчина — 8 складок
    const folds = {
      'Предплечье': '4', 'Плечо спереди': '4', 'Плечо сзади': '10', 'Грудь': '4',
      'Лопатка': '8', 'Живот': '10', 'Бедро': '9', 'Голень': '4',
    };
    for (final MapEntry(:key, :value) in folds.entries) {
      await tester.enterText(find.byKey(Key('field-$key')), value);
    }
    await tester.pumpAndSettle();

    // 102 кг / 178 см: сумма 53 мм → 3,3125 × 2,2457 × 1,3 = 9,67 кг жира → 9,5 %
    expect(find.text('9,5 %'), findsOneWidget);
    expect(find.text('введите обхваты'), findsOneWidget);

    await tapText(tester, 'Использовать в расчёте рациона');
    expect(find.text('Рацион: тренировка и цели'), findsOneWidget);
    // BMR = 102 × 24 × 1,0 = 2448; цель = 2448 × 1,2 + 749,7 = 3687
    expect(find.textContaining('BMR 2448 ккал — по 9,5 % жира'), findsOneWidget);
    expect(find.text('3687 ккал'), findsOneWidget);

    await tapText(tester, 'Рассчитать рацион');
    expect(repo.saved!.bmrMethod, BmrMethod.bodyFat);
    expect(repo.saved!.bodyFatPercent, 9.5);
  });
}
