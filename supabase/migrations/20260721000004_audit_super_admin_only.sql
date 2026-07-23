-- Privacy tightening: audit_logs contains before/after row snapshots that
-- can include other schools' student data, and the table has no school_id
-- to scope by. A school_admin could therefore read cross-tenant history.
-- Audit history is a platform concern — restrict SELECT to super_admin only.

drop policy audit_logs_select on public.audit_logs;

create policy audit_logs_select on public.audit_logs for select
  using (public.is_super_admin());
