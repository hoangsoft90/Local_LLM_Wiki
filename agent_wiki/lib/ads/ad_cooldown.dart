/// Cooldown gate for interstitial ads: an ad may only be shown again after
/// [minInterval] has elapsed since the last show.
///
/// Pure Dart + injectable clock so it is unit-testable on the VM without any
/// platform channel. Keeps AdMob policy safe: never back-to-back ads.
class AdCooldown {
  AdCooldown({required this.minInterval, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Duration minInterval;
  final DateTime Function() _now;

  DateTime? _lastShown;

  /// True when an ad may be shown right now (never shown, or the interval
  /// since the last show has elapsed).
  bool get isReady =>
      _lastShown == null || _now().difference(_lastShown!) >= minInterval;

  /// Marks a show as having happened (call right before/after displaying).
  void markShown() => _lastShown = _now();

  /// Atomically claims the right to show: true when ready (and records the
  /// show), false when still inside the cooldown window.
  bool tryAcquire() {
    if (!isReady) return false;
    markShown();
    return true;
  }

  /// Exposed for tests/debugging.
  DateTime? get lastShown => _lastShown;
}
