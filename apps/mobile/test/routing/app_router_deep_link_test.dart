import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/routing/app_router.dart';

void main() {
  test('recognizes current Stripe payout return link', () {
    expect(
      isStripeReturnLocation(Uri.parse('sidecar://app/stripe-redirect')),
      isTrue,
    );
  });

  test('recognizes the legacy Stripe payout return link', () {
    expect(
      isStripeReturnLocation(Uri.parse('sidecar://stripe-redirect/')),
      isTrue,
    );
  });

  test('does not intercept ride links', () {
    expect(
      isStripeReturnLocation(Uri.parse('sidecar://app/rides/ride-1')),
      isFalse,
    );
  });

  test('returns signed-in drivers to their account', () {
    expect(
      stripeReturnDestination(
        Uri.parse('sidecar://app/stripe-redirect'),
        signedIn: true,
      ),
      AppRoutes.account,
    );
  });

  test('returns signed-out devices to normal app startup', () {
    expect(
      stripeReturnDestination(
        Uri.parse('sidecar://app/stripe-redirect'),
        signedIn: false,
      ),
      AppRoutes.opening,
    );
  });
}
