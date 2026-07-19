-- Content bootstrap: give every seeded media asset a data-driven emoji
-- glyph in metadata. The client renders emoji when present, a storage image
-- otherwise, and the item's initial letter as last resort — so content stays
-- fully database-editable and gameplay does not depend on uploaded files.
-- Idempotent by construction (keyed on storage_path).

with glyphs (path, emoji) as (
  values
    ('seed/animals/cat.png',      '🐱'),
    ('seed/animals/dog.png',      '🐶'),
    ('seed/animals/elephant.png', '🐘'),
    ('seed/animals/lion.png',     '🦁'),
    ('seed/animals/rabbit.png',   '🐰'),
    ('seed/animals/tiger.png',    '🐯'),
    ('seed/fruits/apple.png',     '🍎'),
    ('seed/fruits/banana.png',    '🍌'),
    ('seed/fruits/grapes.png',    '🍇'),
    ('seed/fruits/mango.png',     '🥭'),
    ('seed/fruits/orange.png',    '🍊'),
    ('seed/fruits/papaya.png',    '🍈'),
    ('seed/shapes/circle.png',    '🔵'),
    ('seed/shapes/square.png',    '🟥'),
    ('seed/shapes/triangle.png',  '🔺'),
    ('seed/shapes/star.png',      '⭐'),
    ('seed/shapes/heart.png',     '❤️'),
    ('seed/shapes/diamond.png',   '💠')
)
update public.media_assets m
   set metadata = m.metadata || jsonb_build_object('emoji', g.emoji)
  from glyphs g
 where m.storage_path = g.path;
