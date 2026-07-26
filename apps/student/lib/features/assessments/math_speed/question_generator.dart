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
/// - distractors model the *miscalculations a child actually makes* — a
///   place-value slip (±10), an adjacent times-table row, an off-by-one, or a
///   wrong-operation result — so a wrong option can't be eliminated by rough
///   estimation; the answer must be computed. Padded with near-misses only if
///   the plausible-error pool is too small. Always distinct and non-negative.
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
    // Miscalculation foils, strongest first — a child who applies the wrong
    // rule lands on one of these, so options aren't estimatable-away.
    final foils = _plausibleFoils(op, a, b, answer)..shuffle(_rng);
    for (final candidate in foils) {
      if (options.length >= optionCount) break;
      if (candidate >= 0 && candidate != answer) options.add(candidate);
    }
    // Pad with near-misses if the plausible-error pool ran short.
    var delta = 1;
    while (options.length < optionCount && delta < 50) {
      final down = answer - delta;
      final up = answer + delta;
      if (down >= 0) options.add(down);
      if (options.length < optionCount) options.add(up);
      delta++;
    }

    final shuffled = options.toList()..shuffle(_rng);
    return MathQuestion(text: '$a $symbol $b', answer: answer, options: shuffled);
  }

  /// The specific wrong answers a child produces by mis-applying the operation.
  List<int> _plausibleFoils(String op, int a, int b, int answer) {
    switch (op) {
      case 'add':
        // carry/place-value slip, off-by-one, and "multiplied instead".
        return [answer + 10, answer - 10, answer + 1, answer - 1, a * b];
      case 'sub':
        // "added instead", borrow slip, off-by-one/ten.
        return [a + b, answer + 1, answer - 1, answer + 10, answer - 10];
      case 'mul':
        // adjacent times-table rows are the classic multiplication errors.
        return [a * (b + 1), a * (b - 1), (a + 1) * b, (a - 1) * b, answer + 10];
      case 'div':
        // off-by-one quotient, and confusing the divisor for the answer.
        return [answer + 1, answer - 1, answer + 2, b, a - b];
      default:
        return [answer + 1, answer - 1];
    }
  }
}
