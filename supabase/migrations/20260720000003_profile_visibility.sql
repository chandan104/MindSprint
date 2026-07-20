-- Teacher notes need attribution ("who wrote this?"), which requires staff
-- of the SAME school to read each other's profile names. Previously profiles
-- were self-or-super_admin only. This widens read access minimally: a
-- profile becomes readable to same-school staff (via the profile owner's
-- user_roles school). Profiles contain only full_name — no contact data.

drop policy profiles_select on public.profiles;

create policy profiles_select on public.profiles for select
  using (
    id = auth.uid()
    or public.is_super_admin()
    or exists (
      select 1
        from public.user_roles r
       where r.user_id = public.profiles.id
         and r.school_id is not null
         and public.is_school_member(r.school_id)
    )
  );
