import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/data/password_hasher.dart';
import 'package:ration_planner/data/seed.dart';
import 'package:ration_planner/domain/account.dart';
import 'package:ration_planner/domain/body_composition.dart';
import 'package:ration_planner/domain/energy_calculator.dart';
import 'package:ration_planner/domain/models.dart';

void main() {
  group('пароли', () {
    const hasher = PasswordHasher(iterations: 1000);

    test('верный пароль проходит, неверный — нет', () {
      final h = hasher.hash('секрет-123');
      expect(h, startsWith(r'pbkdf2-sha256$1000$'));
      expect(hasher.verify('секрет-123', h), isTrue);
      expect(hasher.verify('секрет-124', h), isFalse);
      expect(hasher.verify('секрет-123', 'мусор'), isFalse);
    });

    test('соль случайная — хэши одного пароля различаются', () {
      expect(hasher.hash('pass'), isNot(hasher.hash('pass')));
    });

    test('PBKDF2-HMAC-SHA256 совпадает с эталоном RFC 7914', () {
      // RFC 7914, п. 11: P="passwd", S="salt", c=1 → 55 ac 04 6e 56 e3 08 9f …
      const stored = r'pbkdf2-sha256$1$c2FsdA==$VawEblbjCJ/sFpHCJUS2BflBhSFt3gRl5oudV8INrLw=';
      expect(const PasswordHasher().verify('passwd', stored), isTrue);
    });
  });

  test('логин и пароль: правила', () {
    expect(validateLogin('ivan_2'), isNull);
    expect(validateLogin('iv'), isNotNull);
    expect(validateLogin('иван'), isNotNull);
    expect(validatePassword('123'), isNotNull);
    expect(validatePassword('1234'), isNull);
  });

  test('замеры за одну дату объединяются: новые значения заменяют, пустые не стирают', () {
    final caliper = Measurement(
      id: 7,
      date: DateTime(2026, 11, 1, 18, 30),
      weightKg: 100,
      bodyFatPercent: 20,
      girths: {Girth.thigh: 60},
      skinfolds: {Skinfold.abdomen: 10},
    );
    final ration = Measurement(date: DateTime(2026, 11, 1), weightKg: 99, bmr: 2000, girths: {Girth.waist: 90});
    final m = caliper.mergedWith(ration);
    expect(m.id, 7);
    expect(m.date, DateTime(2026, 11, 1));
    expect(m.weightKg, 99);
    expect(m.bodyFatPercent, 20);
    expect(m.bmr, 2000);
    expect(m.girths, {Girth.thigh: 60, Girth.waist: 90});
    expect(m.skinfoldSum, 10);
  });

  test('изменение к предыдущему замеру с этим показателем', () {
    final list = [
      Measurement(date: DateTime(2026, 1, 1), weightKg: 100, bodyFatPercent: 25),
      Measurement(date: DateTime(2026, 2, 1), weightKg: 98),
      Measurement(date: DateTime(2026, 3, 1), weightKg: 97, bodyFatPercent: 22),
    ];
    expect(metricDelta(list, 0, Metric.weight), isNull);
    expect(metricDelta(list, 2, Metric.weight), closeTo(-1, 1e-9));
    expect(metricDelta(list, 2, Metric.bodyFat), closeTo(-3, 1e-9)); // пропускает замер без % жира
    expect(metricDelta(list, 1, Metric.bodyFat), isNull);
  });

  test('замер по расчёту рациона: BMR, TDC, цель; % жира и LBM — при BMR по Каннингему', () {
    final mifflin = calculateEnergy(defaultProfile, metOf: (_) => 14);
    final m = measurementFromEnergy(date: DateTime(2026, 11, 11), profile: defaultProfile, energy: mifflin);
    expect(m.bmr, closeTo(2012.5, 1e-9));
    expect(m.tdc, closeTo(3164.7, 1e-9));
    expect(m.target!.kcal, closeTo(3164.7, 1e-9));
    expect(m.bodyFatPercent, isNull);

    final p = defaultProfile.copyWith(bmrMethod: BmrMethod.bodyFat, bodyFatPercent: 20, includeTraining: false);
    final c = measurementFromEnergy(date: DateTime(2026, 11, 11), profile: p, energy: calculateEnergy(p));
    expect(c.bmrMethod, BmrMethod.bodyFat);
    expect(c.leanKg, closeTo(81.6, 1e-9));
    expect(c.tdc, closeTo((500 + 22 * 81.6) * 1.2, 1e-9));
  });
}
