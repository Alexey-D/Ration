import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/subscription.dart';
import '../state/providers.dart';
import 'account_screen.dart';
import 'format.dart';
import 'subscription_screen.dart';
import 'theme_toggle.dart';

/// Действия в шапке каждого экрана: личный кабинет / выход и переключатель темы.
class AppBarActions extends StatelessWidget {
  final double trailing;
  const AppBarActions({super.key, this.trailing = 8});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const AccountMenuButton(),
        const ThemeToggleButton(),
        SizedBox(width: trailing),
      ]);
}

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    final now = ref.watch(clockProvider)();
    final subStatus = sub == null
        ? null
        : switch (sub.status(now)) {
            SubscriptionStatus.trial || SubscriptionStatus.active =>
              '${sub.status(now).label} · до ${fmtDate(sub.accessUntil(now)!)}',
            final s => s.label,
          };
    return PopupMenuButton<_Action>(
      key: const Key('accountMenu'),
      tooltip: user.name,
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) async {
        switch (action) {
          case _Action.cabinet:
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
          case _Action.subscription:
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          case _Action.logout:
            // вернуться к первому экрану — его заменит экран входа
            Navigator.of(context).popUntil((r) => r.isFirst);
            await ref.read(authProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text('${user.name} (${user.login})', style: Theme.of(context).textTheme.bodySmall),
        ),
        const PopupMenuItem(
          value: _Action.cabinet,
          child: ListTile(leading: Icon(Icons.insights_outlined), title: Text('Личный кабинет')),
        ),
        PopupMenuItem(
          value: _Action.subscription,
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Подписка'),
            subtitle: subStatus == null ? null : Text(subStatus),
          ),
        ),
        const PopupMenuItem(
          value: _Action.logout,
          child: ListTile(leading: Icon(Icons.logout), title: Text('Выйти')),
        ),
      ],
    );
  }
}

enum _Action { cabinet, subscription, logout }
