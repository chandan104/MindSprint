-- Teacher self-onboarding: admin issues an invite (email + school), teacher
-- signs up and claims it. Replaces manual dashboard+SQL onboarding.

create table public.teacher_invites (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  email text not null,
  token uuid not null unique default gen_random_uuid(),
  invited_by uuid not null references auth.users (id),
  status text not null default 'pending' check (status in ('pending', 'claimed', 'revoked')),
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  claimed_by uuid references auth.users (id)
);

create index teacher_invites_school_id_idx on public.teacher_invites (school_id);
create unique index teacher_invites_pending_email_idx
  on public.teacher_invites (school_id, lower(email))
  where status = 'pending';

alter table public.teacher_invites enable row level security;

grant select, insert, update on public.teacher_invites to authenticated;
revoke all on public.teacher_invites from anon;

create policy teacher_invites_select on public.teacher_invites for select
  using (public.is_super_admin() or public.is_school_admin_of(school_id));

create policy teacher_invites_insert on public.teacher_invites for insert
  with check (
    (public.is_super_admin() or public.is_school_admin_of(school_id))
    and invited_by = auth.uid()
  );

-- Revoke = update status only; claim happens through the definer function
-- below, never a direct client update.
create policy teacher_invites_revoke on public.teacher_invites for update
  using (public.is_super_admin() or public.is_school_admin_of(school_id))
  with check (status = 'revoked');

create trigger audit_teacher_invites after insert or update or delete on public.teacher_invites
  for each row execute function public.log_admin_mutation();

-- Claimed by a freshly-signed-up teacher (auth.uid() is the new account).
-- Validates the token, the pending status, and that the claiming account's
-- email matches the invite — then grants exactly the teacher role for that
-- school. SECURITY DEFINER because the new user has no role yet to pass RLS.
create or replace function public.claim_teacher_invite(p_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite record;
  v_email text;
begin
  select email into v_email from auth.users where id = auth.uid();
  if v_email is null then
    raise exception 'claim_teacher_invite: no authenticated user';
  end if;

  select * into v_invite from public.teacher_invites
   where token = p_token and status = 'pending'
   for update;
  if v_invite is null then
    raise exception 'claim_teacher_invite: invite not found or already used';
  end if;

  if lower(v_invite.email) <> lower(v_email) then
    raise exception 'claim_teacher_invite: this invite was issued to a different email address';
  end if;

  if exists (select 1 from public.user_roles where user_id = auth.uid()) then
    raise exception 'claim_teacher_invite: this account already has a role';
  end if;

  insert into public.user_roles (user_id, role, school_id)
  values (auth.uid(), 'teacher', v_invite.school_id);

  insert into public.profiles (id, full_name)
  values (auth.uid(), split_part(v_email, '@', 1))
  on conflict (id) do nothing;

  update public.teacher_invites
     set status = 'claimed', claimed_at = now(), claimed_by = auth.uid()
   where id = v_invite.id;
end;
$$;

grant execute on function public.claim_teacher_invite(uuid) to authenticated;
revoke execute on function public.claim_teacher_invite(uuid) from anon, public;
