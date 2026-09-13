import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingAuthDestinationController extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String destination) => state = destination;

  String take({String fallback = '/home'}) {
    final destination = state;
    state = null;
    return destination == null || destination.isEmpty ? fallback : destination;
  }

  void clear() => state = null;
}

final pendingAuthDestinationProvider =
    NotifierProvider<PendingAuthDestinationController, String?>(
      PendingAuthDestinationController.new,
    );

String takePendingAuthDestination(WidgetRef ref, {String fallback = '/home'}) =>
    ref.read(pendingAuthDestinationProvider.notifier).take(fallback: fallback);
