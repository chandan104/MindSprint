import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../timing/timing_service.dart';

/// App-scoped infrastructure. Feature-level providers live with their
/// features; only cross-cutting singletons belong here.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// A fresh timing service per session run — never share a clock across
/// sessions. Features read this and call start() at session begin.
final timingServiceProvider = Provider.autoDispose<TimingService>((ref) {
  return StopwatchTimingService();
});
