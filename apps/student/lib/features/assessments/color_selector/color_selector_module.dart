import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_identity.dart';
import '../../../core/widgets/countdown_bar.dart';
import '../domain/assessment_models.dart';
import '../engine/assessment_module.dart';

class ColorSelectorModule implements AssessmentModule {
  @override
  String get moduleKey => 'color_selector';

  @override
  String get displayName => 'Colour Selector';

  @override
  bool get requiresContentItems => false; // generates colours

  @override
  Widget buildRunner(AssessmentRunContext context) =>
      ColorSelectorRunner(runContext: context);
}

/// Config (contracts/levels/v1/color_selector.config.json).
class _Config {
  final int colourCount;
  final int timeLimitMs;
  final bool stroop;
  final List<String> instructionModes; // ['colour'] and/or ['word']

  _Config(Map<String, Object?> raw)
      : colourCount = raw['colour_count'] as int,
        timeLimitMs = raw['time_limit_ms_per_round'] as int,
        stroop = raw['stroop'] as bool? ?? false,
        instructionModes =
            List<String>.from(raw['instruction_modes'] as List? ?? ['colour']);
}

class _Colour {
  final String id;
  final String label;
  final Color color;
  const _Colour(this.id, this.label, this.color);
}

const _palette = <_Colour>[
  _Colour('red', 'Red', Color(0xFFEF4444)),
  _Colour('blue', 'Blue', Color(0xFF3B82F6)),
  _Colour('green', 'Green', Color(0xFF22C55E)),
  _Colour('yellow', 'Yellow', Color(0xFFEAB308)),
  _Colour('purple', 'Purple', Color(0xFFA855F7)),
  _Colour('orange', 'Orange', Color(0xFFF97316)),
];

class _Round {
  final String instructionText;
  final String instructionKind; // 'colour' | 'word'
  final String targetId; // the correct option id
  final List<_Tile> tiles;

  /// Stroop congruency of the target tile (word == ink). Null on non-Stroop
  /// rounds. A controlled mix of congruent and incongruent trials is what makes
  /// interference (incongruent RT − congruent RT) measurable.
  final bool? congruent;

  const _Round({
    required this.instructionText,
    required this.instructionKind,
    required this.targetId,
    required this.tiles,
    this.congruent,
  });
}

/// A rendered option: a colour swatch, or (Stroop) a colour word printed in a
/// different ink. id identifies what a tap "means" per the instruction kind.
class _Tile {
  final String id; // matched against target
  final String? word; // shown text (Stroop) or null for a plain swatch
  final Color ink; // fill / text colour

  const _Tile({required this.id, this.word, required this.ink});
}

enum _Phase { instruction, options, feedback }

/// Selective attention with a clear animated instruction before every round
/// (Chroma world). Emits instruction_shown (reading-delay), question_displayed
/// (options), tap_registered / answer_submitted — reusing the whole metrics,
/// replay, upload pipeline. Stroop levels ask for the WORD vs the INK.
class ColorSelectorRunner extends StatefulWidget {
  final AssessmentRunContext runContext;
  final Random? random;
  final int roundCount;

  const ColorSelectorRunner({
    super.key,
    required this.runContext,
    this.random,
    this.roundCount = 8, // more rounds → a more reliable interference estimate
  });

  @override
  State<ColorSelectorRunner> createState() => _ColorSelectorRunnerState();
}

class _ColorSelectorRunnerState extends State<ColorSelectorRunner> {
  late final _Config _config;
  late final Random _rng;

  _Phase _phase = _Phase.instruction;
  var _roundNumber = 0;
  _Round? _round;
  String? _selectedId;
  bool? _lastCorrect;
  Timer? _instructionTimer;
  Timer? _roundTimer;
  Timer? _advanceTimer;

  AssessmentRunContext get _run => widget.runContext;
  ModuleIdentity get _identity => moduleIdentity('color_selector');

  @override
  void initState() {
    super.initState();
    _config = _Config(_run.level.config);
    _rng = widget.random ?? Random();
    _startRound();
  }

