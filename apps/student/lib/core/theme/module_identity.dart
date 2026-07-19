import 'package:flutter/material.dart';

/// Per-module visual identity, translated from the prototype's "worlds"
/// concept: each cognitive domain gets a color world, emoji, and tagline.
/// Display NAMES stay database-driven (assessment_modules.name); this is the
/// purely visual layer that ships with the gameplay implementation.
@immutable
class ModuleIdentity {
  final String emoji;
  final String world;
  final String tagline;
  final List<Color> gradient;
  final Color accent;

  const ModuleIdentity({
    required this.emoji,
    required this.world,
    required this.tagline,
    required this.gradient,
    required this.accent,
  });
}

const _fallback = ModuleIdentity(
  emoji: '🧩',
  world: 'MindSprint',
  tagline: 'A new challenge awaits.',
  gradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  accent: Color(0xFF818CF8),
);

const _identities = <String, ModuleIdentity>{
  'memory_recall': ModuleIdentity(
    emoji: '🧠',
    world: 'Aetheria — Dream World',
    tagline: 'Remember the order. Trust your memory.',
    gradient: [Color(0xFFA855F7), Color(0xFF6366F1), Color(0xFF4F46E5)],
    accent: Color(0xFFC4B5FD),
  ),
  'math_speed': ModuleIdentity(
    emoji: '⚡',
    world: 'Ignis Prime — Volcano Engine',
    tagline: 'Quick thinking. Fast numbers.',
    gradient: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEF4444)],
    accent: Color(0xFFFCD34D),
  ),
  'attention_focus': ModuleIdentity(
    emoji: '🎯',
    world: 'Verdant Core — Emerald Sanctuary',
    tagline: 'Tap the target. Ignore the rest.',
    gradient: [Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF16A34A)],
    accent: Color(0xFF6EE7B7),
  ),
  'pattern_recognition': ModuleIdentity(
    emoji: '🧩',
    world: 'Prisma — Crystal Canyons',
    tagline: 'Find the rule. Complete the pattern.',
    gradient: [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF6366F1)],
    accent: Color(0xFF67E8F9),
  ),
  'visual_search': ModuleIdentity(
    emoji: '👁️',
    world: 'Umbra — Hidden Depths',
    tagline: 'Spot it fast. Eyes sharp.',
    gradient: [Color(0xFFEC4899), Color(0xFFD946EF), Color(0xFFA855F7)],
    accent: Color(0xFFF9A8D4),
  ),
  'sequence_logic': ModuleIdentity(
    emoji: '🔄',
    world: 'Meridian — Clockwork City',
    tagline: 'Put the steps in order.',
    gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6D28D9)],
    accent: Color(0xFFC4B5FD),
  ),
};

ModuleIdentity moduleIdentity(String moduleKey) =>
    _identities[moduleKey] ?? _fallback;
