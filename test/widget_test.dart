import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/app.dart';
import 'package:ration_planner/domain/account.dart';
import 'package:ration_planner/domain/models.dart';
import 'package:ration_planner/state/providers.dart';
import 'package:ration_planner/ui/form_widgets.dart';

import 'support/test_catalog.dart';

void main() {
  Future<FakeRepository> pumpApp(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepository(buildTestCatalog(), signedIn: signedIn);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        passwordHasherProvider.overrideWithValue(testHasher),
      ],
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
    // справка скрыта и открывается во всплывающем окне
    expect(find.byType(InstructionList), findsNothing);
    await tapText(tester, 'Как пользоваться');
    expect(find.byType(InstructionList), findsOneWidget);
    await tapText(tester, 'Понятно');
    expect(find.byType(InstructionList), findsNothing);
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

  testWidgets('две тренировки: калории складываются, сохраняются в профиль', (tester) async {
    final repo = await pumpApp(tester);
    await tapText(tester, 'Далее');
    await tapText(tester, 'Рацион питания');

    expect(find.text('Длительность тренировки'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('trainingCount')));
    await tester.tap(find.descendant(of: find.byKey(const Key('trainingCount')), matching: find.text('2')));
    await tester.pumpAndSettle();
    expect(find.text('Длительность тренировки'), findsNWidgets(2));
    expect(find.text('Тренировка 2'), findsOneWidget);
    expect(find.text('3914 ккал'), findsOneWidget); // 2415 + 749,7 × 2

    await tester.enterText(find.descendant(of: find.byKey(const Key('minutesField-1')), matching: find.byType(TextFormField)), '60');
    await tester.pumpAndSettle();
    expect(find.text('4664 ккал'), findsOneWidget); // 2415 + 749,7 + 1499,4

    await tapText(tester, 'Рассчитать рацион');
    expect(find.text('Итоги дня'), findsOneWidget);
    expect(find.text('1499 ккал'), findsOneWidget); // вторая тренировка — отдельной строкой
    expect(find.text('2249'), findsOneWidget); // тренировки в разбивке расхода
    expect(repo.saved!.trainings.map((t) => t.minutes), [30, 60]);
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
    // LBM = 102 × 0,905 = 92,31; BMR = 500 + 22 × 92,31 = 2530,8; цель = 2530,8 × 1,2 + 749,7 = 3787
    expect(find.textContaining('BMR 2531 ккал — по Каннингему: LBM 92,3 кг (9,5 % жира)'), findsOneWidget);
    expect(find.text('3787 ккал'), findsOneWidget);

    await tapText(tester, 'Рассчитать рацион');
    expect(repo.saved!.bmrMethod, BmrMethod.bodyFat);
    expect(repo.saved!.bodyFatPercent, 9.5);
  });

  Future<void> openAccountMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('accountMenu')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> confirmDatePicker(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextButton)).last);
    await tester.pumpAndSettle();
  }

  testWidgets('регистрация → выход → неверный пароль → вход', (tester) async {
    final repo = await pumpApp(tester, signedIn: false);
    expect(find.text('Войти'), findsOneWidget);

    await tapText(tester, 'Регистрация');
    await tester.enterText(find.byKey(const Key('loginField')), 'anna');
    await tester.enterText(find.byKey(const Key('nameField')), 'Анна');
    await tester.enterText(find.byKey(const Key('passwordField')), '1234');
    await tester.enterText(find.byKey(const Key('confirmField')), '1235');
    await tapText(tester, 'Зарегистрироваться');
    expect(find.text('Пароли не совпадают'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('confirmField')), '1234');
    await tapText(tester, 'Зарегистрироваться');
    expect(find.text('Шаг 1 из 3'), findsOneWidget);
    expect(repo.users.single.$1.name, 'Анна');
    expect(repo.users.single.$2, isNot(contains('1234'))); // хранится хэш, не пароль

    await openAccountMenu(tester, 'Выйти');
    expect(find.text('Войти'), findsOneWidget);
    expect(repo.settings['session_user_id'], isNull);

    await tester.enterText(find.byKey(const Key('loginField')), 'ANNA');
    await tester.enterText(find.byKey(const Key('passwordField')), '0000');
    await tapText(tester, 'Войти');
    expect(find.text('Неверный логин или пароль'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('passwordField')), '1234');
    await tapText(tester, 'Войти');
    expect(find.text('Шаг 1 из 3'), findsOneWidget);
  });

  testWidgets('калиперометрия → «Сохранить замер» → личный кабинет', (tester) async {
    final repo = await pumpApp(tester);
    await tapText(tester, 'Далее');
    await tapText(tester, 'Процент подкожного жира');
    const folds = {
      'Предплечье': '4', 'Плечо спереди': '4', 'Плечо сзади': '10', 'Грудь': '4',
      'Лопатка': '8', 'Живот': '10', 'Бедро': '9', 'Голень': '4',
    };
    for (final MapEntry(:key, :value) in folds.entries) {
      await tester.enterText(find.byKey(Key('field-$key')), value);
    }
    await tester.enterText(find.byKey(const Key('field-Обхват бедра')), '60');
    await tester.pumpAndSettle();

    await tapText(tester, 'Сохранить замер');
    await confirmDatePicker(tester);
    final saved = repo.measurements[1]!.single;
    expect(saved.bodyFatPercent, closeTo(9.48, 0.01));
    expect(saved.skinfoldSum, 53);
    expect(saved.girths, {Girth.thigh: 60.0});
    expect(saved.weightKg, 102);

    await openAccountMenu(tester, 'Личный кабинет');
    expect(find.text('Личный кабинет'), findsOneWidget);
    expect(find.text('История замеров'), findsOneWidget);
    expect(find.text('9,5 %'), findsOneWidget); // последние значения
    expect(find.byKey(const Key('metric-bodyFat')), findsOneWidget);
    expect(find.byKey(const Key('metric-bmr')), findsNothing); // BMR не сохраняли
  });

  testWidgets('личный кабинет: ручной замер и изменение к предыдущему', (tester) async {
    final repo = await pumpApp(tester);
    repo.measurements[1] = [Measurement(id: 1, date: DateTime(2026, 1, 10), weightKg: 105, girths: {Girth.waist: 95})];
    await openAccountMenu(tester, 'Личный кабинет');
    expect(find.text('105,0 кг'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addMeasurement')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('measurementWeight')), '101,5');
    await tester.enterText(find.byKey(const Key('measurementFat')), '20');
    await tester.enterText(find.byKey(const Key('girth-waist')), '92');
    await tester.tap(find.byKey(const Key('measurementSave')));
    await tester.pumpAndSettle();

    final latest = repo.measurements[1]!.last;
    expect(latest.weightKg, 101.5);
    expect(latest.fatKg, closeTo(20.3, 1e-9));
    expect(latest.leanKg, closeTo(81.2, 1e-9));
    expect(find.text('101,5 кг'), findsOneWidget);
    expect(find.textContaining('−3,5'), findsWidgets); // масса: 101,5 − 105
    expect(find.textContaining('−3,0'), findsWidgets); // талия: 92 − 95
  });
}
