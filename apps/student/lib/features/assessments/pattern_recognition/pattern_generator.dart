import 'dart:math';

import '../domain/assessment_models.dart';

/// One pattern-completion question. The child sees [full] with the item at
/// [blankIndex] hidden and picks the completing item from [options].
/// Everything displayed is captured for self-contained event payloads
/// (ADR-009); [shown] is the visible row (full minus the blank).
class PatternQuestion {
  final String kind;
  final List<ContentItem> full; // the complete rule-following sequence
  final int blankIndex; // position of the hidden item
  final ContentItem answer;
  final List<ContentItem> options; // shuffled, contains answer exactly once

  const PatternQuestion({
    required this.kind,
    required this.full,
    required this.blankIndex,
    required this.answer,
    required this.options,
  });

  /// The visible row in order, with the blank position removed.
  List<ContentItem> get shown => [
        for (var i = 0; i < full.length; i++)
          if (i != blankIndex) full[i],
      ];
}

/// Builds rule-following sequences from category items:
///   ab     → A B A B …
///   abc    → A B C A B C …
///   aabb   → A A B B A A B B …
///   abb    → A B B A B B …
///   mirror → first half mirrored (A B C C B A), a palindrome
///
/// The hidden slot is NOT fixed at the end: it is placed at a position that
/// still leaves the rule inferable (a full period of context for periodic
/// kinds; any non-self-mirror position for palindromes). This forces the child
/// to apply the *rule* rather than merely extrapolate the last item.
///
/// Distractors are rule-based foils drawn from the sequence's own motif — the
/// "repeat the neighbour" naive error and other wrong-slot motif members —
/// topped up with wider-pool items. Random-unrelated options (which let a child
/// win by rhythm/elimination) are avoided.
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

  /// The repeating period of a kind, or 0 for non-periodic (mirror).
  int _period(String kind) => switch (kind) {
        'ab' => 2,
        'abc' => 3,
        'aabb' => 4,
        'abb' => 3,
        _ => 0,
      };

  int _blankIndexFor(String kind, List<ContentItem> full) {
    final n = full.length;
    if (kind == 'mirror') {
      // Any position whose mirror partner is a *different* (visible) slot, so
      // the answer is recoverable — never the self-mirroring centre.
      final valid = [
        for (var i = 0; i < n; i++)
          if (i != n - 1 - i) i,
      ];
      return valid[_rng.nextInt(valid.length)];
    }
    final p = _period(kind);
    // Leave at least one full period of context before the blank.
    if (p > 0 && n > p) return p + _rng.nextInt(n - p);
    return n - 1;
  }

  PatternQuestion next() {
    final kind = kinds[_rng.nextInt(kinds.length)];
    final full = _sequenceFor(kind);
    final blankIndex = _blankIndexFor(kind, full);
    final answer = full[blankIndex];

    // Rule-based foils first: plausible-but-wrong answers a child produces by
    // applying the wrong rule, so success requires the *right* rule.
    final options = <ContentItem>{answer};
    void tryAdd(ContentItem? c) {
      if (c != null && c.id != answer.id) options.add(c);
    }

    // "Repeat the neighbour" — the classic naive-continuation error.
    if (blankIndex > 0) tryAdd(full[blankIndex - 1]);
    // Other motif members in the wrong slot (belong to the pattern, wrong here).
    final motif = full.map((e) => e.id).toSet();
    final motifMembers = [
      for (final item in full)
        if (options.every((o) => o.id != item.id)) item,
    ]..shuffle(_rng);
    for (final m in motifMembers) {
      if (options.length >= optionCount) break;
      tryAdd(m);
    }
    // Top up from the wider pool if the motif is too small for the option count.
    final fillers = [
      for (final p in pool)
        if (!motif.contains(p.id)) p,
    ]..shuffle(_rng);
    for (final f in fillers) {
      if (options.length >= optionCount) break;
      tryAdd(f);
    }

    final shuffledOptions = options.toList()..shuffle(_rng);
    return PatternQuestion(
      kind: kind,
      full: full,
      blankIndex: blankIndex,
      answer: answer,
      options: shuffledOptions,
    );
  }
}
