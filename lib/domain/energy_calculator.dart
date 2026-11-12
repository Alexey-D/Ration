import 'body_composition.dart';
import 'models.dart';

/// Коэффициент суточной активности без тренировки (как в «Калькуляторе»).
const double baseActivityFactor = 1.2;

/// Расход на одну тренировку по виду нагрузки.
class SessionEnergy {
  final TrainingSession session;

  /// MET вида нагрузки; null — вид нагрузки не найден в справочнике.
  final double? met;
  final double? kcalPerMinute;

  /// ккал/мин × минуты.
  final double kcal;

  const SessionEnergy({required this.session, required this.met, required this.kcalPerMinute, required this.kcal});
}

class EnergyResult {
  /// Тренировки по видам нагрузки; пусто — калории введены с браслета.
  final List<SessionEnergy> sessions;

  /// Калории тренировок: сумма MET × минуты по всем тренировкам или значение с браслета.
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
    required this.sessions,
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

SessionEnergy _sessionEnergy(TrainingSession s, double? met, double weightKg) {
  final perMin = met == null ? null : kcalPerMinute(met: met, weightKg: weightKg);
  return SessionEnergy(session: s, met: met, kcalPerMinute: perMin, kcal: (perMin ?? 0) * s.minutes);
}

/// [metOf] — MET вида нагрузки по коду (нужен в режиме [TrainingMode.activity]).
/// Калории тренировок складываются: Σ MET × 3,5 × масса / 200 × минуты.
EnergyResult calculateEnergy(Profile p, {double? Function(String activityCode)? metOf}) {
  final byActivity = p.trainingMode == TrainingMode.activity;
  final sessions = [
    if (byActivity)
      for (final s in p.trainings) _sessionEnergy(s, metOf?.call(s.activityCode), p.weightKg),
  ];
  final training = byActivity ? sessions.fold(0.0, (sum, s) => sum + s.kcal) : p.manualTrainingKcal;
  final byBodyFat = p.bmrMethod == BmrMethod.bodyFat && p.bodyFatPercent != null;
  final b = byBodyFat
      ? cunninghamBmr(weightKg: p.weightKg, fatPercent: p.bodyFatPercent!)
      : bmr(sex: p.sex, weightKg: p.weightKg, heightCm: p.heightCm, age: p.age);
  final rest = b * baseActivityFactor;
  final withTraining = rest + training;
  final kcal = (p.includeTraining ? withTraining : rest) * (1 + p.goalPercent / 100);
  return EnergyResult(
    sessions: sessions,
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
