import 'dart:math';

import '../domain/assessment_models.dart';

/// One pattern-completion question. The child sees [shown] followed by a
/// missing slot and picks the completing item from [options]. Everything
/// displayed is captured for self-contained event payloads (ADR-009).
class PatternQuestion {
  final String kind;
  final List<ContentItem> shown; // sequence minus the missing final slot
  final ContentItem answer;
  final List<ContentItem> options; // shuffled, contains answer exactly once

  const PatternQuestion({
    required this.kind,
    required this.shown,
    required this.answer,
    required this.options,
  });
}

/// Builds rule-following sequences from category items:
///   ab     → A B A B …
///   abc    → A B C A B C …
///   aabb   → A A B B A A B B …
///   abb    → A B B A B B …
///   mirror → first half mirrored (A B C C B A), completed by its palindrome
/// The missing slot is always the final position; distractor options are
/// other items from the motif's category pool.
class PatternGenerator {
  final List<String> kinds;
  final int sequenceLength;
  final int optionCount;
  final List<ContentItem> pool;
  final Random _rng;

  PatternGenerator({
    required this.kinds,
    required this.sequenceLength,
    required this.optionCount,
    required this.pool,
    Random? random,
  })  : assert(kinds.isNotEmpty),
        assert(pool.length >= 3),
        _rng = random ?? Random();

  List<ContentItem> _motif(int size) {
    final shuffled = [...pool]..shuffle(_rng);
    return shuffled.take(size).toList();
  }

  List<ContentItem> _sequenceFor(String kind) {
    switch (kind) {
      case 'ab':
        final m = _motif(2);
        return List.generate(sequenceLength, (i) => m[i % 2]);
      case 'abc':
        final m = _motif(3);
        return List.generate(sequenceLength, (i) => m[i % 3]);
      case 'aabb':
        final m = _motif(2);
        return List.generate(sequenceLength, (i) => m[(i ~/ 2) % 2]);
      case 'abb':
        final m = _motif(2);
        const cycle = [0, 1, 1];
        return List.generate(sequenceLength, (i) => m[cycle[i % 3]]);
      case 'mirror':
        final half = (sequenceLength + 1) ~/ 2;
        final m = _motif(min(half, pool.length));
        final motif = List.generate(half, (i) => m[i % m.length]);
        final full = [...motif, ...motif.reversed];
        return full.take(sequenceLength).toList();
      default:
        throw ArgumentError('Unknown pattern kind: $kind');
    }
  }

  PatternQuestion next() {
    final kind = kinds[_rng.nextInt(kinds.length)];
    final sequence = _sequenceFor(kind);
    final answer = sequence.last;
    final shown = sequence.sublist(0, sequence.length - 1);

    final options = <ContentItem>{answer};
    final distractorPool = [...pool]..shuffle(_rng);
    for (final candidate in distractorPool) {
      if (options.length >= optionCount) break;
      options.add(candidate);
    }
    final shuffledOptions = options.toList()..shuffle(_rng);

    return PatternQuestion(
      kind: kind,
      shown: shown,
      answer: answer,
      options: shuffledOptions,
    );
  }
}
