import 'dart:math' as math;

import 'models.dart';

/// Точки измерения кожно-жировых складок (калипер), мм.
enum Skinfold {
  forearm('Предплечье'),
  armFront('Плечо спереди'),
  armBack('Плечо сзади'),
  chest('Грудь'),
  subscapular('Лопатка'),
  abdomen('Живот'),
  thigh('Бедро'),
  calf('Голень');

  final String label;
  const Skinfold(this.label);
}

/// Складки по полу: у мужчин 8 точек, у женщин 7 (без груди).
List<Skinfold> skinfoldsFor(Sex sex) =>
    sex == Sex.male ? Skinfold.values : Skinfold.values.where((s) => s != Skinfold.chest).toList();

/// Обхваты для расчёта мышечной массы, см.
class Girths {
  final double thigh;
  final double calf;
  final double arm;
  const Girths({required this.thigh, required this.calf, required this.arm});
}

class BodyCompositionResult {
  /// Площадь поверхности тела (Мостеллер), м².
  final double bodySurfaceArea;
  final double skinfoldSum;

  /// Средняя полутолщина складки, мм: сумма / (2 × число точек).
  final double meanHalfSkinfold;
  final double fatKg;
  final double fatPercent;

  /// Безжировая масса (LBM), кг.
  final double leanKg;

  /// Скелетная мышечная масса (Ли), кг; null — обхваты не введены.
  final double? muscleKg;

  /// Коэффициент по % жира (лист «схема»).
  final double leanFactor;

  /// BMR по проценту жира, ккал.
  final double bmr;

  const BodyCompositionResult({
    required this.bodySurfaceArea,
    required this.skinfoldSum,
    required this.meanHalfSkinfold,
    required this.fatKg,
    required this.fatPercent,
    required this.leanKg,
    required this.muscleKg,
    required this.leanFactor,
    required this.bmr,
  });
}

/// Площадь поверхности тела по Мостеллеру: √(рост, см × масса, кг / 3600).
double bodySurfaceArea({required double heightCm, required double weightKg}) =>
    math.sqrt(heightCm * weightKg / 3600);

/// Коэффициент по % жира (лист «схема»):
/// мужчины  < 14 → 1,0; 14–20 → 0,95; 20–28 → 0,90; > 28 → 0,85;
/// женщины  < 18 → 1,0; 18–28 → 0,95; 28–38 → 0,90; > 38 → 0,85.
double leanFactor(Sex sex, double fatPercent) {
  final bounds = sex == Sex.male ? const [14.0, 20.0, 28.0] : const [18.0, 28.0, 38.0];
  if (fatPercent < bounds[0]) return 1.0;
  if (fatPercent < bounds[1]) return 0.95;
  if (fatPercent < bounds[2]) return 0.90;
  return 0.85;
}

/// BMR по проценту жира: масса × 24 × (1 муж / 0,9 жен) × коэффициент по % жира.
double bodyFatBmr({required Sex sex, required double weightKg, required double fatPercent}) =>
    weightKg * 24 * (sex == Sex.male ? 1.0 : 0.9) * leanFactor(sex, fatPercent);

/// Скелетная мышечная масса по уравнению Ли (Lee, 2000) в варианте исходного Excel:
/// рост, м × (0,00088·(обхв. бедра − скл. бедра/10)² + 0,00744·(обхв. плеча − скл. плеча сзади/10)²
/// + 0,00441·(обхв. голени − скл. голени/10)²) + 2,4·пол − 0,048·возраст + 7,8.
/// Обхваты в см, складки в мм; пол: мужчина 1, женщина 0.
/// В оригинале Ли из обхвата вычитается π × складка (см); здесь — как в Excel, без π.
double leeMuscleMass({
  required Sex sex,
  required double heightCm,
  required int age,
  required Map<Skinfold, double> folds,
  required Girths girths,
}) {
  double sq(double v) => v * v;
  final h = heightCm / 100;
  return h *
          (0.00088 * sq(girths.thigh - folds[Skinfold.thigh]! / 10) +
              0.00744 * sq(girths.arm - folds[Skinfold.armBack]! / 10) +
              0.00441 * sq(girths.calf - folds[Skinfold.calf]! / 10)) +
      2.4 * (sex == Sex.male ? 1 : 0) -
      0.048 * age +
      7.8;
}

/// Процент жира по калиперометрии (метод Матейки, как в исходных таблицах):
/// масса жира = средняя полутолщина складки (мм) × площадь тела (м²) × 1,3.
BodyCompositionResult calculateBodyComposition({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  required Map<Skinfold, double> folds,
  Girths? girths,
}) {
  final sites = skinfoldsFor(sex);
  final sum = sites.fold<double>(0, (s, f) => s + folds[f]!);
  final halfFold = sum / (2 * sites.length);
  final bsa = bodySurfaceArea(heightCm: heightCm, weightKg: weightKg);
  final fatKg = halfFold * bsa * 1.3;
  final fatPercent = fatKg * 100 / weightKg;
  return BodyCompositionResult(
    bodySurfaceArea: bsa,
    skinfoldSum: sum,
    meanHalfSkinfold: halfFold,
    fatKg: fatKg,
    fatPercent: fatPercent,
    leanKg: weightKg - fatKg,
    muscleKg: girths == null
        ? null
        : leeMuscleMass(sex: sex, heightCm: heightCm, age: age, folds: folds, girths: girths),
    leanFactor: leanFactor(sex, fatPercent),
    bmr: bodyFatBmr(sex: sex, weightKg: weightKg, fatPercent: fatPercent),
  );
}
