-- M3: Data-driven assessment content — modules, media library, categories,
-- levels with append-only versions (ADR-009: sessions reference the exact
-- immutable level_version they ran).

create table public.assessment_modules (
  module_key text primary key,
  name text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  type public.media_type not null,
  storage_path text not null,
  uploaded_by uuid references auth.users (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.category_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id) on delete cascade,
  label text not null,
  media_asset_id uuid references public.media_assets (id) on delete set null,
  created_at timestamptz not null default now()
);

create index category_items_category_id_idx on public.category_items (category_id);

create table public.levels (
  id uuid primary key default gen_random_uuid(),
  module_key text not null references public.assessment_modules (module_key),
  name text not null,
  difficulty_rank integer not null default 1,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.level_versions (
  id uuid primary key default gen_random_uuid(),
  level_id uuid not null references public.levels (id) on delete cascade,
  version integer not null,
  config jsonb not null,
  created_at timestamptz not null default now(),
  unique (level_id, version)
);

create index level_versions_level_id_idx on public.level_versions (level_id);

-- level_versions is append-only: editing a level means inserting a new version.
create or replace function public.forbid_level_version_update()
returns trigger
language plpgsql
as $$
begin
  raise exception 'level_versions is append-only; insert a new version instead of updating';
end;
$$;

create trigger level_versions_no_update
  before update on public.level_versions
  for each row execute function public.forbid_level_version_update();
