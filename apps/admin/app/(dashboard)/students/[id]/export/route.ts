import { createClient } from "@/lib/supabase/server";

// Raw session CSV for one student. Runs as the signed-in user, so RLS
// decides whether any rows are returned at all — a caller who cannot see
// this student gets an empty file, never someone else's data.
function csvCell(v: unknown): string {
  const s = v == null ? "" : String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: student } = await supabase
    .from("students")
    .select("full_name")
    .eq("id", id)
    .maybeSingle();

  const { data, error } = await supabase
    .from("sessions")
    .select(
      "id, module_key, status, was_interrupted, started_at, completed_at, " +
        "level_versions(levels(difficulty)), " +
        "session_metrics(accuracy, error_count, total_time_ms, extra)"
    )
    .eq("student_id", id)
    .order("started_at", { ascending: true });
  if (error) {
    return new Response(`Error: ${error.message}`, { status: 500 });
  }

  const rows = (data ?? []) as unknown as {
    id: string;
    module_key: string;
    status: string;
    was_interrupted: boolean;
    started_at: string;
    completed_at: string | null;
    level_versions: { levels: { difficulty: string } | null } | null;
    session_metrics: {
      accuracy: number | null;
      error_count: number | null;
      total_time_ms: number | null;
      extra: Record<string, unknown>;
    }[];
  }[];

  const header = [
    "session_id",
    "module",
    "difficulty",
    "status",
    "interrupted",
    "started_at",
    "completed_at",
    "accuracy",
    "error_count",
    "total_time_ms",
    "reaction_time_ms",
    "median_decision_ms",
    "hesitation_count",
  ];

  const lines = [header.join(",")];
  for (const r of rows) {
    const m = r.session_metrics[0];
    const extra = (m?.extra ?? {}) as Record<string, unknown>;
    lines.push(
      [
        r.id,
        r.module_key,
        r.level_versions?.levels?.difficulty ?? "",
        r.status,
        r.was_interrupted,
        r.started_at,
        r.completed_at ?? "",
        m?.accuracy ?? "",
        m?.error_count ?? "",
        m?.total_time_ms ?? "",
        extra["reaction_time_ms"] ?? "",
        extra["median_decision_ms"] ?? "",
        extra["hesitation_count"] ?? "",
      ]
        .map(csvCell)
        .join(",")
    );
  }

  const safeName = (student?.full_name ?? "student")
    .replace(/[^a-z0-9]+/gi, "_")
    .toLowerCase();
  return new Response(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="mindsprint_${safeName}.csv"`,
    },
  });
}
