import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/subscription.dart';
import '../state/providers.dart';
import 'account_button.dart';
import 'app_logo.dart';
import 'format.dart';
import 'legal.dart';
import 'payment_screen.dart';

/// «1 000 ₽»
String fmtRub(int rub) {
  final s = '$rub';
  final groups = <String>[];
  for (var end = s.length; end > 0; end -= 3) {
    groups.insert(0, s.substring(end - 3 < 0 ? 0 : end - 3, end));
  }
  return '${groups.join(' ')} ₽';
}

/// Подписка: статус, тариф, переход к оплате, история оплат.
/// Прототип — оплата демонстрационная, доступ к функциям не ограничивается.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const AppLogo(size: 30, showTagline: false),
          if (MediaQuery.sizeOf(context).width >= 600) ...[
            const SizedBox(width: 16),
            Container(width: 1, height: 28, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(width: 16),
            const Flexible(child: Text('Подписка', overflow: TextOverflow.ellipsis)),
          ],
        ]),
        actions: const [AppBarActions()],
      ),
      body: switch (sub) {
        AsyncData(:final value) => _Body(sub: value),
        AsyncError(:final error) => Center(child: Text('Ошибка загрузки подписки: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  final Subscription sub;
  const _Body({required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final status = _StatusCard(sub: sub, now: now);
    final plan = _PlanCard(sub: sub, now: now);
    final history = _PaymentHistory(payments: sub.payments);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 960;
      const gap = SizedBox(height: 16);
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: c.maxWidth >= 600 ? 32 : 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: plan),
                  const SizedBox(width: 24),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [status, gap, history])),
                ])
              else ...[status, gap, plan, gap, history],
              const SizedBox(height: 24),
              const LegalFooter(),
            ]),
          ),
        ),
      );
    });
  }
}

/// Текущий статус: пробный период / активна / закончилась, сколько осталось, автопродление.
class _StatusCard extends ConsumerWidget {
  final Subscription sub;
  final DateTime now;
  const _StatusCard({required this.sub, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = sub.status(now);
    final until = sub.accessUntil(now);
    final days = sub.daysLeft(now);
    final (icon, color) = switch (status) {
      SubscriptionStatus.active => (Icons.verified_outlined, theme.colorScheme.primary),
      SubscriptionStatus.trial => (Icons.hourglass_top, theme.colorScheme.tertiary),
      SubscriptionStatus.none => (Icons.lock_open_outlined, theme.colorScheme.onSurfaceVariant),
      SubscriptionStatus.expired => (Icons.lock_clock_outlined, theme.colorScheme.error),
    };
    final total = switch (status) {
      SubscriptionStatus.trial => sub.plan.trialDays,
      SubscriptionStatus.active => sub.payments.isEmpty
          ? sub.plan.periodDays
          : sub.paidUntil!.difference(sub.payments.last.periodFrom).inDays.clamp(1, 3650),
      _ => 0,
    };
    final subtitle = switch (status) {
      SubscriptionStatus.trial => 'Осталось ${_days(days)} · до ${fmtDate(until!)}',
      SubscriptionStatus.active => 'Оплачено до ${fmtDate(until!)} · осталось ${_days(days)}',
      SubscriptionStatus.none => 'Начните пробный период — ${_days(sub.plan.trialDays)} бесплатно',
      SubscriptionStatus.expired => 'Доступ закончился ${fmtDate(sub.paidUntil ?? sub.trialEndsAt!)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(status.label, key: const Key('subscriptionStatus'), style: theme.textTheme.titleLarge),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ]),
          if (total > 0) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (days / total).clamp(0, 1).toDouble(),
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          if (status == SubscriptionStatus.active) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('autoRenew'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Автопродление'),
              subtitle: Text(sub.autoRenew
                  ? 'Следующее списание ${fmtDate(sub.paidUntil!)} — ${fmtRub(sub.plan.priceRub)}'
                  : 'Подписка закончится ${fmtDate(sub.paidUntil!)} без списания'),
              value: sub.autoRenew,
              onChanged: (v) => ref.read(subscriptionProvider.notifier).setAutoRenew(v),
            ),
          ],
          if (status == SubscriptionStatus.trial) ...[
            const SizedBox(height: 12),
            Text(
              'После пробного периода подписка стоит ${fmtRub(sub.plan.priceRub)} в месяц. '
              'Оплатить можно заранее — оплаченный месяц начнётся после окончания пробного периода.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ]),
      ),
    );
  }
}

String _days(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'день'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
          ? 'дня'
          : 'дней';
  return '$n $word';
}

/// Тариф: цена, пробный период, что входит; согласие с офертой и кнопки.
class _PlanCard extends ConsumerStatefulWidget {
  final Subscription sub;
  final DateTime now;
  const _PlanCard({required this.sub, required this.now});

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  final _formKey = GlobalKey<FormState>();

