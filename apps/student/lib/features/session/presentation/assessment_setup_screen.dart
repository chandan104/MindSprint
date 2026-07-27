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

// ── Cognitive-domain grouping (display only; never affects measurement) ──────
const _domainOrder = [
  'working_memory',
  'attention',
  'selective_attention',
  'processing_speed',
  'reasoning',
];
const _domainLabels = {
  'working_memory': 'Working Memory',
  'attention': 'Attention',
  'selective_attention': 'Selective Attention',
  'processing_speed': 'Processing Speed',
  'reasoning': 'Reasoning',
};
const _moduleDomain = {
  'memory_recall': 'working_memory',
  'attention_focus': 'attention',
  'visual_search': 'attention',
  'color_selector': 'selective_attention',
  'math_speed': 'processing_speed',
  'pattern_recognition': 'reasoning',
  'sequence_logic': 'reasoning',
};

// ── Tier + category helpers (level names are "Category — Tier") ──────────────
String _tierOf(AssessmentLevel l) {
  final idx = l.name.lastIndexOf('—');
  if (idx != -1) {
    final t = l.name.substring(idx + 1).trim();
    if (t.isNotEmpty) return t;
  }
  return l.difficulty.isEmpty
      ? 'Level'
      : l.difficulty[0].toUpperCase() + l.difficulty.substring(1);
}

int _tierRank(String tier) =>
    const {'easy': 0, 'medium': 1, 'hard': 2, 'extreme': 3}[tier.toLowerCase()] ??
    1;

String _categoryOf(AssessmentLevel l) {
  final symbolSet = l.config['symbol_set'] as String?;
  if (symbolSet == 'letters') return 'Alphabet';
  if (symbolSet == 'numbers') return 'Numbers';
  final cat = l.config['category_key'] as String?;
  if (cat != null && cat.isNotEmpty) {
    return cat[0].toUpperCase() + cat.substring(1);
  }
  final idx = l.name.indexOf('—');
  return idx != -1 ? l.name.substring(0, idx).trim() : l.name;
}

String _categoryEmoji(String category) => switch (category.toLowerCase()) {
      'animals' => '🐾',
      'fruits' => '🍎',
      'shapes' => '🔷',
      'alphabet' => '🔤',
      'numbers' => '🔢',
      _ => '🎯',
    };

IconData _tierIcon(String tier) => switch (tier.toLowerCase()) {
      'easy' => Icons.sentiment_very_satisfied_outlined,
      'medium' => Icons.sentiment_neutral_outlined,
      'hard' => Icons.local_fire_department_outlined,
      'extreme' => Icons.whatshot,
      _ => Icons.circle_outlined,
    };

Color _tierColor(String tier) => switch (tier.toLowerCase()) {
      'easy' => const Color(0xFF34D399), // emerald
      'medium' => const Color(0xFFFBBF24), // amber
      'hard' => const Color(0xFFFB923C), // orange
      'extreme' => const Color(0xFFF87171), // red
      _ => AppTheme.textDim,
    };

String _tierBlurb(String tier) => switch (tier.toLowerCase()) {
      'easy' => 'A gentle warm-up.',
      'medium' => 'A step up — steady focus.',
      'hard' => 'Fast and demanding.',
      'extreme' => 'Maximum challenge.',
      _ => '',
    };

enum _Step { module, category, difficulty }

/// Teacher-facing setup: pick assessment → (category) → difficulty → start.
/// A guided, stepped flow — pick a game and you are taken straight to its
/// difficulty options. Fetches everything the session needs so gameplay is
/// network-free. Analytics/measurement are untouched.
class AssessmentSetupScreen extends ConsumerStatefulWidget {
  final ConfirmedStudent student;
  const AssessmentSetupScreen({super.key, required this.student});

  @override
  ConsumerState<AssessmentSetupScreen> createState() =>
      _AssessmentSetupScreenState();
}

class _AssessmentSetupScreenState extends ConsumerState<AssessmentSetupScreen> {
  _Step _step = _Step.module;
  AssessmentModule? _module;
  String? _category; // Memory Recall only
  AssessmentLevel? _level;
  bool _starting = false;
  String? _error;

