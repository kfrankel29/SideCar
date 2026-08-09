import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  testWidgets('action notice appears and dismisses automatically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: sideCarScaffoldMessengerKey,
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppNotice(context, 'Ride cancelled.'),
              child: const Text('Run action'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Run action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ride cancelled.'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Ride cancelled.'), findsNothing);
  });
}
