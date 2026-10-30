import 'body_composition.dart';
import 'models.dart';

/// Коэффициент суточной активности без тренировки (как в «Калькуляторе»).
const double baseActivityFactor = 1.2;

class EnergyResult {
  /// MET вида нагрузки; null — калории тренировки введены вручную.
  final double? met;

  /// ккал/мин для вида нагрузки; null — ручной ввод.
  final double? kcalPerMinute;

  /// Калории тренировки: MET × минуты или значение с браслета.
  final double trainingKcal;

  final double bmr;

  /// Каким способом посчитан [bmr] (по % жира — только если процент задан).
  final BmrMethod bmrMethod;

  /// TDC без тренировки.
  final double tdcRest;

  /// TDC с тренировкой.
  final double tdcTraining;

  /// Цель на день: ккал (выбранный TDC с учётом дефицита/профицита) и БЖУ, г.
  final Nutrients target;

  const EnergyResult({
    required this.met,
    required this.kcalPerMinute,
    required this.trainingKcal,
    required this.bmr,
    required this.bmrMethod,
    required this.tdcRest,
    required this.tdcTraining,
    required this.target,
  });
}

/// ккал/мин = MET × 3,5 × масса тела (кг) / 200  (2024 Adult Compendium).
double kcalPerMinute({required double met, required double weightKg}) =>
    met * 3.5 * weightKg / 200;

/// Миффлин — Сан Жеор: 10·масса + 6,25·рост − 5·возраст + 5 (м) / −161 (ж).
double bmr({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) =>
    10 * weightKg +
    6.25 * heightCm -
    5 * age +
    (sex == Sex.male ? 5 : -161);

/// Цели по БЖУ: белки = г/кг × масса; жиры = % калорий / 9;
/// углеводы — оставшиеся калории / 4 (не меньше нуля).
Nutrients macroTargets({
  required double kcal,
  required double weightKg,
  required double proteinPerKg,
  required double fatPercent,
}) {
  final protein = proteinPerKg * weightKg;
  final fat = kcal * fatPercent / 100 / 9;
  final carbs = (kcal - protein * 4 - fat * 9) / 4;
  return Nutrients(kcal: kcal, protein: protein, fat: fat, carbs: carbs < 0 ? 0 : carbs);
}

/// [met] нужен в режиме [TrainingMode.activity]; в ручном режиме не используется.
EnergyResult calculateEnergy(Profile p, {double? met}) {
  final byActivity = p.trainingMode == TrainingMode.activity;
  final perMin = byActivity && met != null ? kcalPerMinute(met: met, weightKg: p.weightKg) : null;
  final training = byActivity ? (perMin ?? 0) * p.trainingMinutes : p.manualTrainingKcal;
  final byBodyFat = p.bmrMethod == BmrMethod.bodyFat && p.bodyFatPercent != null;
  final b = byBodyFat
      ? bodyFatBmr(sex: p.sex, weightKg: p.weightKg, fatPercent: p.bodyFatPercent!)
      : bmr(sex: p.sex, weightKg: p.weightKg, heightCm: p.heightCm, age: p.age);
  final rest = b * baseActivityFactor;
  final withTraining = rest + training;
  final kcal = (p.includeTraining ? withTraining : rest) * (1 + p.goalPercent / 100);
  return EnergyResult(
    met: byActivity ? met : null,
    kcalPerMinute: perMin,
    trainingKcal: training,
    bmr: b,
    bmrMethod: byBodyFat ? BmrMethod.bodyFat : BmrMethod.mifflin,
    tdcRest: rest,
    tdcTraining: withTraining,
    target: macroTargets(
      kcal: kcal,
      weightKg: p.weightKg,
      proteinPerKg: p.proteinPerKg,
      fatPercent: p.fatPercent,
    ),
  );
}
