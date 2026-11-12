import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/data/database.dart';
import 'package:ration_planner/data/repository.dart';
import 'package:ration_planner/domain/account.dart';
import 'package:ration_planner/domain/body_composition.dart';
import 'package:ration_planner/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_catalog.dart';

/// Настоящий SQLite (в памяти): схема, учётные записи, профиль, замеры.
void main() {
  sqfliteFfiInit();
  late Database db;
  late SqliteRepository repo;

  setUp(() async {
    db = await openAppDatabaseAt(databaseFactoryFfiNoIsolate, inMemoryDatabasePath, loadSeed: () async => loadTestSeed());
    repo = SqliteRepository(db);
  });
  tearDown(() => db.close());

  Future<AppUser> user(String login) => repo.createUser(login: login, name: login, passwordHash: 'h');

  test('логин уникален без учёта регистра', () async {
    final a = await user('Ivan');
    expect((await repo.credentials('ivan'))!.$1.id, a.id);
    expect(() => user('IVAN'), throwsA(isA<LoginTakenException>()));
    expect(await repo.credentials('petr'), isNull);
  });

  test('профиль у каждого пользователя свой', () async {
    final a = await user('a');
    final b = await user('b');
    await repo.saveProfile(a.id, const Profile(
      sex: Sex.female,
      weightKg: 60,
      heightCm: 165,
      age: 30,
      includeTraining: false,
      trainingMode: TrainingMode.activity,
      trainings: [TrainingSession(activityCode: '02074', minutes: 20)],
      manualTrainingKcal: 300,
      goalPercent: -10,
      proteinPerKg: 1.6,
      fatPercent: 25,
    ));
    expect((await repo.loadProfile(a.id))!.weightKg, 60);
    expect(await repo.loadProfile(b.id), isNull);
  });

  test('замеры: объединение за дату, правка, удаление, изоляция пользователей', () async {
    final a = await user('a');
    final b = await user('b');
    await repo.saveMeasurement(a.id, Measurement(
      date: DateTime(2026, 11, 1),
      weightKg: 100,
      bodyFatPercent: 20,
      skinfolds: {Skinfold.abdomen: 12, Skinfold.thigh: 9},
      girths: {Girth.thigh: 60},
    ));
    final merged = await repo.saveMeasurement(a.id, Measurement(
      date: DateTime(2026, 11, 1),
      bmr: 2000,
      bmrMethod: BmrMethod.mifflin,
      target: const Nutrients(kcal: 2500, protein: 150, fat: 70, carbs: 300),
    ));
    await repo.saveMeasurement(a.id, Measurement(date: DateTime(2026, 10, 1), weightKg: 102));
    await repo.saveMeasurement(b.id, Measurement(date: DateTime(2026, 11, 1), weightKg: 70));

    var list = await repo.loadMeasurements(a.id);
    expect(list.map((m) => m.date), [DateTime(2026, 10, 1), DateTime(2026, 11, 1)]);
    final m = list.last;
    expect(m.id, merged.id);
    expect(m.weightKg, 100);
    expect(m.skinfolds, {Skinfold.abdomen: 12, Skinfold.thigh: 9});
    expect(m.girths, {Girth.thigh: 60});
    expect(m.bmr, 2000);
    expect(m.target!.carbs, 300);

    await repo.saveMeasurement(a.id, m.mergedWith(Measurement(date: m.date, note: 'после отпуска')));
    list = await repo.loadMeasurements(a.id);
    expect(list.last.note, 'после отпуска');
    expect(list.length, 2);

    await repo.deleteMeasurement(b.id, m.id!); // чужой замер не удаляется
    expect((await repo.loadMeasurements(a.id)).length, 2);
    await repo.deleteMeasurement(a.id, m.id!);
    expect((await repo.loadMeasurements(a.id)).length, 1);
    expect((await repo.loadMeasurements(b.id)).single.weightKg, 70);
  });

  test('сессия: настройка удаляется', () async {
    await repo.saveSetting('session_user_id', '5');
    await repo.deleteSetting('session_user_id');
    expect(await repo.loadSetting('session_user_id'), isNull);
  });
}
