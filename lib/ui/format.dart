/// Число с запятой в качестве десятичного разделителя (без «−0»).
String fmt(num value, [int digits = 0]) {
  final s = value.toStringAsFixed(digits);
  final clean = RegExp(r'^-0(\.0+)?$').hasMatch(s) ? s.substring(1) : s;
  return clean.replaceAll('.', ',');
}

/// Разбор числа, введённого с запятой или точкой.
double? parseNum(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
