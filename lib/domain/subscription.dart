import 'dart:convert';

/// Тариф. Прототип: один тариф, цена и сроки — условные.
class Plan {
  final String id;
  final String name;
  final int priceRub;
  final int periodDays;
  final int trialDays;
  final List<String> features;

  const Plan({
    required this.id,
    required this.name,
    required this.priceRub,
    required this.periodDays,
    required this.trialDays,
    required this.features,
  });
}

const monthlyPlan = Plan(
  id: 'monthly',
  name: 'Рацион · Месяц',
  priceRub: 1000,
  periodDays: 30,
  trialDays: 7,
  features: [
    'Расчёт суточной нормы калорий: BMR по Миффлину — Сан Жеору или по Каннингему',
    'До трёх тренировок в день — справочник видов нагрузки (MET) или данные фитнес-браслета',
    'Цель: дефицит или профицит калорий, настройка БЖУ',
    'Подбор рациона на 2–6 приёмов пищи с заменой продуктов и пересчётом порций',
    'Калиперометрия: % жира, безжировая и мышечная масса',
    'Личный кабинет: история замеров, графики и таблица изменений',
  ],
);

enum SubscriptionStatus {
  /// Подписки не было и пробный период не начат.
  none('Нет подписки'),
  trial('Пробный период'),
  active('Подписка активна'),
  expired('Подписка закончилась');

  final String label;
  const SubscriptionStatus(this.label);
}

/// Оплата (в прототипе — демонстрационная, деньги не списываются).
class Payment {
  final String id;
  final DateTime paidAt;
  final int amountRub;
  final DateTime periodFrom;
  final DateTime periodTo;

  const Payment({
    required this.id,
    required this.paidAt,
    required this.amountRub,
    required this.periodFrom,
    required this.periodTo,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'paidAt': paidAt.toIso8601String(),
        'amount': amountRub,
        'from': periodFrom.toIso8601String(),
        'to': periodTo.toIso8601String(),
      };

  factory Payment.fromJson(Map<String, Object?> j) => Payment(
        id: j['id'] as String,
        paidAt: DateTime.parse(j['paidAt'] as String),
        amountRub: (j['amount'] as num).toInt(),
        periodFrom: DateTime.parse(j['from'] as String),
        periodTo: DateTime.parse(j['to'] as String),
      );
}

/// Подписка пользователя: пробный период, оплаченный срок, история оплат.
class Subscription {
  final String planId;
  final DateTime? trialStartedAt;
  final DateTime? paidUntil;
  final bool autoRenew;

  /// Когда пользователь принял оферту и правила подписки.
  final DateTime? offerAcceptedAt;
  final List<Payment> payments;

  const Subscription({
    this.planId = 'monthly',
    this.trialStartedAt,
    this.paidUntil,
    this.autoRenew = true,
    this.offerAcceptedAt,
    this.payments = const [],
  });

  static const empty = Subscription();

  Plan get plan => monthlyPlan;

  DateTime? get trialEndsAt => trialStartedAt?.add(Duration(days: plan.trialDays));

  SubscriptionStatus status(DateTime now) {
    if (paidUntil != null && now.isBefore(paidUntil!)) return SubscriptionStatus.active;
    if (trialEndsAt != null && now.isBefore(trialEndsAt!)) return SubscriptionStatus.trial;
    if (paidUntil == null && trialStartedAt == null) return SubscriptionStatus.none;
    return SubscriptionStatus.expired;
  }

  /// Доступ открыт: идёт пробный период или оплаченный срок.
  bool hasAccess(DateTime now) =>
      const {SubscriptionStatus.trial, SubscriptionStatus.active}.contains(status(now));

  /// До какого момента открыт доступ (null — доступа нет).
  DateTime? accessUntil(DateTime now) => switch (status(now)) {
        SubscriptionStatus.active => paidUntil,
        SubscriptionStatus.trial => trialEndsAt,
        _ => null,
      };

  /// Сколько полных и неполных дней доступа осталось.
  int daysLeft(DateTime now) {
    final until = accessUntil(now);
    if (until == null) return 0;
    return (until.difference(now).inHours / 24).ceil();
  }

