import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import '../domain/subscription.dart';
import '../state/providers.dart';
import 'app_logo.dart';
import 'legal.dart';
import 'theme_toggle.dart';

/// Вход и регистрация (локальные учётные записи).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  bool _privacyAccepted = false;
  bool _personalDataAccepted = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_login, _name, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    final error = _register
        ? await auth.register(
            login: _login.text,
            name: _name.text,
            password: _password.text,
            privacyPolicyAccepted: _privacyAccepted,
            personalDataAccepted: _personalDataAccepted,
          )
        : await auth.login(_login.text, _password.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(actions: const [ThemeToggleButton(), SizedBox(width: 16)]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: AppLogo(size: 46)),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Вход'), icon: Icon(Icons.login)),
                          ButtonSegment(value: true, label: Text('Регистрация'), icon: Icon(Icons.person_add_alt)),
                        ],
                        selected: {_register},
                        onSelectionChanged: (s) => setState(() {
                          _register = s.first;
                          _error = null;
                          // галочки создаются заново — сбрасываем и их значения
                          _privacyAccepted = false;
                          _personalDataAccepted = false;
                        }),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('loginField'),
                        controller: _login,
                        decoration: const InputDecoration(labelText: 'Логин', prefixIcon: Icon(Icons.person_outline)),
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        validator: (v) => _register ? validateLogin(v ?? '') : ((v ?? '').trim().isEmpty ? 'Введите логин' : null),
                      ),
                      if (_register) ...[
                        gap,
                        TextFormField(
                          key: const Key('nameField'),
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Имя',
                            helperText: 'Необязательно — как к вам обращаться',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                      gap,
                      TextFormField(
                        key: const Key('passwordField'),
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                        textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: _register ? null : (_) => _submit(),
                        validator: (v) => _register ? validatePassword(v ?? '') : ((v ?? '').isEmpty ? 'Введите пароль' : null),
                      ),
                      if (_register) ...[
                        gap,
                        TextFormField(
                          key: const Key('confirmField'),
                          controller: _confirm,
                          obscureText: !_showPassword,
                          decoration: const InputDecoration(labelText: 'Повторите пароль', prefixIcon: Icon(Icons.lock_outline)),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => v != _password.text ? 'Пароли не совпадают' : null,
                        ),
                        const SizedBox(height: 12),
                        ConsentCheckbox(
                          key: const Key('privacyConsent'),
                          parts: const [
                            ('Я ознакомлен(а) с ', null),
                            ('политикой конфиденциальности', LegalDocument.privacyPolicy),
                          ],
                          errorText: 'Нужно ознакомиться с политикой конфиденциальности',
                          onChanged: (v) => _privacyAccepted = v,
                        ),
                        ConsentCheckbox(
                          key: const Key('personalDataConsent'),
                          parts: const [
                            ('Даю ', null),
                            ('согласие на обработку персональных данных', LegalDocument.personalDataConsent),
                          ],
                          errorText: 'Без согласия на обработку персональных данных регистрация невозможна',
                          onChanged: (v) => _personalDataAccepted = v,
                        ),
                      ],
                      if (_error != null) ...[
                        gap,
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _busy ? null : _submit,
                        child: Text(_register ? 'Зарегистрироваться' : 'Войти'),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Учётные записи и история замеров хранятся только на этом устройстве.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const LegalFooter(documents: [LegalDocument.privacyPolicy, LegalDocument.personalDataConsent]),
            ]),
          ),
        ),
      ),
    );
  }
}
