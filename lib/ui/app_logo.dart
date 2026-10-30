import 'dart:math' as math;

import 'package:flutter/material.dart';

enum LogoVariant {
  /// Тарелка-диаграмма: 5 секторов — 5 приёмов пищи.
  plate,

  /// Лист в круге.
  leaf,

  /// Буква «о» в названии заменена кольцом-тарелкой.
  ring,
}

/// Вариант логотипа для всего приложения — меняется здесь.
const kLogoVariant = LogoVariant.plate;

const kAppName = 'Рацион';
const kAppTagline = 'калории · БЖУ · порции';

class AppLogo extends StatelessWidget {
  /// Высота знака / кегль названия.
  final double size;
  final bool showTagline;
  final LogoVariant variant;

  const AppLogo({super.key, this.size = 40, this.showTagline = true, this.variant = kLogoVariant});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameStyle = TextStyle(
      fontSize: size * 0.8,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: size * 0.02,
      color: scheme.onSurface,
    );
    final tagline = Text(
      kAppTagline,
      style: TextStyle(fontSize: size * 0.3, letterSpacing: 1.2, color: scheme.primary),
    );

    final Widget title = switch (variant) {
      LogoVariant.ring => Text.rich(TextSpan(style: nameStyle, children: [
          const TextSpan(text: 'Раци'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.03),
              child: CustomPaint(
                size: Size.square(size * 0.5),
                painter: _RingPainter(scheme.primary),
              ),
            ),
          ),
          const TextSpan(text: 'н'),
        ])),
      _ => Text(kAppName, style: nameStyle),
    };

    final Widget? mark = switch (variant) {
      LogoVariant.plate => CustomPaint(size: Size.square(size), painter: _PlatePainter(scheme.primary)),
      LogoVariant.leaf => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary, width: size * 0.06),
          ),
          child: Icon(Icons.eco_outlined, size: size * 0.6, color: scheme.primary),
        ),
      LogoVariant.ring => null,
    };

    return Semantics(
      label: kAppName,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (mark != null) ...[mark, SizedBox(width: size * 0.3)],
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            if (showTagline) ...[SizedBox(height: size * 0.12), tagline],
          ],
        ),
      ]),
    );
  }
}

/// Только знак логотипа (тарелка) — для иконок приложения.
class AppLogoMark extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLogoMark({super.key, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _PlatePainter(color ?? Theme.of(context).colorScheme.primary),
      );
}

/// Кольцо с 5 секторами разной доли — как приёмы пищи в шаблоне рациона.
class _PlatePainter extends CustomPainter {
  final Color color;
  _PlatePainter(this.color);

  static const _shares = [25.0, 15.0, 29.0, 10.0, 21.0];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rim = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1;
    canvas.drawCircle(c, r - rim.strokeWidth / 2, rim);

    final band = r * 0.32;
    final arcRect = Rect.fromCircle(center: c, radius: r * 0.56);
    const gap = 0.12;
    final total = _shares.reduce((a, b) => a + b);
    var start = -math.pi / 2;
    for (final (i, share) in _shares.indexed) {
      final sweep = share / total * 2 * math.pi;
      canvas.drawArc(
        arcRect,
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = color.withValues(alpha: 1 - i * 0.17)
          ..style = PaintingStyle.stroke
          ..strokeWidth = band,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.color != color;
}

/// Кольцо-тарелка вместо буквы «о».
class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22;
    canvas.drawCircle(c, r - stroke.strokeWidth / 2, stroke);
    canvas.drawCircle(c, r * 0.3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
