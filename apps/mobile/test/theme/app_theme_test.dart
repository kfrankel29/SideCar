import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  test('Final Draft palette is the app-wide source of truth', () {
    expect(AppColors.ink, const Color(0xFF111111));
    expect(AppColors.primary, const Color(0xFF2F4979));
    expect(AppColors.ivory, const Color(0xFFFAF7F2));
    expect(AppColors.secondaryInk, const Color(0xFF8A8A8E));
    expect(AppColors.mutedInk, const Color(0xFF8A8A8E));
    expect(AppColors.border, const Color(0xFFE2E2E2));

    final theme = AppTheme.light;
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.surface, AppColors.ivory);
    expect(theme.scaffoldBackgroundColor, AppColors.ivory);
    expect(theme.appBarTheme.backgroundColor, AppColors.ivory);
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.ivory);
  });
}