  @override
  void dispose() {
    _instructionTimer?.cancel();
    _roundTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  _Round _buildRound() {
    final colours = [..._palette]..shuffle(_rng);
    final chosen = colours.take(_config.colourCount).toList();
    final target = chosen[_rng.nextInt(chosen.length)];
    final mode = _config.instructionModes[
        _rng.nextInt(_config.instructionModes.length)];

    if (!_config.stroop) {
      final tiles = [for (final c in chosen) _Tile(id: c.id, ink: c.color)]
        ..shuffle(_rng);
      return _Round(
        instructionText: 'Tap the ${target.label.toUpperCase()} colour',
        instructionKind: mode,
        targetId: target.id,
        tiles: tiles,
      );
    }
    return _buildStroopRound(chosen, target, mode);
  }

  /// Stroop round: each tile is a colour WORD printed in an ink. The target
  /// tile is congruent (word == ink) on ~1/3 of trials so the metrics engine
  /// can measure interference = incongruent RT − congruent RT. Exactly one tile
  /// matches the target under the instruction (word id, or ink id).
  _Round _buildStroopRound(List<_Colour> chosen, _Colour target, String mode) {
    final congruent = _rng.nextInt(3) == 0;
    final nonTarget = chosen.where((c) => c.id != target.id).toList();

    // The word shown on the target tile.
    final targetWord = (mode == 'word' || congruent)
        ? target
        : nonTarget[_rng.nextInt(nonTarget.length)];
    // Its ink: colour mode requires the target's ink; word mode uses the
    // target's colour only when congruent, otherwise a conflicting ink.
    final Color targetInk = (mode == 'colour')
        ? target.color
        : (congruent ? target.color : nonTarget[_rng.nextInt(nonTarget.length)].color);

    final tiles = <_Tile>[
      _Tile(
        id: mode == 'word' ? targetWord.id : target.id,
        word: targetWord.label,
        ink: targetInk,
      ),
    ];

    // One distractor tile per remaining word, inked to a NON-target colour that
    // differs from its own word (Stroop conflict) so its match id != target.
    for (final w in chosen.where((c) => c.id != targetWord.id)) {
      final inkChoices = chosen
          .where((x) => x.id != target.id && x.id != w.id)
          .toList();
      final ink = (inkChoices.isEmpty ? nonTarget : inkChoices)..shuffle(_rng);
      final chosenInk = ink.first;
      tiles.add(_Tile(
        id: mode == 'word' ? w.id : chosenInk.id,
        word: w.label,
        ink: chosenInk.color,
      ));
    }
    tiles.shuffle(_rng);

    final instruction = mode == 'word'
        ? 'Tap the WORD ${target.label}'
        : 'Tap the ${target.label.toUpperCase()} colour';

    return _Round(
      instructionText: instruction,
      instructionKind: mode,
      targetId: target.id,
      tiles: tiles,
      congruent: congruent,
    );
  }

  void _startRound() {
    if (_roundNumber >= widget.roundCount) {
      _run.onFinished(AssessmentOutcome.completed);
      return;
    }
    final round = _buildRound();
    setState(() {
      _roundNumber++;
      _round = round;
      _selectedId = null;
      _lastCorrect = null;
      _phase = _Phase.instruction;
    });
    _run.recorder.record('instruction_shown', {
      'instruction_text': round.instructionText,
      'instruction_kind': round.instructionKind,
    });
    // Give children a clear beat to read; then reveal options.
    _instructionTimer = Timer(const Duration(milliseconds: 1200), _showOptions);
  }

  void _showOptions() {
    if (!mounted) return;
    final round = _round!;
    setState(() => _phase = _Phase.options);
    _run.recorder.record('question_displayed', {
      'question_text': round.instructionText,
      'expected_answer': round.targetId,
      if (round.congruent != null) 'congruent': round.congruent,
      'options': [
        for (final t in round.tiles)
          {'item_id': t.id, 'label': t.word ?? t.id},
      ],
    });
    _roundTimer?.cancel();
    _roundTimer = Timer(Duration(milliseconds: _config.timeLimitMs), () {
      if (!mounted || _phase != _Phase.options || _selectedId != null) return;
      _run.recorder.record('answer_submitted', {
        'answer': 'timeout',
        'is_correct': false,
      });
      _feedbackThenNext(correct: false);
    });
  }

  void _onTileTap(_Tile tile, TapDownDetails details) {
    if (_phase != _Phase.options || _selectedId != null) return;
    final isCorrect = tile.id == _round!.targetId;
    _roundTimer?.cancel();
    _run.recorder.record('tap_registered', {
      'target_kind': 'choice',
      'item_id': tile.id,
      'label': tile.word ?? tile.id,
      'is_correct': isCorrect,
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    });
    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _selectedId = tile.id);
    _feedbackThenNext(correct: isCorrect);
  }

