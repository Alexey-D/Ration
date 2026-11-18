import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/subscription.dart';
import '../state/providers.dart';
import 'format.dart';
import 'subscription_screen.dart' show fmtRub;

/// Имитация страницы платёжного сервиса. Карта не запрашивается, деньги не списываются:
/// когда будет выбран эквайринг, здесь откроется его страница оплаты, а приложение
/// получит подтверждение и зафиксирует оплату так же, как сейчас.
///
/// Возвращает [Payment] при успешной оплате, null — при отмене.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

enum _Stage { confirm, processing, done }

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _Stage _stage = _Stage.confirm;
  Payment? _payment;

  Future<void> _pay() async {
    setState(() => _stage = _Stage.processing);
    // ответ платёжного сервиса
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final id = 'DEMO-${ref.read(clockProvider)().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final payment = await ref.read(subscriptionProvider.notifier).recordPayment(id);
    if (!mounted) return;
    setState(() {
      _payment = payment;
      _stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = ref.watch(subscriptionProvider).valueOrNull ?? Subscription.empty;
    final now = ref.watch(clockProvider)();
    // какой период оплачивается — тот же расчёт, что при фиксации оплаты
    final preview = _payment ?? sub.withPayment(now: now, paymentId: '').payments.last;

    return PopScope(
      canPop: _stage != _Stage.processing,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: _stage == _Stage.confirm,
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Flexible(child: Text('Платёжный сервис', overflow: TextOverflow.ellipsis)),
          ]),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _DemoBanner(),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: switch (_stage) {
                      _Stage.done => _Done(payment: _payment!),
                      _ => _Order(
                          sub: sub,
                          payment: preview,
                          processing: _stage == _Stage.processing,
                          onPay: _pay,
                          onCancel: () => Navigator.of(context).pop(),
                        ),
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.science_outlined, color: color),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Демонстрационный режим: платёжный сервис ещё не подключён, '
            'данные карты не запрашиваются и деньги не списываются.',
          ),
        ),
      ]),
    );
  }
}

class _Order extends StatelessWidget {
  final Subscription sub;
  final Payment payment;
  final bool processing;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const _Order({
    required this.sub,
    required this.payment,
    required this.processing,
    required this.onPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ))),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: strong ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) : null,
              ),
            ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Оплата заказа', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      row('Получатель', 'Рацион (самозанятый, НПД)'),
      row('Назначение', 'Подписка «${sub.plan.name}»'),
      row('Период', '${fmtDate(payment.periodFrom)} – ${fmtDate(payment.periodTo)}'),
      const Divider(height: 24),
      row('К оплате', fmtRub(payment.amountRub), strong: true),
      const SizedBox(height: 20),
      FilledButton.icon(
        key: const Key('confirmPayment'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: processing ? null : onPay,
        icon: processing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lock_outline),
        label: Text(processing ? 'Проводим оплату…' : 'Оплатить ${fmtRub(payment.amountRub)}'),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: processing ? null : onCancel, child: const Text('Отменить и вернуться')),
      const SizedBox(height: 8),
      Text(
        'После оплаты чек формируется через «Мой налог» и направляется покупателю.',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

class _Done extends StatelessWidget {
  final Payment payment;
  const _Done({required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
      const SizedBox(height: 12),
      Text('Оплата прошла', key: const Key('paymentDone'), style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        '${fmtRub(payment.amountRub)} · подписка до ${fmtDate(payment.periodTo)}',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text('Номер платежа ${payment.id}', style: theme.textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        'Чек будет сформирован после подключения «Мой налог».',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      FilledButton(
        key: const Key('paymentBack'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () => Navigator.of(context).pop(payment),
        child: const Text('Вернуться в приложение'),
      ),
    ]);
  }
}
