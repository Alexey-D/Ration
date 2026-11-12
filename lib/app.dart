import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/app_logo.dart';
import 'ui/login_screen.dart';
import 'ui/profile_screen.dart';
import 'ui/theme.dart';

class RationApp extends ConsumerWidget {
  const RationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _AuthGate(),
    );
  }
}

/// Без входа — экран входа; после входа — расчёт (шаг 1) для этого пользователя.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(authProvider)) {
        AsyncData(value: final user?) => ProfileScreen(key: ValueKey(user.id)),
        AsyncData() || AsyncError() => const LoginScreen(),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      };
}

