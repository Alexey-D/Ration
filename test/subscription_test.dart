import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/domain/subscription.dart';

void main() {
  final t0 = DateTime(2026, 11, 1, 10);

  test('тариф: 1000 ₽ в месяц, 7 дней пробного периода', () {
    expect(monthlyPlan.priceRub, 1000);
    expect(monthlyPlan.periodDays, 30);
    expect(monthlyPlan.trialDays, 7);
  });

  test('пробный период: 7 дней доступа, даётся один раз', () {
    expect(Subscription.empty.status(t0), SubscriptionStatus.none);
    final s = Subscription.empty.startTrial(t0);
    expect(s.status(t0), SubscriptionStatus.trial);
    expect(s.hasAccess(t0), isTrue);
    expect(s.daysLeft(t0), 7);
    expect(s.daysLeft(t0.add(const Duration(days: 6, hours: 1))), 1);
    expect(s.status(t0.add(const Duration(days: 7))), SubscriptionStatus.expired);
    expect(s.hasAccess(t0.add(const Duration(days: 8))), isFalse);
    expect(s.trialAvailable, isFalse);
    expect(s.startTrial(t0.add(const Duration(days: 30))).trialStartedAt, t0); // повторно не начинается
  });

  test('оплата во время пробного периода начинается после него — дни не сгорают', () {
    final s = Subscription.empty.startTrial(t0).withPayment(now: t0.add(const Duration(days: 2)), paymentId: 'p1');
    final p = s.payments.single;
    expect(p.amountRub, 1000);
    expect(p.periodFrom, t0.add(const Duration(days: 7)));
    expect(p.periodTo, t0.add(const Duration(days: 37)));
    expect(s.status(t0.add(const Duration(days: 3))), SubscriptionStatus.active);
    expect(s.paidUntil, p.periodTo);
  });

  test('продление продлевает от конца оплаченного срока, после окончания — от даты оплаты', () {
    var s = Subscription.empty.withPayment(now: t0, paymentId: 'p1');
    expect(s.paidUntil, t0.add(const Duration(days: 30)));
    s = s.withPayment(now: t0.add(const Duration(days: 10)), paymentId: 'p2');
    expect(s.paidUntil, t0.add(const Duration(days: 60)));
    final late = t0.add(const Duration(days: 100));
    expect(s.status(late), SubscriptionStatus.expired);
    s = s.withPayment(now: late, paymentId: 'p3');
    expect(s.payments.last.periodFrom, late);
    expect(s.paidUntil, late.add(const Duration(days: 30)));
    expect(s.trialAvailable, isFalse); // после оплаты пробный период не положен
  });

  test('запись и чтение: подписка и согласия', () {
    final s = Subscription.empty
        .startTrial(t0)
        .withOfferAccepted(t0)
        .withPayment(now: t0, paymentId: 'DEMO-1')
        .withAutoRenew(false);
    final r = Subscription.decode(s.encode());
    expect(r.trialStartedAt, t0);
    expect(r.offerAcceptedAt, t0);
    expect(r.autoRenew, isFalse);
    expect(r.paidUntil, s.paidUntil);
    expect(r.payments.single.id, 'DEMO-1');
    expect(Subscription.decode('мусор').status(t0), SubscriptionStatus.none);
    expect(Subscription.decode(null).payments, isEmpty);

    final c = Consents.decode(Consents(privacyPolicyAt: t0, personalDataAt: t0).encode());
    expect(c.complete, isTrue);
    expect(Consents.decode('').complete, isFalse);
  });
}
