-- The DPDP data-erasure path, specified in Phase 1 and now implemented:
-- permanent, audited deletion of one student and every derived record.
--
-- SECURITY DEFINER with authorization INSIDE the function: only a
-- school_admin of the student's school (or super_admin) may erase. The audit
-- row is written BEFORE the cascade so the ledger records what was erased,
-- by whom, and why — without retaining the erased assessment data itself.
-- Cascades: sessions -> session_events + session_metrics, teacher_notes.

create or replace function public.delete_student(
  p_student_id uuid,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid;
  v_student jsonb;
  v_session_count integer;
begin
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'delete_student: a reason is required for the audit record';
  end if;

  select s.school_id, to_jsonb(s) into v_school, v_student
    from public.students s where s.id = p_student_id;
  if v_school is null then
    raise exception 'delete_student: unknown student %', p_student_id;
  end if;

  if not (public.is_super_admin() or public.is_school_admin_of(v_school)) then
    raise insufficient_privilege
      using message = 'delete_student: only a school admin of this school may erase student data';
  end if;

  select count(*) into v_session_count
    from public.sessions where student_id = p_student_id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before, after)
  values (
    auth.uid(),
    'ERASE',
    'students',
    p_student_id::text,
    jsonb_build_object(
      'student', v_student,
      'reason', trim(p_reason),
      'sessions_erased', v_session_count
    ),
    null
  );

  delete from public.students where id = p_student_id;
end;
$$;

grant execute on function public.delete_student(uuid, text) to authenticated;
revoke execute on function public.delete_student(uuid, text) from anon, public;
