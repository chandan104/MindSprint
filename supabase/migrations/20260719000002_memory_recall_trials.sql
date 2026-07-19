-- Append level_versions v2 for the seeded Memory Recall levels with the new
-- optional trial_count knob (multi-round sessions, adopted from the UI
-- prototype's superior assessment structure). Append-only per ADR-009 —
-- existing versions are never touched; sessions keep referencing the exact
-- version they ran.
--
-- Guarded by join on levels: on a fresh local database (migrations run
-- before seed) this inserts nothing; on hosted (already seeded) it appends.

insert into public.level_versions (level_id, version, config)
select l.id,
       coalesce((select max(v.version)
                   from public.level_versions v
                  where v.level_id = l.id), 0) + 1,
       c.config::jsonb
  from (values
    ('00000000-0000-4000-8000-000000000401'::uuid,
     '{"category_key": "animals", "sequence_length": 3, "display_time_ms": 2000, "inter_item_gap_ms": 500, "choice_grid_size": 4, "trial_count": 2}'),
    ('00000000-0000-4000-8000-000000000402'::uuid,
     '{"category_key": "fruits", "sequence_length": 4, "display_time_ms": 1200, "inter_item_gap_ms": 350, "choice_grid_size": 6, "trial_count": 3}'),
    ('00000000-0000-4000-8000-000000000403'::uuid,
     '{"category_key": "shapes", "sequence_length": 6, "display_time_ms": 800, "inter_item_gap_ms": 250, "choice_grid_size": 8, "trial_count": 3}')
  ) as c(level_id, config)
  join public.levels l on l.id = c.level_id;
