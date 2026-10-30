import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/domain/body_composition.dart';
import 'package:ration_planner/domain/models.dart';

// Эталоны — из «Процент подкожного жира у мужчин/женщин.xlsx».
Map<Skinfold, double> folds(List<double> values, Sex sex) =>
    {for (final (i, s) in skinfoldsFor(sex).indexed) s: values[i]};

void main() {
  test('мужчина, лист «карипер мужчина», столбец D', () {
    final r = calculateBodyComposition(
      sex: Sex.male,
      weightKg: 86.2,
      heightCm: 185,
      age: 39,
      folds: folds([10.5, 16, 18, 14, 20, 22, 29, 16], Sex.male),
      girths: const Girths(thigh: 59.5, calf: 37, arm: 35),
    );
    expect(r.skinfoldSum, 145.5);
    expect(r.bodySurfaceArea, closeTo(2.1046905288479403, 1e-12));
    expect(r.meanHalfSkinfold, closeTo(9.09375, 1e-12));
    expect(r.fatKg, closeTo(24.881388345724243, 1e-9));
    expect(r.fatPercent, closeTo(28.8647196586128, 1e-9));
    expect(r.leanKg, closeTo(86.2 - 24.881388345724243, 1e-9));
    expect(r.muscleKg, closeTo(38.938532900000006, 1e-9)); // МСМ
    expect(r.leanFactor, 0.85); // > 28 %
    expect(r.bmr, closeTo(86.2 * 24 * 0.85, 1e-9));
  });

  test('женщина, лист «калипер женщина», столбец D', () {
    final r = calculateBodyComposition(
      sex: Sex.female,
      weightKg: 69,
      heightCm: 177,
      age: 43,
      folds: folds([2, 4, 12, 10, 10, 10, 8], Sex.female),
      girths: const Girths(thigh: 62, calf: 37, arm: 32),
    );
    expect(r.skinfoldSum, 56);
    expect(r.fatKg, closeTo(9.5777450373248083, 1e-9));
    expect(r.fatPercent, closeTo(13.88078990916639, 1e-9));
    expect(r.muscleKg, closeTo(34.25318154, 1e-8));
    expect(r.leanFactor, 1.0); // < 18 %
    expect(r.bmr, closeTo(69 * 24 * 0.9, 1e-9));
  });

  test('второй файл: женщина 170 см / 59,5 кг — % жира и LBM', () {
    final r = calculateBodyComposition(
      sex: Sex.female,
      weightKg: 59.5,
      heightCm: 170,
      age: 17,
      folds: folds([7, 7, 14, 9, 9, 12, 17], Sex.female),
    );
    expect(r.fatPercent, closeTo(19.6196523419119, 1e-9));
    expect(r.leanKg, closeTo(47.8263068565623, 1e-9));
    expect(r.muscleKg, isNull); // обхваты не введены
  });

  test('второй файл: мужчина 178 см / 84,6 кг', () {
    final r = calculateBodyComposition(
      sex: Sex.male,
      weightKg: 84.6,
      heightCm: 178,
      age: 26,
      folds: folds([4, 4, 10, 4, 8, 10, 9, 4], Sex.male),
    );
    expect(r.fatPercent, closeTo(10.410529244933098, 1e-9));
    expect(r.fatKg, closeTo(8.8073077412133998, 1e-9));
  });

  test('коэффициенты по % жира (лист «схема»)', () {
    expect([for (final p in [8.0, 13.9, 14.0, 19.9, 20.0, 27.9, 28.0, 35.0]) leanFactor(Sex.male, p)],
        [1.0, 1.0, 0.95, 0.95, 0.90, 0.90, 0.85, 0.85]);
    expect([for (final p in [12.0, 17.9, 18.0, 27.9, 28.0, 37.9, 38.0, 45.0]) leanFactor(Sex.female, p)],
        [1.0, 1.0, 0.95, 0.95, 0.90, 0.90, 0.85, 0.85]);
  });
}
