import 'package:flutter/material.dart';

/// Акцент: зелёный в светлой теме, синий в тёмной.
const lightAccent = Color(0xFF2E7D32);
const darkAccent = Color(0xFF64B5F6);

/// Минималистичная тема: однотонный фон, все контуры — цветом акцента.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final accent = dark ? darkAccent : lightAccent;
  final background = dark ? const Color(0xFF121417) : Colors.white;
  final foreground = dark ? const Color(0xFFE8EAED) : const Color(0xFF1B1B1B);
  final soft = accent.withValues(alpha: dark ? 0.16 : 0.08);
  final error = dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: dark ? Colors.black : Colors.white,
    secondary: accent,
    onSecondary: dark ? Colors.black : Colors.white,
    tertiary: dark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
    onTertiary: Colors.black,
    error: error,
    onError: dark ? Colors.black : Colors.white,
    surface: background,
    onSurface: foreground,
    onSurfaceVariant: foreground.withValues(alpha: 0.7),
    outline: accent,
    outlineVariant: accent.withValues(alpha: 0.35),
    primaryContainer: soft,
    onPrimaryContainer: foreground,
    secondaryContainer: soft,
    onSecondaryContainer: foreground,
    surfaceContainerLowest: background,
    surfaceContainerLow: background,
    surfaceContainer: background,
    surfaceContainerHigh: background,
    surfaceContainerHighest: soft,
    surfaceTint: Colors.transparent,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  final outlined = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: accent),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: accent)),
    ),
    cardTheme: CardThemeData(
      color: background,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: outlined,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: outlined,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border(accent),
      enabledBorder: border(accent),
      focusedBorder: border(accent, 2),
      disabledBorder: border(accent.withValues(alpha: 0.3)),
      errorBorder: border(error),
      focusedErrorBorder: border(error, 2),
    ),
    dividerTheme: DividerThemeData(color: accent.withValues(alpha: 0.35)),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(soft),
      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: foreground),
    ),
    popupMenuTheme: PopupMenuThemeData(color: background, surfaceTintColor: Colors.transparent),
    expansionTileTheme: ExpansionTileThemeData(
      shape: outlined,
      collapsedShape: outlined,
      iconColor: accent,
      collapsedIconColor: accent,
    ),
  );
}
