import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../domain/assessment_models.dart';
import '../domain/content_repository.dart';

class SupabaseContentRepository implements ContentRepository {
  final SupabaseClient _client;
  SupabaseContentRepository(this._client);

  static const _tierOrder = {'easy': 0, 'medium': 1, 'hard': 2};

  @override
  Future<List<AssessmentLevel>> levelsForModule(String moduleKey) async {
    try {
      final rows = await _client
          .from('levels')
          .select('id, module_key, name, difficulty, difficulty_rank, '
              'level_versions(id, version, config)')
          .eq('module_key', moduleKey)
          .eq('enabled', true);

      final levels = <AssessmentLevel>[];
      for (final row in rows) {
        final versions = (row['level_versions'] as List?) ?? const [];
        if (versions.isEmpty) continue; // a level without versions is unplayable
        final latest = versions.cast<Map<String, dynamic>>().reduce(
            (a, b) => (a['version'] as int) >= (b['version'] as int) ? a : b);
        levels.add(AssessmentLevel(
          levelId: row['id'] as String,
          levelVersionId: latest['id'] as String,
          version: latest['version'] as int,
          moduleKey: row['module_key'] as String,
          name: row['name'] as String,
          difficulty: row['difficulty'] as String,
          config: Map<String, Object?>.from(latest['config'] as Map),
        ));
      }
      levels.sort((a, b) {
        final tier = (_tierOrder[a.difficulty] ?? 9)
            .compareTo(_tierOrder[b.difficulty] ?? 9);
        return tier != 0 ? tier : a.name.compareTo(b.name);
      });
      return levels;
    } on SocketException {
      throw const NetworkFailure();
    } on PostgrestException catch (e) {
      throw UnknownFailure('Could not load levels: ${e.message}');
    }
  }

  @override
  Future<List<ContentItem>> itemsForCategory(String categoryKey) async {
    try {
      final rows = await _client
          .from('category_items')
          .select('id, label, categories!inner(key, enabled), '
              'media_assets(storage_path, metadata)')
          .eq('categories.key', categoryKey)
          .eq('categories.enabled', true)
          .order('label');

      return [
        for (final row in rows)
          ContentItem(
            id: row['id'] as String,
            label: row['label'] as String,
            emoji: ((row['media_assets'] as Map?)?['metadata']
                as Map?)?['emoji'] as String?,
            imagePath:
                (row['media_assets'] as Map?)?['storage_path'] as String?,
          ),
      ];
    } on SocketException {
      throw const NetworkFailure();
    } on PostgrestException catch (e) {
      throw UnknownFailure('Could not load category items: ${e.message}');
    }
  }
}
