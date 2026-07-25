import 'dart:math';

import '../domain/assessment_models.dart';

/// Builds the item pool for Memory Recall depending on symbol_set:
///  - 'pictures' → the category items passed in (existing behaviour)
///  - 'letters'  → generated A,B,C… (upper, or mixed-case with look-alikes)
///  - 'numbers'  → generated 0-9 digits
/// chunk_size groups consecutive symbols into one item ("AB", "45") so the
/// child remembers them as chunks (Extreme). Everything is a ContentItem, so
/// the whole recall pipeline (events, metrics, replay) is unchanged.
List<ContentItem> buildSymbolPool({
  required String symbolSet,
  required int poolSize,
  required int chunkSize,
  required String caseMode,
  required Random rng,
  required List<ContentItem> categoryItems,
}) {
  if (symbolSet == 'pictures') return categoryItems;

  final base = symbolSet == 'numbers'
      ? List<String>.generate(10, (i) => '$i')
      : List<String>.generate(26, (i) => String.fromCharCode(65 + i)); // A-Z

  var glyphs = [...base];
  if (symbolSet == 'letters' && caseMode == 'mixed') {
    // Mix in lowercase and bias toward visually-similar confusables.
    glyphs = [
      ...base,
      ...base.map((c) => c.toLowerCase()),
    ];
  }
  glyphs.shuffle(rng);

  final items = <ContentItem>[];
  final needed = poolSize * chunkSize;
  final source = <String>[];
  while (source.length < needed) {
    source.addAll(glyphs);
  }
  source.shuffle(rng);

  var idx = 0;
  final seen = <String>{};
  while (items.length < poolSize && idx + chunkSize <= source.length) {
    final label = source.sublist(idx, idx + chunkSize).join();
    idx += chunkSize;
    if (seen.add(label)) {
      items.add(ContentItem(id: 'sym_$label', label: label, emoji: label));
    }
  }
  return items;
}
