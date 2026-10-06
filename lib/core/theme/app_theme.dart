import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF51318A);
  static const Color onPrimary = Colors.white;
  static const Color accent = Color(0xFF7955AF);
  static const Color black = Color(0xFF231C32);
  static const Color onSurface = Color(0xFF231C32);
  static const Color onSurfaceVariant = Color(0xFF625D70);
  static const Color surface = Color(0xFFF5F5F9);
  static const Color surfaceContainerHigh = Color(0xFFEAE7F1);
  static const Color surfaceTint = Color(0xFFF1ECF9);
  static const Color outline = Color(0xFFDEDDE7);
  static const Color mutedText = Color(0xFF625D70);
  static const Color danger = Color(0xFFB3261E);
  static const Color success = Color(0xFF146C4B);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    surface: Colors.white,
    onSurface: AppColors.onSurface,
    error: AppColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansDevanagariUI'],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    shape: WidgetStatePropertyAll(shape),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    ),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.outline),
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AppColors.onSurface,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleSmall: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 17,
            height: 1.5,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 15,
            height: 1.5,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 13,
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          labelMedium: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['NotoSansDevanagariUI'],
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        )
        .apply(
          fontFamily: 'Inter',
          fontFamilyFallback: ['NotoSansDevanagariUI'],
          bodyColor: AppColors.onSurface,
          displayColor: AppColors.onSurface,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button.copyWith(
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.outline),
        ),
        foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: button),
    textButtonTheme: TextButtonThemeData(style: button),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 14,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
      space: 24,
    ),
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selectedColor: AppColors.surfaceTint,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      constraints: const BoxConstraints(maxWidth: 640),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 23,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 15,
        height: 1.5,
        color: AppColors.onSurface,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      constraints: BoxConstraints(maxWidth: 720),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.onSurface,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 15,
        height: 1.4,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 15,
        color: AppColors.onSurfaceVariant,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 15,
        color: AppColors.onSurfaceVariant,
      ),
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AppColors.surfaceTint),
      headingRowHeight: 56,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 96,
      headingTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
      ),
      dataTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['NotoSansDevanagariUI'],
        fontSize: 14,
        color: AppColors.onSurface,
      ),
      columnSpacing: 24,
      horizontalMargin: 18,
      dividerThickness: .7,
    ),
  );
}
