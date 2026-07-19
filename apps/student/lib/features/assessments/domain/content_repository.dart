import 'assessment_models.dart';

abstract interface class ContentRepository {
  /// Latest version of every enabled level for a module, ordered
  /// easy → medium → hard then by rank.
  Future<List<AssessmentLevel>> levelsForModule(String moduleKey);

  /// Enabled items of a category with their resolved visuals.
  Future<List<ContentItem>> itemsForCategory(String categoryKey);
}
