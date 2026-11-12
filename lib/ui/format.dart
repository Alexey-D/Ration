/// Число с запятой в качестве десятичного разделителя (без «−0»).
String fmt(num value, [int digits = 0]) {
  final s = value.toStringAsFixed(digits);
  final clean = RegExp(r'^-0(\.0+)?$').hasMatch(s) ? s.substring(1) : s;
  return clean.replaceAll('.', ',');
}

/// Разбор числа, введённого с запятой или точкой.
double? parseNum(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Дата ДД.ММ.ГГГГ.
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Изменение со знаком: «+1,2», «−0,5», «0».
String fmtDelta(double delta, [int digits = 1]) {
  final s = fmt(delta.abs(), digits);
  if (s == fmt(0, digits)) return s;
  return delta > 0 ? '+$s' : '−$s';
}
