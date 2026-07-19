import 'package:flutter/foundation.dart';

/// A playable level: one immutable level_version resolved with its parent
/// level's metadata. `config` is the raw JSONB validated against the module's
/// contract schema server-side; modules parse what they need.
@immutable
class AssessmentLevel {
  final String levelId;
  final String levelVersionId;
  final int version;
  final String moduleKey;
  final String name;
  final String difficulty; // 'easy' | 'medium' | 'hard'
  final Map<String, Object?> config;

  const AssessmentLevel({
    required this.levelId,
    required this.levelVersionId,
    required this.version,
    required this.moduleKey,
    required this.name,
    required this.difficulty,
    required this.config,
  });
}

/// A content item resolved for display. Visual preference order: emoji glyph
/// (data-driven, from media_assets.metadata), then a storage image path,
/// then the label's initial as last resort. Everything an event payload
/// needs to be self-contained lives here (ADR-009).
@immutable
class ContentItem {
  final String id;
  final String label;
  final String? emoji;
  final String? imagePath;

  const ContentItem({
    required this.id,
    required this.label,
    this.emoji,
    this.imagePath,
  });
}

/// How a run ended, from the module's perspective. The session layer decides
/// what to do with it (record session_completed vs session_aborted, compute
/// metrics, navigate).
enum AssessmentOutcome { completed, aborted }
