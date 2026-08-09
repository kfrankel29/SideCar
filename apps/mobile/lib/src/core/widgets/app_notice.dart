import 'package:flutter/material.dart';
import 'package:sidecar/src/theme/app_theme.dart';

final sideCarScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum AppNoticeKind { success, error, info }

void showAppNotice(
  BuildContext context,
  String message, {
  AppNoticeKind kind = AppNoticeKind.success,
}) {
  final messenger =
      sideCarScaffoldMessengerKey.currentState ??
      ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final isError = kind == AppNoticeKind.error;
  final icon = switch (kind) {
    AppNoticeKind.success => Icons.check_rounded,
    AppNoticeKind.error => Icons.error_outline_rounded,
    AppNoticeKind.info => Icons.info_outline_rounded,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'SideCar Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2400),
        dismissDirection: DismissDirection.down,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
