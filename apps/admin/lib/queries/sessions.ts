import { createClient } from "@/lib/supabase/server";

export type SessionRow = {
  id: string;
  module_key: string;
  status: string;
  started_at: string;
  completed_at: string | null;
  was_interrupted: boolean;
  students: { full_name: string } | null;
  classes: { name: string } | null;
  level_versions: { version: number; levels: { name: string; difficulty: string } | null } | null;
  session_metrics: { metrics_version: number; total_time_ms: number | null; accuracy: number | null }[];
};

export async function listRecentSessions(limit = 50): Promise<SessionRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("sessions")
    .select(
      "id, module_key, status, started_at, completed_at, was_interrupted, " +
        "students(full_name), classes(name), " +
        "level_versions(version, levels(name, difficulty)), " +
        "session_metrics(metrics_version, total_time_ms, accuracy)"
    )
    .order("started_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(`Could not load sessions: ${error.message}`);
  return data as unknown as SessionRow[];
}

export type SessionDetail = SessionRow & {
  device_meta: Record<string, unknown> | null;
  provisional_metrics: Record<string, unknown> | null;
  session_metrics: {
    metrics_version: number;
    total_time_ms: number | null;
    accuracy: number | null;
    error_count: number | null;
    computed_at: string;
    extra: Record<string, unknown>;
  }[];
};

export type SessionEventRow = {
  seq: number;
  event_type: string;
  t_ms: number;
  payload: Record<string, unknown>;
};

export async function getSessionDetail(id: string): Promise<{
  session: SessionDetail;
  events: SessionEventRow[];
}> {
  const supabase = await createClient();
  const [sessionRes, eventsRes] = await Promise.all([
    supabase
      .from("sessions")
      .select(
        "id, module_key, status, started_at, completed_at, was_interrupted, " +
          "device_meta, provisional_metrics, " +
          "students(full_name), classes(name), " +
          "level_versions(version, levels(name, difficulty)), " +
          "session_metrics(metrics_version, total_time_ms, accuracy, error_count, computed_at, extra)"
      )
      .eq("id", id)
      .single(),
    supabase
      .from("session_events")
      .select("seq, event_type, t_ms, payload")
      .eq("session_id", id)
      .order("seq"),
  ]);
  if (sessionRes.error) {
    throw new Error(`Could not load session: ${sessionRes.error.message}`);
  }
  if (eventsRes.error) {
    throw new Error(`Could not load events: ${eventsRes.error.message}`);
  }
  return {
    session: sessionRes.data as unknown as SessionDetail,
    events: eventsRes.data as unknown as SessionEventRow[],
  };
}

export type OverviewCounts = {
  sessionsToday: number;
  pending: number;
  invalid: number;
  students: number;
};

export async function getOverviewCounts(): Promise<OverviewCounts> {
  const supabase = await createClient();
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const [today, pending, invalid, students] = await Promise.all([
    supabase
      .from("sessions")
      .select("id", { count: "exact", head: true })
      .gte("started_at", todayStart.toISOString()),
    supabase
      .from("sessions")
      .select("id", { count: "exact", head: true })
      .eq("status", "uploaded"),
    supabase
      .from("sessions")
      .select("id", { count: "exact", head: true })
      .eq("status", "invalid"),
    supabase
      .from("students")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
  ]);

  return {
    sessionsToday: today.count ?? 0,
    pending: pending.count ?? 0,
    invalid: invalid.count ?? 0,
    students: students.count ?? 0,
  };
}
