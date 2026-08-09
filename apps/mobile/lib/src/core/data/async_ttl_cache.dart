class AsyncTtlCache<T> {
  AsyncTtlCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  T? _value;
  DateTime? _expiresAt;
  Future<T>? _pending;

  Future<T> get(
    Duration duration,
    Future<T> Function() loader, {
    bool forceRefresh = false,
  }) {
    final value = _value;
    final expiresAt = _expiresAt;
    if (!forceRefresh &&
        value != null &&
        expiresAt != null &&
        _now().isBefore(expiresAt)) {
      return Future.value(value);
    }

    final pending = _pending;
    if (pending != null) return pending;

    final request = loader();
    _pending = request;
    return request
        .then((result) {
          _value = result;
          _expiresAt = _now().add(duration);
          return result;
        })
        .whenComplete(() => _pending = null);
  }

  void clear() {
    _value = null;
    _expiresAt = null;
  }
}
