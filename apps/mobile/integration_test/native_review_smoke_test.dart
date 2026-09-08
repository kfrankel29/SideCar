import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/platform/app_review.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native review channel is available', (tester) async {
    expect(await AppReview.request(), isTrue);
  });
}
