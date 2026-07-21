import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../attention_focus/focus_tap_module.dart';
import '../math_speed/math_speed_module.dart';
import '../memory_recall/memory_recall_module.dart';
import '../pattern_recognition/pattern_detective_module.dart';
import '../visual_search/visual_search_module.dart';
import 'assessment_module.dart';

/// Feature-flag key per module. A module is offered to teachers only when it
/// is implemented here AND its server-side flag is on (spec §modules).
const moduleFlagKeys = <String, String>{
  'memory_recall': 'memory_module',
  'math_speed': 'maths_module',
  'attention_focus': 'attention_module',
  'pattern_recognition': 'pattern_module',
  'visual_search': 'visual_search_module',
  'sequence_logic': 'sequence_logic_module',
};

/// All modules compiled into this app version. Future modules: implement
/// [AssessmentModule], add one line here.
final _implementations = <String, AssessmentModule Function()>{
  'memory_recall': MemoryRecallModule.new,
  'math_speed': MathSpeedModule.new,
  'attention_focus': FocusTapModule.new,
  'pattern_recognition': PatternDetectiveModule.new,
  'visual_search': VisualSearchModule.new,
};

/// Modules that are both implemented in this build and enabled by server
/// flags — the list the setup screen offers.
final enabledModulesProvider = Provider<List<AssessmentModule>>((ref) {
  final startup = ref.watch(startupStateProvider);
  if (startup == null) return const [];
  return [
    for (final entry in _implementations.entries)
      if (startup.flag(moduleFlagKeys[entry.key] ?? '')) entry.value(),
  ];
});

AssessmentModule? moduleForKey(String moduleKey) =>
    _implementations[moduleKey]?.call();