  /// Оферту нужно принять один раз — дальше галочка не показывается.
  bool _confirmOffer() {
    if (widget.sub.offerAcceptedAt != null) return true;
    return _formKey.currentState!.validate();
  }

  Future<void> _startTrial() async {
    if (!_confirmOffer()) return;
    final notifier = ref.read(subscriptionProvider.notifier);
    if (widget.sub.offerAcceptedAt == null) await notifier.acceptOffer();
    await notifier.startTrial();
  }

  Future<void> _pay() async {
    if (!_confirmOffer()) return;
    if (widget.sub.offerAcceptedAt == null) await ref.read(subscriptionProvider.notifier).acceptOffer();
    if (!mounted) return;
    final paid = await Navigator.of(context).push<Payment>(MaterialPageRoute(builder: (_) => const PaymentScreen()));
    if (paid != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Оплата ${fmtRub(paid.amountRub)} зафиксирована · подписка до ${fmtDate(paid.periodTo)}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.sub;
    final plan = sub.plan;
    final status = sub.status(widget.now);
    final hasAccess = sub.hasAccess(widget.now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.workspace_premium_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Тариф «${plan.name}»', style: theme.textTheme.titleMedium)),
              if (sub.trialAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_days(plan.trialDays)} бесплатно',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.tertiary),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Text.rich(TextSpan(children: [
              TextSpan(
                text: fmtRub(plan.priceRub),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              TextSpan(text: '  в месяц', style: theme.textTheme.titleMedium),
            ])),
            Text(
              'Списание раз в ${_days(plan.periodDays)}, отменить автопродление можно в любой момент',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 32),
            Text('Что входит', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final f in plan.features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f)),
                ]),
              ),
            const SizedBox(height: 16),
            if (sub.offerAcceptedAt == null)
              ConsentCheckbox(
                key: const Key('offerConsent'),
                parts: const [
                  ('Принимаю условия ', null),
                  ('публичной оферты', LegalDocument.offer),
                  (' и ', null),
                  ('правил подписки', LegalDocument.subscriptionRules),
                ],
                errorText: 'Чтобы продолжить, примите условия оферты и правил подписки',
              )
            else
              Text(
                'Условия оферты и правил подписки приняты ${fmtDate(sub.offerAcceptedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('payButton'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _pay,
              icon: const Icon(Icons.credit_card),
              label: Text(
                status == SubscriptionStatus.active
                    ? 'Продлить на месяц — ${fmtRub(plan.priceRub)}'
                    : 'Оформить подписку — ${fmtRub(plan.priceRub)}',
              ),
            ),
            if (sub.trialAvailable && !hasAccess) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('trialButton'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _startTrial,
                icon: const Icon(Icons.hourglass_top),
                label: Text('Попробовать ${_days(plan.trialDays)} бесплатно'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Оплата проходит на стороне платёжного сервиса. Чек формируется через «Мой налог» '
              'и направляется покупателю.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PaymentHistory extends StatelessWidget {
  final List<Payment> payments;
  const _PaymentHistory({required this.payments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('История оплат', style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Text('Оплат пока не было.', style: theme.textTheme.bodyMedium)
          else
            for (final (i, p) in payments.reversed.indexed) ...[
              if (i > 0) const Divider(height: 20),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${fmtDate(p.paidAt)} · период ${fmtDate(p.periodFrom)} – ${fmtDate(p.periodTo)}'),
                    Text('№ ${p.id} · чек: будет сформирован после подключения «Мой налог»',
                        style: theme.textTheme.bodySmall),
                  ]),
                ),
                const SizedBox(width: 12),
                Text(fmtRub(p.amountRub), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ]),
            ],
        ]),
      ),
    );
  }
}
