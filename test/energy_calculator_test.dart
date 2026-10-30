import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/domain/energy_calculator.dart';
import 'package:ration_planner/domain/models.dart';

// Эталоны — из «Калькулятор .xlsx» (масса 102 кг, гребля ≥ 200 Вт, MET 14).
void main() {
  test('ккал/мин = MET × 3,5 × масса / 200', () {
    expect(kcalPerMinute(met: 14, weightKg: 102), closeTo(24.99, 1e-9));
  });

  test('BMR женщины совпадает с Excel (E12)', () {
    expect(bmr(sex: Sex.female, weightKg: 102, heightCm: 190, age: 40), closeTo(1846.5, 1e-9));
  });

  test('BMR мужчины: +5 по Миффлину (в Excel было −5 → 2002,5)', () {
    expect(bmr(sex: Sex.male, weightKg: 102, heightCm: 178, age: 25), closeTo(2012.5, 1e-9));
  });

  const female = Profile(
    sex: Sex.female,
    weightKg: 102,
    heightCm: 190,
    age: 40,
    includeTraining: true,
    trainingMode: TrainingMode.activity,
    activityCode: '02074',
    trainingMinutes: 30,
    manualTrainingKcal: 400,
    goalPercent: 0,
    proteinPerKg: 1.4,
    fatPercent: 20,
  );

  test('TDC женщины совпадает с Excel (E13, E14)', () {
    final r = calculateEnergy(female, met: 14);
    expect(r.tdcRest, closeTo(2215.8, 1e-9));
    expect(r.tdcTraining, closeTo(2965.5, 1e-9));
    expect(r.trainingKcal, closeTo(749.7, 1e-9));
    expect(r.target.kcal, closeTo(2965.5, 1e-9));
  });

  test('TDC мужчины с тренировкой учитывает минуты', () {
    final r = calculateEnergy(female.copyWith(sex: Sex.male, heightCm: 178, age: 25), met: 14);
    expect(r.tdcRest, closeTo(2415, 1e-9));
    expect(r.tdcTraining, closeTo(3164.7, 1e-9));
  });

  test('без тренировки цель = TDC без тренировки', () {
    final r = calculateEnergy(female.copyWith(includeTraining: false), met: 14);
    expect(r.target.kcal, closeTo(2215.8, 1e-9));
  });

  test('ручной ввод: калории браслета вместо MET × минуты', () {
    final r = calculateEnergy(female.copyWith(trainingMode: TrainingMode.manual));
    expect(r.met, isNull);
    expect(r.kcalPerMinute, isNull);
    expect(r.trainingKcal, 400);
    expect(r.tdcTraining, closeTo(2215.8 + 400, 1e-9));
    expect(r.target.kcal, closeTo(2615.8, 1e-9));
  });

  test('дефицит/профицит применяется к цели', () {
    expect(calculateEnergy(female.copyWith(goalPercent: -10), met: 14).target.kcal, closeTo(2668.95, 1e-9));
    expect(calculateEnergy(female.copyWith(goalPercent: 10), met: 14).target.kcal, closeTo(3262.05, 1e-9));
  });

  test('БЖУ: белки г/кг, жиры % калорий, углеводы — остаток', () {
    final t = calculateEnergy(female, met: 14).target;
    expect(t.protein, closeTo(142.8, 1e-9)); // 1,4 × 102
    expect(t.fat, closeTo(2965.5 * 0.2 / 9, 1e-9)); // 65,9
    expect(t.carbs, closeTo((2965.5 - 142.8 * 4 - 2965.5 * 0.2) / 4, 1e-9)); // 450,3
    expect(t.protein * 4 + t.fat * 9 + t.carbs * 4, closeTo(t.kcal, 1e-9));
  });

  test('BMR по % жира: масса × 24 × 0,9 (жен) × коэффициент по % жира', () {
    final r = calculateEnergy(female.copyWith(bmrMethod: BmrMethod.bodyFat, bodyFatPercent: 30), met: 14);
    expect(r.bmrMethod, BmrMethod.bodyFat);
    expect(r.bmr, closeTo(102 * 24 * 0.9 * 0.90, 1e-9)); // 28–38 % → 0,90
    expect(r.tdcRest, closeTo(r.bmr * 1.2, 1e-9));
  });

  test('BMR по % жира без заданного процента — Миффлин', () {
    final r = calculateEnergy(female.copyWith(bmrMethod: BmrMethod.bodyFat), met: 14);
    expect(r.bmrMethod, BmrMethod.mifflin);
    expect(r.bmr, closeTo(1846.5, 1e-9));
  });

  test('углеводы не уходят в минус', () {
    final t = macroTargets(kcal: 1000, weightKg: 150, proteinPerKg: 2, fatPercent: 30);
    expect(t.carbs, 0);
  });
}
