import 'package:flutter/material.dart';

import '../domain/subscription.dart';

/// Документ-заглушка: тексты оферты, правил и политик ещё не готовы.
Future<void> showLegalDocument(BuildContext context, LegalDocument document) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('legalDialog'),
        icon: const Icon(Icons.description_outlined),
        title: Text(document.title),
        content: const SizedBox(
          width: 480,
          child: Text(
            'Текст документа готовится и будет опубликован до запуска платной версии.\n\n'
            'Сейчас это заглушка прототипа: ссылка показывает, где пользователь сможет '
            'ознакомиться с документом.',
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Закрыть')),
        ],
      ),
    );

/// Ссылка на документ внутри текста.
class LegalLink extends StatelessWidget {
  final LegalDocument document;

  /// Текст ссылки; по умолчанию — название документа.
  final String? text;
  final TextStyle? style;

  const LegalLink(this.document, {super.key, this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showLegalDocument(context, document),
        child: Text(
          text ?? document.title,
          style: (style ?? DefaultTextStyle.of(context).style).copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

/// Часть подписи к галочке: обычный текст или ссылка на документ.
typedef ConsentPart = (String text, LegalDocument? link);

/// Обязательная галочка согласия: без неё форма не проходит проверку.
class ConsentCheckbox extends FormField<bool> {
  ConsentCheckbox({
    super.key,
    required List<ConsentPart> parts,
    required String errorText,
    ValueChanged<bool>? onChanged,
  }) : super(
          initialValue: false,
          validator: (v) => v == true ? null : errorText,
          builder: (state) {
            final context = state.context;
            final theme = Theme.of(context);
            final style = theme.textTheme.bodyMedium;
            void toggle(bool? v) {
              state.didChange(v ?? false);
              onChanged?.call(v ?? false);
            }

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(value: state.value ?? false, onChanged: toggle),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text.rich(TextSpan(style: style, children: [
                      for (final (text, link) in parts)
                        link == null
                            ? TextSpan(text: text)
                            : WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: LegalLink(link, text: text, style: style),
                              ),
                    ])),
                  ),
                ),
              ]),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 52, top: 2),
                  child: Text(
                    state.errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
            ]);
          },
        );
}

/// Строка ссылок на все документы — в подвале экранов.
class LegalFooter extends StatelessWidget {
  final List<LegalDocument> documents;
  const LegalFooter({super.key, this.documents = LegalDocument.values});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [for (final d in documents) LegalLink(d, style: style)],
    );
  }
}
