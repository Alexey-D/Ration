import 'body_composition.dart';
import 'energy_calculator.dart';
import 'models.dart';

/// Пользователь приложения (локальная учётная запись).
class AppUser {
  final int id;

  /// Логин для входа (без учёта регистра).
  final String login;

  /// Как обращаться к пользователю.
  final String name;
  final DateTime createdAt;

  const AppUser({required this.id, required this.login, required this.name, required this.createdAt});
}

/// Правила для логина и пароля (упрощённая авторизация).
const loginLength = (min: 3, max: 32);
const minPasswordLength = 4;
final loginPattern = RegExp(r'^[A-Za-z0-9_.\-]+$');

/// null — логин подходит, иначе текст ошибки.
String? validateLogin(String login) {
  final l = login.trim();
  if (l.length < loginLength.min || l.length > loginLength.max) {
    return 'Логин — от ${loginLength.min} до ${loginLength.max} символов';
  }
  if (!loginPattern.hasMatch(l)) return 'Только латинские буквы, цифры и символы _ . -';
  return null;
}

String? validatePassword(String password) =>
    password.length < minPasswordLength ? 'Пароль — не короче $minPasswordLength символов' : null;

/// Дата без времени.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Обхваты тела, см. Бедро, голень и плечо нужны для мышечной массы (Ли).
enum Girth {
  waist('Талия'),
  hips('Ягодицы'),
  chest('Грудь'),
  thigh('Бедро'),
  calf('Голень'),
  arm('Плечо');

  final String label;
  const Girth(this.label);
}

/// Замер — состояние тела и расчёты на дату. Все показатели необязательны:
/// калиперометрия, расчёт рациона и ручной ввод заполняют каждый свою часть,
/// а замеры за одну дату объединяются ([mergedWith]).
class Measurement {
  /// null — ещё не сохранён.
  final int? id;
  final DateTime date;

  final double? weightKg;
  final double? heightCm;
  final int? age;

  // Состав тела
  final double? bodyFatPercent;
  final double? fatKg;
  final double? leanKg;
  final double? muscleKg;
  final Map<Skinfold, double> skinfolds;
  final Map<Girth, double> girths;

  // Энергия и рацион
  final double? bmr;
  final BmrMethod? bmrMethod;
  final double? tdc;
  final Nutrients? target;

  final String? note;

  Measurement({
    this.id,
    required DateTime date,
    this.weightKg,
    this.heightCm,
    this.age,
    this.bodyFatPercent,
    this.fatKg,
    this.leanKg,
    this.muscleKg,
    this.skinfolds = const {},
    this.girths = const {},
    this.bmr,
    this.bmrMethod,
    this.tdc,
    this.target,
    this.note,
  }) : date = dateOnly(date);

  double? get skinfoldSum => skinfolds.isEmpty ? null : skinfolds.values.fold<double>(0, (s, v) => s + v);

  /// Объединение с более новым замером за ту же дату: заданные в [newer] значения заменяют старые.
  Measurement mergedWith(Measurement newer) => Measurement(
        id: id ?? newer.id,
        date: date,
        weightKg: newer.weightKg ?? weightKg,
        heightCm: newer.heightCm ?? heightCm,
        age: newer.age ?? age,
        bodyFatPercent: newer.bodyFatPercent ?? bodyFatPercent,
        fatKg: newer.fatKg ?? fatKg,
        leanKg: newer.leanKg ?? leanKg,
        muscleKg: newer.muscleKg ?? muscleKg,
        skinfolds: newer.skinfolds.isNotEmpty ? newer.skinfolds : skinfolds,
        girths: {...girths, ...newer.girths},
        bmr: newer.bmr ?? bmr,
        bmrMethod: newer.bmr != null ? newer.bmrMethod : bmrMethod,
        tdc: newer.tdc ?? tdc,
        target: newer.target ?? target,
        note: newer.note ?? note,
      );

  /// Замер по результату калиперометрии.
  factory Measurement.fromBodyComposition({
    required DateTime date,
    required Profile profile,
    required BodyCompositionResult result,
    required Map<Skinfold, double> skinfolds,
    Map<Girth, double> girths = const {},
  }) =>
      Measurement(
        date: date,
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        age: profile.age,
        bodyFatPercent: result.fatPercent,
        fatKg: result.fatKg,
        leanKg: result.leanKg,
        muscleKg: result.muscleKg,
        skinfolds: skinfolds,
        girths: girths,
      );
}

/// Замер по расчёту рациона: масса, BMR, TDC и цель КБЖУ (и % жира, если BMR — по Каннингему).
Measurement measurementFromEnergy({required DateTime date, required Profile profile, required EnergyResult energy}) {
  final fat = energy.bmrMethod == BmrMethod.bodyFat ? profile.bodyFatPercent : null;
  return Measurement(
    date: date,
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    age: profile.age,
    bodyFatPercent: fat,
    fatKg: fat == null ? null : profile.weightKg * fat / 100,
    leanKg: fat == null ? null : leanMass(weightKg: profile.weightKg, fatPercent: fat),
    bmr: energy.bmr,
    bmrMethod: energy.bmrMethod,
    tdc: profile.includeTraining ? energy.tdcTraining : energy.tdcRest,
    target: energy.target,
  );
}

/// Показатели, по которым строится динамика.
enum Metric {
  weight('Масса тела', 'кг', 1),
  bodyFat('Процент жира', '%', 1),
  fatKg('Масса жира', 'кг', 1),
  leanKg('Безжировая масса (LBM)', 'кг', 1),
  muscleKg('Мышечная масса (МСМ)', 'кг', 1),
  skinfoldSum('Сумма складок', 'мм', 0),
  waist('Обхват талии', 'см', 1),
  hips('Обхват ягодиц', 'см', 1),
  chest('Обхват груди', 'см', 1),
  thigh('Обхват бедра', 'см', 1),
  calf('Обхват голени', 'см', 1),
  arm('Обхват плеча', 'см', 1),
  bmr('BMR', 'ккал', 0),
  tdc('TDC', 'ккал', 0),
  targetKcal('Цель на день', 'ккал', 0),
  protein('Белки', 'г', 0),
  fat('Жиры', 'г', 0),
  carbs('Углеводы', 'г', 0);

  final String label;
  final String unit;

  /// Знаков после запятой при выводе.
  final int digits;
  const Metric(this.label, this.unit, this.digits);

  double? of(Measurement m) => switch (this) {
        weight => m.weightKg,
        bodyFat => m.bodyFatPercent,
        fatKg => m.fatKg,
        leanKg => m.leanKg,
        muscleKg => m.muscleKg,
        skinfoldSum => m.skinfoldSum,
        waist => m.girths[Girth.waist],
        hips => m.girths[Girth.hips],
        chest => m.girths[Girth.chest],
        thigh => m.girths[Girth.thigh],
        calf => m.girths[Girth.calf],
        arm => m.girths[Girth.arm],
        bmr => m.bmr,
        tdc => m.tdc,
        targetKcal => m.target?.kcal,
        protein => m.target?.protein,
        fat => m.target?.fat,
        carbs => m.target?.carbs,
      };
}

/// Изменение показателя к предыдущему замеру, где он задан; null — сравнивать не с чем.
double? metricDelta(List<Measurement> sortedByDate, int index, Metric metric) {
  final current = metric.of(sortedByDate[index]);
  if (current == null) return null;
  for (var i = index - 1; i >= 0; i--) {
    final previous = metric.of(sortedByDate[i]);
    if (previous != null) return current - previous;
  }
  return null;
}
