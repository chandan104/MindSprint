import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/timing/timing_service.dart';

void main() {
  group('StopwatchTimingService', () {
    test('throws StateError when read before start', () {
      final timing = StopwatchTimingService();
      expect(() => timing.nowMs, throwsStateError);
      expect(() => timing.sessionStartWallClock, throwsStateError);
      expect(timing.isRunning, isFalse);
    });

    test('nowMs is monotonically non-decreasing', () async {
      final timing = StopwatchTimingService()..start();
      var previous = timing.nowMs;
      for (var i = 0; i < 200; i++) {
        final current = timing.nowMs;
        expect(current, greaterThanOrEqualTo(previous),
            reason: 'monotonic clock must never go backwards');
        previous = current;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(timing.nowMs, greaterThanOrEqualTo(previous + 15));
    });

    test('restart resets the clock to zero and refreshes the anchor', () async {
      final timing = StopwatchTimingService()..start();
      final firstAnchor = timing.sessionStartWallClock;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(timing.nowMs, greaterThanOrEqualTo(20));

      timing.start();
      expect(timing.nowMs, lessThan(20),
          reason: 'restart must reset elapsed time');
      expect(
        timing.sessionStartWallClock.isAfter(firstAnchor) ||
            timing.sessionStartWallClock.isAtSameMomentAs(firstAnchor),
        isTrue,
      );
    });

    test('isRunning reflects start', () {
      final timing = StopwatchTimingService();
      expect(timing.isRunning, isFalse);
      timing.start();
      expect(timing.isRunning, isTrue);
    });
  });
}
