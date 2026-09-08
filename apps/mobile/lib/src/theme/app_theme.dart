import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const ink = Color(0xFF111111);
  static const primary = Color(0xFF2F4979);
  static const ivory = Color(0xFFFAF7F2);
  static const secondaryInk = Color(0xFF8A8A8E);
  static const mutedInk = Color(0xFF8A8A8E);
  static const border = Color(0xFFE2E2E2);
  static const softBorder = Color(0xFFE5E5E5);
  static const softSurface = Color(0xFFF2F2F2);
  static const information = Color(0xFFE8F1FB);
  static const success = Color(0xFFE7F3EB);
  static const warning = Color(0xFFFCF3E3);
  static const danger = Color(0xFFE33A3A);
  static const dangerSurface = Color(0xFFF9E2DE);
  static const strongSecondaryInk = Color(0xFF4D4D4D);
  static const tertiaryInk = Color(0xFF6E6E73);
  static const disabled = Color(0xFFE5E5E5);
}

abstract final class AppButtonStyles {
  static final primaryFilled = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.disabled,
    disabledForegroundColor: Colors.white,
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.ivory,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ivory,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Arial',
          color: AppColors.ink,
          fontSize: 40,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Arial',
          color: AppColors.ink,
          fontSize: 33,
          height: 1.08,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Arial',
          color: AppColors.ink,
          fontSize: 26,
          height: 1.08,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Arial',
          color: AppColors.ink,
          fontSize: 27,
          height: 1.1,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: AppColors.secondaryInk,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: TextStyle(
          color: AppColors.mutedInk,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: const TextStyle(
          color: AppColors.mutedInk,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(color: AppColors.primary, width: 1.4),
        errorBorder: _border(color: AppColors.danger),
        focusedErrorBorder: _border(color: AppColors.danger, width: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          enableFeedback: false,
          minimumSize: const Size.fromHeight(48),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          enableFeedback: false,
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enableFeedback: false,
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(enableFeedback: false),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => Image.asset(
          'assets/icons/figma/back.png',
          width: 24,
          height: 24,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.ivory,
        indicatorColor: AppColors.primary.withValues(alpha: .12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.mutedInk,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: AppColors.ivory,
        showDragHandle: true,
      ),
    );
  }

  static OutlineInputBorder _border({
    Color color = AppColors.border,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
