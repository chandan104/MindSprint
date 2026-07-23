import 'package:flutter/widgets.dart';

import '../../../core/timing/timing_service.dart';
import '../domain/assessment_models.dart';
import 'session_recorder.dart';

/// Everything a module needs to run one assessment, handed to it by the
/// session layer. Modules own their gameplay UI and event emission; they do
/// NOT own session lifecycle events (session_started/completed/aborted are
/// recorded by the session layer) and they never touch the network.
class AssessmentRunContext {
  final AssessmentLevel level;

  /// Content items resolved for this level (e.g. the category's items for
  /// Memory Recall). Modules must embed displayed item data into event
  /// payloads so replay never needs a content lookup.
  final List<ContentItem> items;

  final SessionRecorder recorder;
  final TimingService timing;

  /// Called exactly once when gameplay finishes. The session layer records
  /// the terminal event, computes provisional metrics, and navigates.
  final void Function(AssessmentOutcome outcome) onFinished;

  const AssessmentRunContext({
    required this.level,
    required this.items,
    required this.recorder,
    required this.timing,
    required this.onFinished,
  });
}

/// The plug-in contract (ADR-010). A module implements exactly one method:
/// build the widget that runs the assessment for the given context. Adding a
/// future module means implementing this and adding one registry entry —
/// no engine, recorder, or sync changes.
abstract interface class AssessmentModule {
  String get moduleKey;

  /// Human-readable name shown on the setup screen (module display names in
  /// the database are authoritative for admin surfaces; this is the
  /// in-gameplay fallback).
  String get displayName;

  /// Whether this module draws its stimuli from a picture category. Modules
  /// that generate their own content (numbers, arithmetic) return false, so
  /// the setup screen does not gate them on category item counts.
  bool get requiresContentItems;

  Widget buildRunner(AssessmentRunContext context);
}
