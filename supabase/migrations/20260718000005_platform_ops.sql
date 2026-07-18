-- M5: Platform operations — app version gate, feature flags, teacher notes,
-- audit logging on every admin mutation.

create table public.app_versions (
  id uuid primary key default gen_random_uuid(),
  version text not null,
  minimum_supported_version text not null,
  release_notes text,
  released_at timestamptz not null default now()
);

create table public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  description text
);

create table public.teacher_notes (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.sessions (id) on delete set null,
  student_id uuid not null references public.students (id) on delete cascade,
  teacher_id uuid not null references auth.users (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index teacher_notes_student_id_idx on public.teacher_notes (student_id);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  entity text not null,
  entity_id text,
  before jsonb,
  after jsonb,
  at timestamptz not null default now()
);

revoke update, delete on public.audit_logs from authenticated, anon;

-- Generic audit trigger for admin-managed tables. SECURITY DEFINER so the
-- insert succeeds regardless of the actor's own grants on audit_logs.
create or replace function public.log_admin_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_entity_id text;
begin
  v_row := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  -- Not every audited table has an `id` column (feature_flags keys on `key`,
  -- assessment_modules on `module_key`), so derive the identifier generically.
  v_entity_id := coalesce(v_row ->> 'id', v_row ->> 'key', v_row ->> 'module_key');

  insert into public.audit_logs (actor_id, action, entity, entity_id, before, after)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    v_entity_id,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger audit_schools after insert or update or delete on public.schools
  for each row execute function public.log_admin_mutation();
create trigger audit_classes after insert or update or delete on public.classes
  for each row execute function public.log_admin_mutation();
create trigger audit_students after insert or update or delete on public.students
  for each row execute function public.log_admin_mutation();
create trigger audit_assessment_modules after insert or update or delete on public.assessment_modules
  for each row execute function public.log_admin_mutation();
create trigger audit_media_assets after insert or update or delete on public.media_assets
  for each row execute function public.log_admin_mutation();
create trigger audit_categories after insert or update or delete on public.categories
  for each row execute function public.log_admin_mutation();
create trigger audit_category_items after insert or update or delete on public.category_items
  for each row execute function public.log_admin_mutation();
create trigger audit_levels after insert or update or delete on public.levels
  for each row execute function public.log_admin_mutation();
create trigger audit_app_versions after insert or update or delete on public.app_versions
  for each row execute function public.log_admin_mutation();
create trigger audit_feature_flags after insert or update or delete on public.feature_flags
  for each row execute function public.log_admin_mutation();
