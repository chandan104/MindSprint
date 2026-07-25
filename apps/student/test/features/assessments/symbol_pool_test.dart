import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/features/assessments/domain/assessment_models.dart';
import 'package:mindsprint_student/features/assessments/memory_recall/symbol_pool.dart';

void main() {
  ContentItem item(String id) => ContentItem(id: id, label: id, emoji: '🐱');

  test('pictures passes through the category items unchanged', () {
    final cats = [item('a'), item('b'), item('c')];
    final pool = buildSymbolPool(
      symbolSet: 'pictures',
      poolSize: 6,
      chunkSize: 1,
      caseMode: 'upper',
      rng: Random(1),
      categoryItems: cats,
    );
    expect(pool, same(cats));
  });

  test('letters generates distinct uppercase items', () {
    final pool = buildSymbolPool(
      symbolSet: 'letters',
      poolSize: 8,
      chunkSize: 1,
      caseMode: 'upper',
      rng: Random(1),
      categoryItems: const [],
    );
    expect(pool.length, 8);
    expect(pool.map((e) => e.label).toSet().length, 8, reason: 'distinct');
    expect(pool.every((e) => RegExp(r'^[A-Z]$').hasMatch(e.label)), isTrue);
    // Emoji carries the glyph so ItemVisual renders the letter big.
    expect(pool.first.emoji, pool.first.label);
  });

  test('numbers generates distinct single digits', () {
    final pool = buildSymbolPool(
      symbolSet: 'numbers',
      poolSize: 8,
      chunkSize: 1,
      caseMode: 'upper',
      rng: Random(2),
      categoryItems: const [],
    );
    expect(pool.length, 8);
    expect(pool.every((e) => RegExp(r'^[0-9]$').hasMatch(e.label)), isTrue);
  });

  test('chunk_size groups symbols into multi-character items', () {
    final pool = buildSymbolPool(
      symbolSet: 'numbers',
      poolSize: 6,
      chunkSize: 2,
      caseMode: 'upper',
      rng: Random(3),
      categoryItems: const [],
    );
    expect(pool.length, 6);
    expect(pool.every((e) => e.label.length == 2), isTrue);
    expect(pool.map((e) => e.label).toSet().length, 6, reason: 'distinct chunks');
  });

  test('mixed case draws from both upper and lower letters', () {
    final pool = buildSymbolPool(
      symbolSet: 'letters',
      poolSize: 12,
      chunkSize: 1,
      caseMode: 'mixed',
      rng: Random(4),
      categoryItems: const [],
    );
    final hasLower = pool.any((e) => e.label == e.label.toLowerCase() && e.label != e.label.toUpperCase());
    expect(hasLower, isTrue);
  });
}
