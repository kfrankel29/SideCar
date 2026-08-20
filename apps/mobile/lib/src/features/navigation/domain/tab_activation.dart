import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainTabActivationController extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};

  void activate(int index) {
    state = {...state, index: (state[index] ?? 0) + 1};
  }
}

final mainTabActivationProvider =
    NotifierProvider<MainTabActivationController, Map<int, int>>(
      MainTabActivationController.new,
    );

final myRidesTabActivationProvider = Provider<int>(
  (ref) => ref.watch(mainTabActivationProvider)[2] ?? 0,
);

final homeTabActivationProvider = Provider<int>(
  (ref) => ref.watch(mainTabActivationProvider)[0] ?? 0,
);
