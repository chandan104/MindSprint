-- M1: Identity, roles, and JWT claims hook.
-- user_roles is the single source for every permission check (ADR-011).

create type public.user_role as enum ('super_admin', 'school_admin', 'teacher');
create type public.session_status as enum ('uploaded', 'validated', 'invalid');
create type public.media_type as enum ('image', 'icon', 'audio', 'animation');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  created_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null,
  -- FK to schools added in M2 (schools does not exist yet)
  school_id uuid,
  created_at timestamptz not null default now()
);

-- Stamps user_role and school_id into every access token so RLS policies read
-- claims instead of joining user_roles per row. Enabled in config.toml under
-- [auth.hook.custom_access_token]; must also be enabled in the hosted project's
-- Auth settings.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  v_role public.user_role;
  v_school uuid;
begin
  select role, school_id
    into v_role, v_school
    from public.user_roles
   where user_id = (event ->> 'user_id')::uuid;

  claims := coalesce(event -> 'claims', '{}'::jsonb);

  if v_role is not null then
    claims := jsonb_set(claims, '{user_role}', to_jsonb(v_role::text));
    if v_school is not null then
      claims := jsonb_set(claims, '{school_id}', to_jsonb(v_school::text));
    end if;
  end if;

  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;
grant select on table public.user_roles to supabase_auth_admin;

-- Claim readers used by every RLS policy.
create or replace function public.auth_role()
returns text
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'user_role'
$$;

create or replace function public.auth_school_id()
returns uuid
language sql
stable
as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'school_id', '')::uuid
$$;