  /// Пробный период даётся один раз.
  bool get trialAvailable => trialStartedAt == null && payments.isEmpty;

  Subscription startTrial(DateTime now) => trialAvailable ? _copy(trialStartedAt: now) : this;

  /// Оплата продлевает доступ на период тарифа: оплаченный срок начинается
  /// после текущего (оплаченного или пробного), а не сгорает.
  Subscription withPayment({required DateTime now, required String paymentId}) {
    final from = [now, ?accessUntil(now)].reduce((a, b) => a.isAfter(b) ? a : b);
    final to = from.add(Duration(days: plan.periodDays));
    return _copy(
      paidUntil: to,
      payments: [
        ...payments,
        Payment(id: paymentId, paidAt: now, amountRub: plan.priceRub, periodFrom: from, periodTo: to),
      ],
    );
  }

  Subscription withAutoRenew(bool value) => _copy(autoRenew: value);

  Subscription withOfferAccepted(DateTime now) => _copy(offerAcceptedAt: now);

  Subscription _copy({
    DateTime? trialStartedAt,
    DateTime? paidUntil,
    bool? autoRenew,
    DateTime? offerAcceptedAt,
    List<Payment>? payments,
  }) =>
      Subscription(
        planId: planId,
        trialStartedAt: trialStartedAt ?? this.trialStartedAt,
        paidUntil: paidUntil ?? this.paidUntil,
        autoRenew: autoRenew ?? this.autoRenew,
        offerAcceptedAt: offerAcceptedAt ?? this.offerAcceptedAt,
        payments: payments ?? this.payments,
      );

  String encode() => jsonEncode({
        'plan': planId,
        if (trialStartedAt != null) 'trialStartedAt': trialStartedAt!.toIso8601String(),
        if (paidUntil != null) 'paidUntil': paidUntil!.toIso8601String(),
        'autoRenew': autoRenew,
        if (offerAcceptedAt != null) 'offerAcceptedAt': offerAcceptedAt!.toIso8601String(),
        'payments': [for (final p in payments) p.toJson()],
      });

  /// Пустая или испорченная строка — подписки нет.
  static Subscription decode(String? text) {
    if (text == null || text.isEmpty) return empty;
    try {
      final j = jsonDecode(text) as Map<String, Object?>;
      DateTime? date(String key) => j[key] == null ? null : DateTime.parse(j[key] as String);
      return Subscription(
        planId: j['plan'] as String? ?? 'monthly',
        trialStartedAt: date('trialStartedAt'),
        paidUntil: date('paidUntil'),
        autoRenew: j['autoRenew'] as bool? ?? true,
        offerAcceptedAt: date('offerAcceptedAt'),
        payments: [
          for (final p in (j['payments'] as List? ?? const [])) Payment.fromJson((p as Map).cast<String, Object?>()),
        ],
      );
    } on Object {
      return empty;
    }
  }
}

/// Согласия пользователя, данные при регистрации.
class Consents {
  final DateTime? privacyPolicyAt;
  final DateTime? personalDataAt;

  const Consents({this.privacyPolicyAt, this.personalDataAt});

  bool get complete => privacyPolicyAt != null && personalDataAt != null;

  String encode() => jsonEncode({
        if (privacyPolicyAt != null) 'privacyPolicy': privacyPolicyAt!.toIso8601String(),
        if (personalDataAt != null) 'personalData': personalDataAt!.toIso8601String(),
      });

  static Consents decode(String? text) {
    if (text == null || text.isEmpty) return const Consents();
    try {
      final j = jsonDecode(text) as Map<String, Object?>;
      DateTime? date(String key) => j[key] == null ? null : DateTime.parse(j[key] as String);
      return Consents(privacyPolicyAt: date('privacyPolicy'), personalDataAt: date('personalData'));
    } on Object {
      return const Consents();
    }
  }
}

/// Юридические документы. В прототипе тексты ещё не готовы — ссылки-заглушки.
enum LegalDocument {
  offer('Публичная оферта'),
  subscriptionRules('Правила подписки'),
  privacyPolicy('Политика конфиденциальности'),
  personalDataConsent('Согласие на обработку персональных данных');

  final String title;
  const LegalDocument(this.title);
}
