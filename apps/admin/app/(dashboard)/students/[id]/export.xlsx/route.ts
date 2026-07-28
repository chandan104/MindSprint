import writeXlsxFile from "write-excel-file/node";
import { createClient } from "@/lib/supabase/server";
import {
  computeCognitiveProfile,
  DOMAIN_LABELS,
  type CognitiveDomain,
  type ScoredSession,
} from "@/lib/insights/cognitive-score";

// Full analytics workbook for one student: a Summary sheet (cognitive
// indices) and a Sessions sheet (every session's metrics). Runs as the
// signed-in user — RLS decides visibility.
const MODULE_NAMES: Record<string, string> = {
  memory_recall: "Memory Recall",
  math_speed: "Mathematics Speed",
  attention_focus: "Focus Tap",
  pattern_recognition: "Pattern Detective",
  visual_search: "Visual Search",
  sequence_logic: "Sequence Logic",
};

const DOMAINS: CognitiveDomain[] = [
  "workingMemory",
  "attention",
  "processingSpeed",
  "reasoning",
];

type Metrics = {
  accuracy: number | null;
  error_count: number | null;
  total_time_ms: number | null;
  extra: Record<string, unknown>;
};
type Row = {
  id: string;
  module_key: string;
  status: string;
  was_interrupted: boolean;
  started_at: string;
  level_versions: { levels: { difficulty: string } | null } | null;
  session_metrics: Metrics[];
};

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: student } = await supabase
    .from("students")
    .select("full_name, classes(name)")
    .eq("id", id)
    .maybeSingle();

  const { data, error } = await supabase
    .from("sessions")
    .select(
      "id, module_key, status, was_interrupted, started_at, " +
        "level_versions(levels(difficulty)), " +
        "session_metrics(accuracy, error_count, total_time_ms, extra)"
    )
    .eq("student_id", id)
    .order("started_at", { ascending: true });
  if (error) return new Response(`Error: ${error.message}`, { status: 500 });

  const rows = (data ?? []) as unknown as Row[];
  const num = (e: Record<string, unknown>, k: string) =>
    typeof e[k] === "number" ? (e[k] as number) : null;

  const trustworthy = rows.filter(
    (r) => r.status === "validated" && !r.was_interrupted
  );
  const scored: ScoredSession[] = trustworthy.map((r) => {
    const e = (r.session_metrics[0]?.extra ?? {}) as Record<string, unknown>;
    return {
      moduleKey: r.module_key,
      startedAt: r.started_at,
      accuracy: r.session_metrics[0]?.accuracy ?? null,
      medianDecisionMs: num(e, "median_decision_ms"),
      reactionMs: num(e, "reaction_time_ms"),
      hesitationCount: num(e, "hesitation_count"),
    };
  });
  const profile = computeCognitiveProfile(scored);

  const headerStyle = { fontWeight: "bold" as const };

  const summarySheet = [
    [{ value: "Skill Lab — Cognitive Summary", fontWeight: "bold" as const, span: 2 }],
    [{ value: "Student" }, { value: student?.full_name ?? "" }],
    [
      { value: "Class" },
      {
        value:
          (student?.classes as { name: string } | null)?.name ?? "",
      },
    ],
    [{ value: "Generated" }, { value: new Date().toISOString().slice(0, 10) }],
    [{ value: "Assessments" }, { value: trustworthy.length, type: Number }],
    [],
    [{ value: "Domain", ...headerStyle }, { value: "Index (%)", ...headerStyle }],
    ...DOMAINS.map((d) => [
      { value: DOMAIN_LABELS[d] },
      profile.domains[d] == null
        ? { value: "—" }
        : { value: profile.domains[d]!, type: Number },
    ]),
    [
      { value: "Overall", fontWeight: "bold" as const },
      profile.overall == null
        ? { value: "—" }
        : { value: profile.overall, type: Number, fontWeight: "bold" as const },
    ],
    [{ value: "Trend" }, { value: profile.trend }],
    [{ value: "Confidence" }, { value: profile.confidence }],
  ];

  const sessionsHeader = [
    "Session ID",
    "Module",
    "Difficulty",
    "Status",
    "Interrupted",
    "Started",
    "Accuracy %",
    "Errors",
    "Total time (ms)",
    "Reaction (ms)",
    "Median decision (ms)",
    "Hesitations",
  ].map((v) => ({ value: v, fontWeight: "bold" as const }));

  const sessionRows = rows.map((r) => {
    const m = r.session_metrics[0];
    const e = (m?.extra ?? {}) as Record<string, unknown>;
    return [
      { value: r.id },
      { value: MODULE_NAMES[r.module_key] ?? r.module_key },
      { value: r.level_versions?.levels?.difficulty ?? "" },
      { value: r.status },
      { value: r.was_interrupted ? "yes" : "no" },
      { value: r.started_at.slice(0, 19).replace("T", " ") },
      m?.accuracy == null
        ? { value: "" }
        : { value: Math.round(m.accuracy * 100), type: Number },
      { value: m?.error_count ?? 0, type: Number },
      { value: m?.total_time_ms ?? 0, type: Number },
      { value: num(e, "reaction_time_ms") ?? "", type: Number },
      { value: num(e, "median_decision_ms") ?? "", type: Number },
      { value: num(e, "hesitation_count") ?? "", type: Number },
    ];
  });

  // The library's multi-sheet generics don't accept two sheets with
  // different cell shapes; the runtime is fine, so relax the call typing.
  const write = writeXlsxFile as unknown as (
    data: unknown,
    opts: unknown
  ) => Promise<Buffer>;
  const buffer = await write([summarySheet, [sessionsHeader, ...sessionRows]], {
    sheets: ["Summary", "Sessions"],
    buffer: true,
  });

  const safeName = (student?.full_name ?? "student")
    .replace(/[^a-z0-9]+/gi, "_")
    .toLowerCase();
  return new Response(new Uint8Array(buffer), {
    headers: {
      "Content-Type":
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="mindsprint_${safeName}.xlsx"`,
    },
  });
}
