import { createClient } from "@/lib/supabase/server";

export type AuditRow = {
  id: number;
  actor_id: string | null;
  actor_name: string;
  action: string;
  entity: string;
  entity_id: string | null;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  at: string;
};

// No direct FK from audit_logs to profiles (both reference auth.users), so
// actor names are resolved in a second query and mapped in memory.
export async function listAuditLogs(limit = 200): Promise<AuditRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("audit_logs")
    .select("id, actor_id, action, entity, entity_id, before, after, at")
    .order("at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(`Could not load audit log: ${error.message}`);

  const rows = data as Omit<AuditRow, "actor_name">[];
  const actorIds = [...new Set(rows.map((r) => r.actor_id).filter(Boolean))];

  const names = new Map<string, string>();
  if (actorIds.length > 0) {
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, full_name")
      .in("id", actorIds as string[]);
    for (const p of profiles ?? []) names.set(p.id, p.full_name);
  }

  return rows.map((r) => ({
    ...r,
    actor_name: r.actor_id ? (names.get(r.actor_id) ?? "Unknown") : "System",
  }));
}
