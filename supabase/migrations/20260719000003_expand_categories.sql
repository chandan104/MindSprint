-- Content fix (device-testing finding): the Hard Memory Recall level needs an
-- 8-tile choice grid but every category held only 6 items, so Hard was
-- unstartable. Expand each category to 8 items. Also enable the Mathematics
-- Speed feature flag — its gameplay ships in the same release.
--
-- Guarded like all content-bootstrap migrations: joins on categories mean a
-- fresh local database (migrations before seed) inserts nothing; hosted
-- (already seeded) gets exactly the missing rows. Idempotent via NOT EXISTS.

with new_items (category_key, label, path, emoji) as (
  values
    ('animals', 'Panda',      'seed/animals/panda.png',      '🐼'),
    ('animals', 'Fox',        'seed/animals/fox.png',        '🦊'),
    ('fruits',  'Strawberry', 'seed/fruits/strawberry.png',  '🍓'),
    ('fruits',  'Watermelon', 'seed/fruits/watermelon.png',  '🍉'),
    ('shapes',  'Moon',       'seed/shapes/moon.png',        '🌙'),
    ('shapes',  'Sun',        'seed/shapes/sun.png',         '☀️')
),
cats as (
  select id, key from public.categories where key in ('animals', 'fruits', 'shapes')
),
assets as (
  insert into public.media_assets (type, storage_path, metadata)
  select 'image'::public.media_type,
         ni.path,
         jsonb_build_object('seed', true, 'emoji', ni.emoji)
    from new_items ni
    join cats c on c.key = ni.category_key
   where not exists (
     select 1 from public.media_assets ma where ma.storage_path = ni.path
   )
  returning id, storage_path
)
insert into public.category_items (category_id, label, media_asset_id)
select c.id, ni.label, a.id
  from new_items ni
  join cats c on c.key = ni.category_key
  join assets a on a.storage_path = ni.path
 where not exists (
   select 1 from public.category_items ci
    where ci.category_id = c.id and ci.label = ni.label
 );

update public.feature_flags
   set enabled = true
 where key = 'maths_module';
