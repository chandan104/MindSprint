/// Session timing built on a monotonic clock.
///
/// Every recorded event carries `t_ms` — milliseconds since the session
/// started, measured by [Stopwatch], which is immune to wall-clock jumps
/// (NTP sync, timezone changes, manual clock edits). Wall-clock time is
/// captured once, at session start, purely as an anchor for humans reading
/// reports. Measurement accuracy is bounded by device input sampling
/// (~±10-20 ms); never compare t_ms across devices without the session's
/// device metadata.
abstract interface class TimingService {
  /// Starts (or restarts) the session clock and captures the wall-clock anchor.
  void start();

  bool get isRunning;

  /// Milliseconds since [start] on the monotonic clock.
  ///
  /// Throws [StateError] if the service was never started — recording an
  /// event with no running session clock is always a programming error.
  int get nowMs;

  /// Wall-clock moment [start] was called. Anchor only; never used for
  /// measurement arithmetic.
  DateTime get sessionStartWallClock;
}

class StopwatchTimingService implements TimingService {
  final Stopwatch _stopwatch = Stopwatch();
  DateTime? _startWallClock;

  @override
  void start() {
    _startWallClock = DateTime.now();
    _stopwatch
      ..reset()
      ..start();
  }

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  int get nowMs {
    if (_startWallClock == null) {
      throw StateError('TimingService.nowMs read before start()');
    }
    return _stopwatch.elapsedMilliseconds;
  }

  @override
  DateTime get sessionStartWallClock {
    final anchor = _startWallClock;
    if (anchor == null) {
      throw StateError('TimingService.sessionStartWallClock read before start()');
    }
    return anchor;
  }
}
