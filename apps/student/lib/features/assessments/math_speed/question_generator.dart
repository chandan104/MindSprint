import 'dart:math';

/// One generated arithmetic question with tappable answer options.
/// Everything shown to the child is captured here so event payloads are
/// self-contained (ADR-009).
class MathQuestion {
  final String text; // e.g. "7 + 5"
  final int answer;
  final List<int> options; // shuffled, contains the answer exactly once

  const MathQuestion({
    required this.text,
    required this.answer,
    required this.options,
  });
}

/// Generates integer-safe questions from a level config:
/// - sub never goes negative (child-appropriate),
/// - div always divides exactly (dividend = divisor × quotient),
/// - distractors are near-misses (±1..3 and digit-ish slips), never
///   duplicating the correct answer, always non-negative.
class MathQuestionGenerator {
  final List<String> operations;
  final int operandMin;
  final int operandMax;
  final Random _rng;

  static const int optionCount = 4;

  MathQuestionGenerator({
    required this.operations,
    required this.operandMin,
    required this.operandMax,
    Random? random,
  })  : assert(operations.isNotEmpty),
        _rng = random ?? Random();

  int _operand() => operandMin + _rng.nextInt(operandMax - operandMin + 1);

  MathQuestion next() {
    final op = operations[_rng.nextInt(operations.length)];
    late final int a;
    late final int b;
    late final int answer;
    late final String symbol;

    switch (op) {
      case 'add':
        a = _operand();
        b = _operand();
        answer = a + b;
        symbol = '+';
      case 'sub':
        final x = _operand();
        final y = _operand();
        a = max(x, y);
        b = min(x, y);
        answer = a - b;
        symbol = '−';
      case 'mul':
        a = _operand();
        b = _operand();
        answer = a * b;
        symbol = '×';
      case 'div':
        final divisor = max(1, _operand());
        final quotient = max(1, _operand());
        a = divisor * quotient;
        b = divisor;
        answer = quotient;
        symbol = '÷';
      default:
        throw ArgumentError('Unknown operation: $op');
    }

    final options = <int>{answer};
    var guard = 0;
    while (options.length < optionCount && guard < 100) {
      guard++;
      final delta = 1 + _rng.nextInt(3);
      final candidate = _rng.nextBool() ? answer + delta : answer - delta;
      if (candidate >= 0) options.add(candidate);
    }
    // Degenerate ranges (e.g. answer 0, all negatives rejected): pad upward.
    var pad = answer + 4;
    while (options.length < optionCount) {
      options.add(pad++);
    }

    final shuffled = options.toList()..shuffle(_rng);
    return MathQuestion(text: '$a $symbol $b', answer: answer, options: shuffled);
  }
}
