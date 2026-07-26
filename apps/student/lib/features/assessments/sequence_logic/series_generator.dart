import 'dart:math';

/// One "what comes next" number-series question. Everything shown is captured
/// so event payloads stay self-contained (ADR-009).
class SeriesQuestion {
  final String kind; // rule family (see [SeriesGenerator])
  final List<int> shown; // the visible ordered run
  final int answer;
  final List<int> options; // shuffled, contains the answer exactly once

  const SeriesQuestion({
    required this.kind,
    required this.shown,
    required this.answer,
    required this.options,
  });
}

/// Generates number series that follow a rule and asks for the next term. The
/// rule families span more than one construct so the task can't be solved by a
/// single "constant difference" heuristic:
///   next_in_series / arrange_order → constant arithmetic step (ascending)
///   reverse_order                  → constant arithmetic step (descending)
///   geometric                      → constant ratio (×2, ×3)
///   fibonacci                      → each term = sum of the previous two
///   alternating                    → two interleaved step sizes (+a, +b, …)
///
/// Distractors are rule-relevant errors — counting one term too far, repeating
/// the previous term, or wrongly assuming a constant arithmetic step — so a
/// child can't win by eliminating obviously-unrelated numbers. Always distinct,
/// non-negative, and exactly [optionCount].
class SeriesGenerator {
  final List<String> kinds;
  final int sequenceLength; // total terms in the full series (>=3)
  final Random _rng;

  static const int optionCount = 4;

  SeriesGenerator({
    required this.kinds,
    required int sequenceLength,
    Random? random,
  })  : assert(kinds.isNotEmpty),
        sequenceLength = max(3, sequenceLength),
        _rng = random ?? Random();

  List<int> _buildSeries(String kind) {
    switch (kind) {
      case 'reverse_order':
        final step = 1 + _rng.nextInt(9);
        final start = sequenceLength * step + _rng.nextInt(10);
        return [for (var i = 0; i < sequenceLength; i++) start - i * step];
      case 'geometric':
        final ratio = 2 + _rng.nextInt(2); // ×2 or ×3
        final start = 1 + _rng.nextInt(4);
        return [
          for (var i = 0; i < sequenceLength; i++)
            start * pow(ratio, i).toInt(),
        ];
      case 'fibonacci':
        final a = 1 + _rng.nextInt(4);
        final b = a + _rng.nextInt(4); // b >= a keeps it ascending
        final series = <int>[a, b];
        while (series.length < sequenceLength) {
          series.add(series[series.length - 1] + series[series.length - 2]);
        }
        return series;
      case 'alternating':
        final da = 1 + _rng.nextInt(5);
        var db = 1 + _rng.nextInt(5);
        if (db == da) db += 1; // two *different* interleaved steps
        final start = _rng.nextInt(6);
        final series = <int>[start];
        for (var i = 1; i < sequenceLength; i++) {
          series.add(series.last + (i.isOdd ? da : db));
        }
        return series;
      case 'next_in_series':
      case 'arrange_order':
      default:
        final step = 1 + _rng.nextInt(9);
        final start = _rng.nextInt(10);
        return [for (var i = 0; i < sequenceLength; i++) start + i * step];
    }
  }

  /// Rule-relevant wrong answers, strongest first.
  List<int> _foils(List<int> full) {
    final n = full.length;
    final answer = full[n - 1];
    final gap = full[n - 1] - full[n - 2];
    return [
      answer + gap, // counted one term too far
      full[n - 2], // repeated the previous term
      if (n >= 3) full[n - 2] + (full[n - 2] - full[n - 3]), // assumed arithmetic
      answer + 1,
      answer - 1,
      answer + 2,
    ];
  }

  SeriesQuestion next() {
    final kind = kinds[_rng.nextInt(kinds.length)];
    final full = _buildSeries(kind);
    final answer = full.last;
    final shown = full.sublist(0, full.length - 1);

    final options = <int>{answer};
    for (final candidate in _foils(full)) {
      if (options.length >= optionCount) break;
      if (candidate >= 0 && candidate != answer) options.add(candidate);
    }
    var delta = 1;
    while (options.length < optionCount && delta < 50) {
      final down = answer - delta;
      final up = answer + delta;
      if (down >= 0) options.add(down);
      if (options.length < optionCount) options.add(up);
      delta++;
    }

    final shuffled = options.toList()..shuffle(_rng);
    return SeriesQuestion(
        kind: kind, shown: shown, answer: answer, options: shuffled);
  }
}