  bool get _moduleHasCategories => _module?.moduleKey == 'memory_recall';

  void _selectModule(AssessmentModule module) {
    setState(() {
      _module = module;
      _category = null;
      _level = null;
      _error = null;
      // Selecting a game takes you straight on — to its categories (Memory
      // Recall) or directly to its difficulty options.
      _step = module.moduleKey == 'memory_recall'
          ? _Step.category
          : _Step.difficulty;
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _level = null;
      _error = null;
      _step = _Step.difficulty;
    });
  }

  void _back() {
    switch (_step) {
      case _Step.module:
        context.pop();
      case _Step.category:
        setState(() {
          _step = _Step.module;
          _module = null;
        });
      case _Step.difficulty:
        setState(() {
          _level = null;
          _error = null;
          _step = _moduleHasCategories ? _Step.category : _Step.module;
          if (!_moduleHasCategories) _module = null;
        });
    }
  }

  Future<void> _start() async {
    final level = _level;
    if (level == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Generative modules make their own stimuli and need no picture category.
      // Memory Recall with a letters/numbers symbol_set is likewise generated.
      final module = moduleForKey(level.moduleKey);
      final symbolSet = level.config['symbol_set'] as String?;
      final generatedSymbols = symbolSet == 'letters' || symbolSet == 'numbers';
      final needsItems =
          (module?.requiresContentItems ?? true) && !generatedSymbols;

      final categoryKey = level.config['category_key'] as String?;
      final items = (!needsItems || categoryKey == null)
          ? const <ContentItem>[]
          : await ref
              .read(contentRepositoryProvider)
              .itemsForCategory(categoryKey);

      if (needsItems && items.length < _minItemsFor(level)) {
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

  String get _title => switch (_step) {
        _Step.module => 'Select an Assessment',
        _Step.category => 'Select a Category',
        _Step.difficulty => 'Select a Difficulty',
      };

  String get _subtitle => switch (_step) {
        _Step.module => 'Choose a game for ${widget.student.studentName}.',
        _Step.category =>
          'Pick what ${widget.student.studentName} will remember.',
        _Step.difficulty => _module == null
            ? ''
            : 'How challenging should ${_module!.displayName} be?',
      };

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(enabledModulesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Assessment for ${widget.student.studentName}'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(step: _step, title: _title, subtitle: _subtitle),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _buildStep(modules),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (_step == _Step.difficulty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _level == null || _starting ? null : _start,
                    icon: _starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_level == null
                        ? 'Select a difficulty to begin'
                        : 'Start ${_module?.displayName ?? 'assessment'}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(List<AssessmentModule> modules) {
    switch (_step) {
      case _Step.module:
        return _ModuleStep(
          key: const ValueKey('module'),
          modules: modules,
          onSelect: _selectModule,
        );
      case _Step.category:
        return _CategoryStep(
          key: const ValueKey('category'),
          moduleKey: _module!.moduleKey,
          onSelect: _selectCategory,
        );
      case _Step.difficulty:
        return _DifficultyStep(
          key: ValueKey('difficulty-${_module!.moduleKey}-$_category'),
          moduleKey: _module!.moduleKey,
          category: _category,
          selected: _level,
          onSelect: (l) => setState(() {
            _level = l;
            _error = null;
          }),
        );
    }
  }
}

// ── Header (title + subtitle + step dots) ────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final _Step step;
  final String title;
  final String subtitle;
  const _StepHeader(
      {required this.step, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textDim)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in _Step.values)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  height: 4,
                  width: s == step ? 26 : 14,
                  decoration: BoxDecoration(
                    color: s.index <= step.index
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 1: modules grouped by cognitive domain ──────────────────────────────
class _ModuleStep extends StatelessWidget {
  final List<AssessmentModule> modules;
  final void Function(AssessmentModule) onSelect;
  const _ModuleStep(
      {super.key, required this.modules, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const _EmptyState(
        emoji: '🎈',
        title: 'No assessments enabled yet',
        message:
            'Ask your administrator to turn on assessment modules for your school.',
      );
    }

    final byDomain = <String, List<AssessmentModule>>{};
    for (final m in modules) {
      final d = _moduleDomain[m.moduleKey] ?? 'reasoning';
      byDomain.putIfAbsent(d, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final domain in _domainOrder)
          if (byDomain[domain] != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
              child: Text(
                _domainLabels[domain]!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textDim,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            for (final module in byDomain[domain]!)
              _ModuleCard(module: module, onTap: () => onSelect(module)),
          ],
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final AssessmentModule module;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final identity = moduleIdentity(module.moduleKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.radiusXl,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: AppTheme.radiusXl,
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: identity.gradient),
                    borderRadius: AppTheme.radiusL,
                  ),
                  child: Center(
                      child: Text(identity.emoji,
                          style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.displayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(identity.tagline,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textDim),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Memory Recall categories ─────────────────────────────────────────
class _CategoryStep extends ConsumerWidget {
  final String moduleKey;
  final void Function(String) onSelect;
  const _CategoryStep(
      {super.key, required this.moduleKey, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(_levelsProvider(moduleKey));
    return levels.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorRetry(
        message: e is Failure ? e.message : 'Could not load categories.',
        onRetry: () => ref.invalidate(_levelsProvider(moduleKey)),
      ),
      data: (items) {
        // Distinct categories, in a friendly order.
        final seen = <String>{};
        final categories = <String>[];
        for (final l in items) {
          final c = _categoryOf(l);
          if (seen.add(c)) categories.add(c);
        }
        const order = ['Animals', 'Fruits', 'Shapes', 'Alphabet', 'Numbers'];
        categories.sort((a, b) {
          final ia = order.indexOf(a), ib = order.indexOf(b);
          return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
        });

        if (categories.isEmpty) {
          return const _EmptyState(
            emoji: '📦',
            title: 'No categories yet',
            message: 'Ask your admin to add Memory Recall content.',
          );
        }

        return GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final category in categories)
              _CategoryCard(
                category: category,
                onTap: () => onSelect(category),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusXl,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: AppTheme.radiusXl,
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_categoryEmoji(category),
                  style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(category, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 3: difficulty ───────────────────────────────────────────────────────
class _DifficultyStep extends ConsumerWidget {
  final String moduleKey;
  final String? category;
  final AssessmentLevel? selected;
  final void Function(AssessmentLevel) onSelect;

  const _DifficultyStep({
    super.key,
    required this.moduleKey,
    required this.category,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(_levelsProvider(moduleKey));
    return levels.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorRetry(
        message: e is Failure ? e.message : 'Could not load levels.',
        onRetry: () => ref.invalidate(_levelsProvider(moduleKey)),
      ),
      data: (items) {
        final filtered = (category == null
            ? items
            : items.where((l) => _categoryOf(l) == category)).toList()
          ..sort((a, b) => _tierRank(_tierOf(a)).compareTo(_tierRank(_tierOf(b))));

        if (filtered.isEmpty) {
          return const _EmptyState(
            emoji: '🗂️',
            title: 'No levels here yet',
            message: 'Ask your admin to add levels for this game.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            for (final level in filtered)
              _DifficultyCard(
                level: level,
                selected: selected?.levelVersionId == level.levelVersionId,
                onTap: () => onSelect(level),
              ),
          ],
        );
      },
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final AssessmentLevel level;
  final bool selected;
  final VoidCallback onTap;
  const _DifficultyCard(
      {required this.level, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tier = _tierOf(level);
    final color = _tierColor(tier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.radiusXl,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : AppTheme.surface,
              borderRadius: AppTheme.radiusXl,
              border: Border.all(
                color: selected ? color : AppTheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radiusL,
                  ),
                  child: Icon(_tierIcon(tier), color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tier, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(_tierBlurb(tier),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textDim)),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: selected ? color : AppTheme.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared small states ──────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  const _EmptyState(
      {required this.emoji, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textDim)),
          ],
        ),
      ),
    );
  }
}
