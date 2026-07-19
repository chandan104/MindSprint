import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../assessments/data/content_repository_impl.dart';
import '../../assessments/domain/assessment_models.dart';
import '../../assessments/domain/content_repository.dart';
import '../../assessments/engine/assessment_module.dart';
import '../../assessments/engine/module_registry.dart';
import '../domain/session_args.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return SupabaseContentRepository(ref.watch(supabaseClientProvider));
});

final _levelsProvider = FutureProvider.autoDispose
    .family<List<AssessmentLevel>, String>((ref, moduleKey) {
  return ref.watch(contentRepositoryProvider).levelsForModule(moduleKey);
});

/// Teacher-facing: pick the assessment module and difficulty for the
/// confirmed student, then start. Fetches everything the session needs so
/// gameplay is network-free.
class AssessmentSetupScreen extends ConsumerStatefulWidget {
  final ConfirmedStudent student;
  const AssessmentSetupScreen({super.key, required this.student});

  @override
  ConsumerState<AssessmentSetupScreen> createState() =>
      _AssessmentSetupScreenState();
}

class _AssessmentSetupScreenState extends ConsumerState<AssessmentSetupScreen> {
  String? _selectedModuleKey;
  AssessmentLevel? _selectedLevel;
  bool _starting = false;
  String? _error;

  Future<void> _start() async {
    final level = _selectedLevel;
    if (level == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final categoryKey = level.config['category_key'] as String?;
      final items = categoryKey == null
          ? const <ContentItem>[]
          : await ref
              .read(contentRepositoryProvider)
              .itemsForCategory(categoryKey);

      if (items.length < _minItemsFor(level)) {
        setState(() {
          _starting = false;
          _error =
              'This level needs more items than the category currently has. '
              'Ask your admin to add items or pick another level.';
        });
        return;
      }

      if (!mounted) return;
      context.push(
        AppRoutes.session,
        extra: SessionRunArgs(
            student: widget.student, level: level, items: items),
      );
      setState(() => _starting = false);
    } on Failure catch (f) {
      setState(() {
        _starting = false;
        _error = f.message;
      });
    }
  }

  int _minItemsFor(AssessmentLevel level) {
    final grid = level.config['choice_grid_size'];
    final sequence = level.config['sequence_length'];
    if (grid is int) return grid;
    if (sequence is int) return sequence;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(enabledModulesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Assessment for ${widget.student.studentName}')),
      body: modules.isEmpty
          ? const Center(
              child: Text('No assessment modules are enabled.\n'
                  'Check feature flags with your admin.',
                  textAlign: TextAlign.center))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Choose an assessment',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final module in modules)
                  _ModuleCard(
                    module: module,
                    selected: _selectedModuleKey == module.moduleKey,
                    onTap: () => setState(() {
                      _selectedModuleKey = module.moduleKey;
                      _selectedLevel = null;
                    }),
                  ),
                if (_selectedModuleKey != null) ...[
                  const SizedBox(height: 16),
                  Text('Choose difficulty',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _DifficultyPicker(
                    moduleKey: _selectedModuleKey!,
                    selected: _selectedLevel,
                    onSelect: (level) => setState(() => _selectedLevel = level),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      _selectedLevel == null || _starting ? null : _start,
                  icon: _starting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: const Text('Start assessment'),
                ),
              ],
            ),
    );
  }
}

/// Game-catalogue card (prototype's "worlds"): gradient identity, emoji,
/// tagline — the module's public face on the teacher's setup screen.
class _ModuleCard extends StatelessWidget {
  final AssessmentModule module;
  final bool selected;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final identity = moduleIdentity(module.moduleKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusXl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? identity.gradient
                  : [AppTheme.surface, AppTheme.surface],
            ),
            borderRadius: AppTheme.radiusXl,
            border: Border.all(
              color: selected ? Colors.transparent : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.surfaceHigh,
                  borderRadius: AppTheme.radiusL,
                ),
                child: Center(
                    child: Text(identity.emoji,
                        style: const TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.displayName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      selected ? identity.world : identity.tagline,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppTheme.textDim,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? Colors.white : AppTheme.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyPicker extends ConsumerWidget {
  final String moduleKey;
  final AssessmentLevel? selected;
  final void Function(AssessmentLevel) onSelect;

  const _DifficultyPicker({
    required this.moduleKey,
    required this.selected,
    required this.onSelect,
  });

  static const _tierIcons = {
    'easy': Icons.sentiment_satisfied_outlined,
    'medium': Icons.sentiment_neutral_outlined,
    'hard': Icons.local_fire_department_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(_levelsProvider(moduleKey));
    return levels.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        children: [
          Text(error is Failure ? error.message : 'Could not load levels.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(_levelsProvider(moduleKey)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (items) => Column(
        children: [
          for (final level in items)
            Card(
              child: ListTile(
                leading: Icon(_tierIcons[level.difficulty] ?? Icons.circle),
                title: Text(
                    level.difficulty[0].toUpperCase() +
                        level.difficulty.substring(1),
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(level.name),
                selected: selected?.levelVersionId == level.levelVersionId,
                trailing: selected?.levelVersionId == level.levelVersionId
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => onSelect(level),
              ),
            ),
        ],
      ),
    );
  }
}
