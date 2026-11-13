import 'package:flutter/material.dart';

/// Смысловые цвета — одинаковые на всех экранах: белки, жиры, углеводы
/// и составляющие суточного расхода энергии.
class Palette {
  final Color protein;
  final Color fat;
  final Color carbs;
  final Color bmr;
  final Color activity;
  final Color training;

  /// Фон карточек-разделов — нейтральный, чтобы разделы отличались от фона страницы.
  final Color section;

  const Palette._({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.bmr,
    required this.activity,
    required this.training,
    required this.section,
  });

  static Palette of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = Palette._(
    protein: Color(0xFFD81B60),
    fat: Color(0xFFF9A825),
    carbs: Color(0xFF00897B),
    bmr: Color(0xFF5C6BC0),
    activity: Color(0xFF9FA8DA),
    training: Color(0xFFEF6C00),
    section: Color(0xFFF4F6F4),
  );

  static const _dark = Palette._(
    protein: Color(0xFFF06292),
    fat: Color(0xFFFFD54F),
    carbs: Color(0xFF4DB6AC),
    bmr: Color(0xFF7986CB),
    activity: Color(0xFFB4BCE6),
    training: Color(0xFFFFB74D),
    section: Color(0xFF1B1E23),
  );
}