  void _feedbackThenNext({required bool correct}) {
    setState(() {
      _lastCorrect = correct;
      _phase = _Phase.feedback;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 700), _startRound);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Badge(
            identity: _identity, current: _roundNumber, total: widget.roundCount),
        Expanded(
          child: switch (_phase) {
            _Phase.instruction => _InstructionView(
                key: ValueKey('instr$_roundNumber'),
                text: _round!.instructionText,
                accent: _identity.accent,
              ),
            _Phase.options || _Phase.feedback => _OptionsView(
                round: _round!,
                identity: _identity,
                timeLimitMs: _config.timeLimitMs,
                selectedId: _selectedId,
                lastCorrect: _lastCorrect,
                accepting: _phase == _Phase.options,
                onTapDown: _onTileTap,
              ),
          },
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final ModuleIdentity identity;
  final int current;
  final int total;
  const _Badge({required this.identity, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusL,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Text(identity.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('COLOUR SELECTOR',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          Text('$current / $total',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: identity.accent)),
        ],
      ),
    );
  }
}

/// Animated, child-clear instruction beat before options appear.
class _InstructionView extends StatefulWidget {
  final String text;
  final Color accent;
  const _InstructionView({super.key, required this.text, required this.accent});

  @override
  State<_InstructionView> createState() => _InstructionViewState();
}

class _InstructionViewState extends State<_InstructionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: AppTheme.radiusXl,
            border: Border.all(color: widget.accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_outlined, color: widget.accent, size: 40),
              const SizedBox(height: 16),
              Text(
                widget.text,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionsView extends StatelessWidget {
  final _Round round;
  final ModuleIdentity identity;
  final int timeLimitMs;
  final String? selectedId;
  final bool? lastCorrect;
  final bool accepting;
  final void Function(_Tile, TapDownDetails) onTapDown;

  const _OptionsView({
    required this.round,
    required this.identity,
    required this.timeLimitMs,
    required this.selectedId,
    required this.lastCorrect,
    required this.accepting,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (accepting)
            CountdownBar(
                duration: Duration(milliseconds: timeLimitMs),
                color: identity.accent)
          else
            Icon(
              lastCorrect == true
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 30,
              color: lastCorrect == true ? AppTheme.success : scheme.error,
            ),
          const SizedBox(height: 8),
          Text(round.instructionText,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.6,
              children: [
                for (var i = 0; i < round.tiles.length; i++)
                  _TileWidget(
                    tile: round.tiles[i],
                    index: i,
                    selected: selectedId != null &&
                        !accepting &&
                        round.tiles[i].id == selectedId,
                    correct: lastCorrect,
                    onTapDown: accepting
                        ? (d) => onTapDown(round.tiles[i], d)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final _Tile tile;
  final int index;
  final bool selected;
  final bool? correct;
  final void Function(TapDownDetails)? onTapDown;

  const _TileWidget({
    required this.tile,
    required this.index,
    required this.selected,
    required this.correct,
    this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected
        ? (correct == true ? AppTheme.success : scheme.error)
        : AppTheme.border;

    return GestureDetector(
      key: ValueKey('colour-$index'),
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          // Stroop tiles show a WORD in an ink colour on a neutral card; plain
          // tiles are a solid swatch.
          color: tile.word == null ? tile.ink : AppTheme.surface,
          borderRadius: AppTheme.radiusL,
          border: Border.all(color: border, width: selected ? 3 : 1),
        ),
        child: Center(
          child: tile.word == null
              ? const SizedBox.shrink()
              : Text(
                  tile.word!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: tile.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
        ),
      ),
    );
  }
}
