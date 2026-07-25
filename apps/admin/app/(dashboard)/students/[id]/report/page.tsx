import { CognitiveSnapshot } from "@/components/admin/cognitive-snapshot";
import { CohortComparisonCard } from "@/components/admin/cohort-comparison";
import { PrintButton } from "@/components/admin/print-button";
import { RadarChart } from "@/components/admin/radar-chart";
import {
  computeCognitiveProfile,
  DOMAIN_LABELS,
  type CognitiveDomain,
  type ScoredSession,
} from "@/lib/insights/cognitive-score";
import { observeModule, type SessionPoint } from "@/lib/insights/observations";
import { getCohortComparison } from "@/lib/queries/cohort";
import { getStudentReport, type ReportSession } from "@/lib/queries/student-report";

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

function scored(s: ReportSession): ScoredSession {
  const extra = (s.session_metrics[0]?.extra ?? {}) as Record<string, unknown>;
  const num = (k: string) =>
    typeof extra[k] === "number" ? (extra[k] as number) : null;
  return {
    moduleKey: s.module_key,
    startedAt: s.started_at,
    accuracy: s.session_metrics[0]?.accuracy ?? null,
    medianDecisionMs: num("median_decision_ms"),
    reactionMs: num("reaction_time_ms"),
    hesitationCount: num("hesitation_count"),
  };
}

function point(s: ReportSession): SessionPoint {
  const extra = (s.session_metrics[0]?.extra ?? {}) as Record<string, unknown>;
  return {
    startedAt: s.started_at,
    accuracy: s.session_metrics[0]?.accuracy ?? null,
    medianDecisionMs:
      typeof extra["median_decision_ms"] === "number"
        ? (extra["median_decision_ms"] as number)
        : null,
    hesitationCount:
      typeof extra["hesitation_count"] === "number"
        ? (extra["hesitation_count"] as number)
        : null,
  };
}

export default async function StudentReportPrintPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [{ student, sessions }, cohort] = await Promise.all([
    getStudentReport(id),
    getCohortComparison(id),
  ]);

  const trustworthy = sessions.filter(
    (s) => s.status === "validated" && !s.was_interrupted
  );
  const profile = computeCognitiveProfile(trustworthy.map(scored));

  const byModule = new Map<string, ReportSession[]>();
  for (const s of trustworthy) {
    byModule.set(s.module_key, [...(byModule.get(s.module_key) ?? []), s]);
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold">MindSprint Assessment Report</h1>
          <p className="text-muted-foreground text-sm">
            {student.full_name} · {student.classes?.name ?? "No class"}
            {student.roll_number ? ` · Roll ${student.roll_number}` : ""}
          </p>
          <p className="text-muted-foreground text-xs">
            Generated {new Date().toLocaleDateString()} ·{" "}
            {trustworthy.length} assessment
            {trustworthy.length === 1 ? "" : "s"}
          </p>
        </div>
        <PrintButton />
      </div>

      <div className="print-avoid-break">
        <CognitiveSnapshot profile={profile} />
      </div>

      {profile.overall != null && (
        <div className="print-avoid-break flex flex-wrap items-center justify-center gap-6 rounded-xl border p-4">
          <RadarChart
            axes={DOMAINS.map((d) => ({
              label: DOMAIN_LABELS[d].split(" ")[0],
              value: profile.domains[d],
            }))}
          />
        </div>
      )}

      <div className="print-avoid-break">
        <CohortComparisonCard data={cohort} />
      </div>

      <div className="print-avoid-break space-y-3">
        <h2 className="text-lg font-semibold">By assessment</h2>
        {[...byModule.entries()].map(([moduleKey, moduleSessions]) => {
          const name = MODULE_NAMES[moduleKey] ?? moduleKey;
          const observations = observeModule(name, moduleSessions.map(point));
          const accuracies = moduleSessions
            .map((s) => s.session_metrics[0]?.accuracy)
            .filter((a): a is number => a != null);
          const avgAcc = accuracies.length
            ? Math.round(
                (accuracies.reduce((a, b) => a + b, 0) / accuracies.length) * 100
              )
            : null;
          return (
            <div key={moduleKey} className="rounded-lg border p-3">
              <div className="flex justify-between">
                <span className="font-medium">{name}</span>
                <span className="text-muted-foreground text-sm">
                  {moduleSessions.length} session
                  {moduleSessions.length === 1 ? "" : "s"} ·{" "}
                  {avgAcc == null ? "—" : `${avgAcc}% avg accuracy`}
                </span>
              </div>
              <ul className="mt-1 space-y-0.5 text-sm">
                {observations.map((o, i) => (
                  <li key={i}>• {o.text}</li>
                ))}
              </ul>
            </div>
          );
        })}
        {byModule.size === 0 && (
          <p className="text-muted-foreground text-sm">
            No completed assessments yet.
          </p>
        )}
      </div>

      <p className="text-muted-foreground border-t pt-4 text-xs">
        This report describes performance within MindSprint educational
        assessments. It is not a psychological, medical, or diagnostic
        evaluation. Indices are educational comparisons intended to support
        teaching, not to label or rank children.
      </p>
    </div>
  );
}
