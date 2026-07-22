import 'dart:math';

/// One "what comes next" number-series question. Everything shown is captured
/// so event payloads stay self-contained (ADR-009).
class SeriesQuestion {
  final String kind; // 'next_in_series' | 'reverse_order'
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

/// Generates ordered number series that follow a rule (arithmetic step, or a
/// descending run for reverse_order), showing all but the final term and
/// asking for what comes next. Distractors are near-misses (±step, ±1),
/// always distinct and non-negative. Sequence reasoning, not visual pattern
/// matching — a genuinely different cognitive domain from Pattern Detective.
class SeriesGenerator {
  final List<String> kinds;
  final int sequenceLength; // total terms in the full series (>=3)
  final Random _rng;

  static const int optionCount = 3;

  SeriesGenerator({
    required this.kinds,
    required int sequenceLength,
    Random? random,
  })  : assert(kinds.isNotEmpty),
        sequenceLength = max(3, sequenceLength),
        _rng = random ?? Random();

  SeriesQuestion next() {
    final kind = kinds[_rng.nextInt(kinds.length)];
    final step = 1 + _rng.nextInt(9); // 1..9
    final ascending = kind != 'reverse_order';
    final start = ascending
        ? _rng.nextInt(10) // 0..9
        : sequenceLength * step + _rng.nextInt(10); // high enough to stay >=0

    final full = <int>[
      for (var i = 0; i < sequenceLength; i++)
        ascending ? start + i * step : start - i * step,
    ];
    final answer = full.last;
    final shown = full.sublist(0, full.length - 1);

    final options = <int>{answer};
    var guard = 0;
    while (options.length < optionCount && guard < 50) {
      guard++;
      final delta = _rng.nextBool() ? step : (1 + _rng.nextInt(2));
      final candidate = _rng.nextBool() ? answer + delta : answer - delta;
      if (candidate >= 0) options.add(candidate);
    }
    var pad = answer + step + 1;
    while (options.length < optionCount) {
      options.add(pad++);
    }

    final shuffled = options.toList()..shuffle(_rng);
    return SeriesQuestion(
        kind: kind, shown: shown, answer: answer, options: shuffled);
  }
}
