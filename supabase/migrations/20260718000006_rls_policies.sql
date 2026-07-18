-- M6: Row Level Security — the actual security boundary of the platform.
-- Matrix (spec §7): super_admin → all; school_admin → own school;
-- teacher → own school read, session/note writes only as themselves.
-- All policies read JWT claims via auth_role()/auth_school_id() (M1).

-- Helper predicates ----------------------------------------------------------

create or replace function public.is_super_admin()
returns boolean language sql stable as $$
  select public.auth_role() = 'super_admin'
$$;

create or replace function public.is_school_admin_of(target_school uuid)
returns boolean language sql stable as $$
  select public.auth_role() = 'school_admin' and public.auth_school_id() = target_school
$$;

create or replace function public.is_school_member(target_school uuid)
returns boolean language sql stable as $$
  select public.auth_role() in ('school_admin', 'teacher')
     and public.auth_school_id() = target_school
$$;

-- Enable RLS everywhere ------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.schools enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.teacher_classes enable row level security;
alter table public.assessment_modules enable row level security;
alter table public.media_assets enable row level security;
alter table public.categories enable row level security;
alter table public.category_items enable row level security;
alter table public.levels enable row level security;
alter table public.level_versions enable row level security;
alter table public.sessions enable row level security;
alter table public.session_events enable row level security;
alter table public.session_metrics enable row level security;
alter table public.app_versions enable row level security;
alter table public.feature_flags enable row level security;
alter table public.teacher_notes enable row level security;
alter table public.audit_logs enable row level security;

-- Explicit grants: do not rely on platform default privileges. RLS decides
-- WHICH rows; grants decide WHICH verbs. anon gets nothing — every client
-- authenticates.

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- service_role (server-side tooling, Studio, admin scripts) has bypassrls
-- but still needs table grants once we stop relying on platform defaults.
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

-- Future tables created by migrations (which run as postgres) inherit the
-- same grants automatically.
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges for role postgres in schema public
  grant all on tables to service_role;

-- Narrow the broad grant for immutable / system-written tables.
revoke update, delete on public.session_events from authenticated;
revoke update, delete on public.session_metrics from authenticated;
revoke insert, update, delete on public.audit_logs from authenticated;

revoke all on all tables in schema public from anon;

-- profiles: users see/update themselves; super_admin sees all ---------------

create policy profiles_select on public.profiles for select
  using (
    id = auth.uid()
    or public.is_super_admin()
    -- School admins see profiles of users who hold a role in their school.
    or (
      public.auth_role() = 'school_admin'
      and exists (
        select 1 from public.user_roles ur
        where ur.user_id = profiles.id
          and ur.school_id = public.auth_school_id()
      )
    )
  );
create policy profiles_update on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_admin_write on public.profiles for insert
  with check (id = auth.uid() or public.is_super_admin());

-- user_roles: readable by self, super_admin, and the school_admin of the
-- same school (the admin dashboard lists a school's teachers); writable by
-- super_admin only.

create policy user_roles_select on public.user_roles for select
  using (
    user_id = auth.uid()
    or public.is_super_admin()
    or (public.auth_role() = 'school_admin' and school_id = public.auth_school_id())
  );
create policy user_roles_write on public.user_roles for all
  using (public.is_super_admin()) with check (public.is_super_admin());

-- The access-token hook runs as supabase_auth_admin BEFORE claims exist, so
-- claim-based policies see nothing. Without this policy every token is
-- issued without role claims and all RLS checks deny.
create policy user_roles_auth_admin_read on public.user_roles
  for select to supabase_auth_admin using (true);

-- schools -------------------------------------------------------------------

create policy schools_select on public.schools for select
  using (public.is_super_admin() or public.is_school_member(id));
create policy schools_write on public.schools for all
  using (public.is_super_admin()) with check (public.is_super_admin());

-- classes / students: school-scoped read; school_admin + super_admin write --

create policy classes_select on public.classes for select
  using (public.is_super_admin() or public.is_school_member(school_id));
create policy classes_write on public.classes for all
  using (public.is_super_admin() or public.is_school_admin_of(school_id))
  with check (public.is_super_admin() or public.is_school_admin_of(school_id));

create policy students_select on public.students for select
  using (public.is_super_admin() or public.is_school_member(school_id));
create policy students_write on public.students for all
  using (public.is_super_admin() or public.is_school_admin_of(school_id))
  with check (public.is_super_admin() or public.is_school_admin_of(school_id));

-- teacher_classes: teachers see own assignments; admins manage school's -----

create policy teacher_classes_select on public.teacher_classes for select
  using (
    teacher_id = auth.uid()
    or public.is_super_admin()
    or exists (
      select 1 from public.classes c
      where c.id = class_id and public.is_school_admin_of(c.school_id)
    )
  );
create policy teacher_classes_write on public.teacher_classes for all
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.classes c
      where c.id = class_id and public.is_school_admin_of(c.school_id)
    )
  )
  with check (
    public.is_super_admin()
    or exists (
      select 1 from public.classes c
      where c.id = class_id and public.is_school_admin_of(c.school_id)
    )
  );

