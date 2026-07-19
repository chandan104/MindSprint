import 'package:flutter/material.dart';

import '../domain/assessment_models.dart';

/// Renders a content item's visual: data-driven emoji first, then a storage
/// image (arrives with the media pipeline), then the label's initial letter.
class ItemVisual extends StatelessWidget {
  final ContentItem item;
  final double size;

  const ItemVisual({super.key, required this.item, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final emoji = item.emoji;
    if (emoji != null && emoji.isNotEmpty) {
      return Text(
        emoji,
        style: TextStyle(fontSize: size, height: 1),
        semanticsLabel: item.label,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      child: Text(
        item.label.isEmpty ? '?' : item.label.characters.first,
        style: TextStyle(fontSize: size * 0.5),
        semanticsLabel: item.label,
      ),
    );
  }
}
