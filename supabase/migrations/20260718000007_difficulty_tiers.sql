-- M7: Three predefined difficulty tiers per module (product decision,
-- 2026-07-18). Every module ships Easy / Medium / Hard levels; the tier is
-- metadata for selection and benchmarking, while the actual knobs (pace,
-- counts, display times, distractors) stay in the level_versions config —
-- nothing is hardcoded per tier.

create type public.difficulty_tier as enum ('easy', 'medium', 'hard');

alter table public.levels
  add column difficulty public.difficulty_tier not null default 'medium';

-- difficulty_rank stays for fine ordering within a tier.
create index levels_module_difficulty_idx
  on public.levels (module_key, difficulty);