-- Content: readable by all authenticated; writable by admins ----------------

create policy assessment_modules_select on public.assessment_modules for select
  using (auth.role() = 'authenticated');
create policy assessment_modules_write on public.assessment_modules for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy media_assets_select on public.media_assets for select
  using (auth.role() = 'authenticated');
create policy media_assets_write on public.media_assets for all
  using (public.auth_role() in ('super_admin', 'school_admin'))
  with check (public.auth_role() in ('super_admin', 'school_admin'));

create policy categories_select on public.categories for select
  using (auth.role() = 'authenticated');
create policy categories_write on public.categories for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy category_items_select on public.category_items for select
  using (auth.role() = 'authenticated');
create policy category_items_write on public.category_items for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy levels_select on public.levels for select
  using (auth.role() = 'authenticated');
create policy levels_write on public.levels for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy level_versions_select on public.level_versions for select
  using (auth.role() = 'authenticated');
create policy level_versions_insert on public.level_versions for insert
  with check (public.is_super_admin());
-- No update policy: level_versions is append-only (M3 trigger + no policy).

-- Sessions: teachers insert their own; school-scoped read -------------------

create policy sessions_select on public.sessions for select
  using (public.is_super_admin() or public.is_school_member(school_id));
create policy sessions_insert on public.sessions for insert
  with check (
    teacher_id = auth.uid()
    and public.auth_role() = 'teacher'
    and public.auth_school_id() = school_id
  );
-- Status transitions (validated/invalid) happen via definer functions in
-- later phases; no direct update policy for clients.

-- session_events: insert-only by the owning teacher; school-scoped read -----

create policy session_events_select on public.session_events for select
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.sessions s
      where s.id = session_id and public.is_school_member(s.school_id)
    )
  );
create policy session_events_insert on public.session_events for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = session_id and s.teacher_id = auth.uid()
    )
  );

-- session_metrics: read-only for clients; written by compute fn (Phase 4) ---

create policy session_metrics_select on public.session_metrics for select
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.sessions s
      where s.id = session_id and public.is_school_member(s.school_id)
    )
  );

-- Platform ops --------------------------------------------------------------

create policy app_versions_select on public.app_versions for select
  using (auth.role() = 'authenticated');
create policy app_versions_write on public.app_versions for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy feature_flags_select on public.feature_flags for select
  using (auth.role() = 'authenticated');
create policy feature_flags_write on public.feature_flags for all
  using (public.is_super_admin()) with check (public.is_super_admin());

-- teacher_notes: teachers write their own; school-scoped read ---------------

create policy teacher_notes_select on public.teacher_notes for select
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.students st
      where st.id = student_id and public.is_school_member(st.school_id)
    )
  );
create policy teacher_notes_insert on public.teacher_notes for insert
  with check (teacher_id = auth.uid() and public.auth_role() = 'teacher');
create policy teacher_notes_update on public.teacher_notes for update
  using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());

-- audit_logs: written by trigger (security definer); admins read ------------

create policy audit_logs_select on public.audit_logs for select
  using (
    public.is_super_admin()
    or public.auth_role() = 'school_admin'
  );
-- No insert policy for clients: the security-definer trigger bypasses RLS.
