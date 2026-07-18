-- Seed data: one demo school with classes/students, both assessment modules,
-- three categories with placeholder media, starter levels, version gate, and
-- feature flags. Deterministic UUIDs so local resets are reproducible.
-- Auth users cannot be seeded via SQL — see tools/seed-users.md.

-- Demo school ----------------------------------------------------------------

insert into public.schools (id, name) values
  ('00000000-0000-4000-8000-000000000001', 'MindSprint Demo School');

insert into public.classes (id, school_id, name, grade) values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'Grade 4A', 4),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000001', 'Grade 5B', 5);

insert into public.students (id, school_id, class_id, full_name, roll_number, birth_year) values
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'Aarav Sharma',   '4A-01', 2016),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'Diya Patel',     '4A-02', 2016),
  ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'Kabir Das',      '4A-03', 2015),
  ('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'Meera Nair',     '4A-04', 2016),
  ('00000000-0000-4000-8000-000000000205', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'Rohan Gupta',    '4A-05', 2015),
  ('00000000-0000-4000-8000-000000000206', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'Ananya Singh',   '5B-01', 2015),
  ('00000000-0000-4000-8000-000000000207', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'Ishaan Bora',    '5B-02', 2014),
  ('00000000-0000-4000-8000-000000000208', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'Priya Kalita',   '5B-03', 2015),
  ('00000000-0000-4000-8000-000000000209', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'Vihaan Roy',     '5B-04', 2014),
  ('00000000-0000-4000-8000-000000000210', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'Zara Ahmed',     '5B-05', 2014);

-- Assessment modules ---------------------------------------------------------

insert into public.assessment_modules (module_key, name, enabled) values
  ('memory_recall', 'Memory Recall', true),
  ('math_speed', 'Mathematics Speed', true);

-- Categories + media library (placeholder storage paths) ---------------------

insert into public.categories (id, key, name) values
  ('00000000-0000-4000-8000-000000000301', 'animals', 'Animals'),
  ('00000000-0000-4000-8000-000000000302', 'fruits', 'Fruits'),
  ('00000000-0000-4000-8000-000000000303', 'shapes', 'Shapes');

with seed_items (category_id, label, path) as (
  values
    ('00000000-0000-4000-8000-000000000301'::uuid, 'Cat',      'seed/animals/cat.png'),
    ('00000000-0000-4000-8000-000000000301'::uuid, 'Dog',      'seed/animals/dog.png'),
    ('00000000-0000-4000-8000-000000000301'::uuid, 'Elephant', 'seed/animals/elephant.png'),
    ('00000000-0000-4000-8000-000000000301'::uuid, 'Lion',     'seed/animals/lion.png'),
    ('00000000-0000-4000-8000-000000000301'::uuid, 'Rabbit',   'seed/animals/rabbit.png'),
    ('00000000-0000-4000-8000-000000000301'::uuid, 'Tiger',    'seed/animals/tiger.png'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'Apple',    'seed/fruits/apple.png'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'Banana',   'seed/fruits/banana.png'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'Grapes',   'seed/fruits/grapes.png'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'Mango',    'seed/fruits/mango.png'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'Orange',   'seed/fruits/orange.png'),
    ('00000000-0000-4000-8000-000000000302'::uuid, 'Papaya',   'seed/fruits/papaya.png'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'Circle',   'seed/shapes/circle.png'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'Square',   'seed/shapes/square.png'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'Triangle', 'seed/shapes/triangle.png'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'Star',     'seed/shapes/star.png'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'Heart',    'seed/shapes/heart.png'),
    ('00000000-0000-4000-8000-000000000303'::uuid, 'Diamond',  'seed/shapes/diamond.png')
), assets as (
  insert into public.media_assets (type, storage_path, metadata)
  select 'image'::public.media_type, path, jsonb_build_object('seed', true)
  from seed_items
  returning id, storage_path
)
insert into public.category_items (category_id, label, media_asset_id)
select si.category_id, si.label, a.id
from seed_items si
join assets a on a.storage_path = si.path;

-- Starter levels (configs conform to packages/contracts/levels/v1) -----------

insert into public.levels (id, module_key, name, difficulty_rank) values
  ('00000000-0000-4000-8000-000000000401', 'memory_recall', 'Animals — Short Sequence', 1),
  ('00000000-0000-4000-8000-000000000402', 'memory_recall', 'Fruits — Medium Sequence', 2),
  ('00000000-0000-4000-8000-000000000403', 'memory_recall', 'Shapes — Long Sequence', 3),
  ('00000000-0000-4000-8000-000000000404', 'math_speed', 'Addition Basics', 1),
  ('00000000-0000-4000-8000-000000000405', 'math_speed', 'Mixed Operations', 2);

insert into public.level_versions (level_id, version, config) values
  ('00000000-0000-4000-8000-000000000401', 1,
   '{"category_key": "animals", "sequence_length": 3, "display_time_ms": 1500, "inter_item_gap_ms": 400, "choice_grid_size": 6}'),
  ('00000000-0000-4000-8000-000000000402', 1,
   '{"category_key": "fruits", "sequence_length": 4, "display_time_ms": 1200, "inter_item_gap_ms": 350, "choice_grid_size": 6}'),
  ('00000000-0000-4000-8000-000000000403', 1,
   '{"category_key": "shapes", "sequence_length": 5, "display_time_ms": 1000, "inter_item_gap_ms": 300, "choice_grid_size": 6}'),
  ('00000000-0000-4000-8000-000000000404', 1,
   '{"operations": ["add"], "question_count": 10, "operand_min": 1, "operand_max": 20, "time_limit_ms_per_question": 15000}'),
  ('00000000-0000-4000-8000-000000000405', 1,
   '{"operations": ["add", "sub", "mul"], "question_count": 10, "operand_min": 1, "operand_max": 12, "time_limit_ms_per_question": 20000}');

-- Platform ops ---------------------------------------------------------------

insert into public.app_versions (version, minimum_supported_version, release_notes) values
  ('0.1.0', '0.1.0', 'Phase 1 foundation');

insert into public.feature_flags (key, enabled, description) values
  ('memory_module', true,  'Memory Recall assessment module'),
  ('maths_module', false, 'Mathematics Speed assessment module'),
  ('session_replay', false, 'Admin session replay UI'),
  ('benchmark_engine', false, 'Class/school benchmark aggregates'),
  ('adaptive_difficulty', false, 'On-device adaptive difficulty engine');
