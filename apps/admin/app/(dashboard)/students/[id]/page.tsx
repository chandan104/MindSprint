import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { AddNoteForm } from "@/components/admin/add-note-form";
import { EraseStudentDialog } from "@/components/admin/erase-student-dialog";
import { Sparkline } from "@/components/admin/sparkline";
import { eraseStudent } from "@/lib/actions/erasure";
import { addTeacherNote } from "@/lib/actions/notes";
import {
  observeModule,
  type Observation,
  type SessionPoint,
} from "@/lib/insights/observations";
import {
  currentUserRole,
  getStudentReport,
  type ReportSession,
} from "@/lib/queries/student-report";

const MODULE_NAMES: Record<string, string> = {
  memory_recall: "Memory Recall",
  math_speed: "Mathematics Speed",
  attention_focus: "Focus Tap",
  pattern_recognition: "Pattern Detective",
  visual_search: "Visual Search",
  sequence_logic: "Sequence Logic",
};

function toPoint(session: ReportSession): SessionPoint {
  const metrics = session.session_metrics[0];
  const extra = (metrics?.extra ?? {}) as Record<string, unknown>;
  return {
    startedAt: session.started_at,
    accuracy: metrics?.accuracy ?? null,
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

function observationBadge(kind: Observation["kind"]) {
  switch (kind) {
    case "positive":
      return "✅";
    case "attention":
      return "🔎";
    default:
      return "•";
  }
}

export default async function StudentReportPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [{ student, sessions, notes }, role] = await Promise.all([
    getStudentReport(id),
    currentUserRole(),
  ]);
  const isTeacher = role === "teacher";
  const canErase = role === "school_admin" || role === "super_admin";

  // Trends use only trustworthy data: validated and uninterrupted.
  const trustworthy = sessions.filter(
    (s) => s.status === "validated" && !s.was_interrupted
  );
  const byModule = new Map<string, ReportSession[]>();
  for (const session of trustworthy) {
    byModule.set(session.module_key, [
      ...(byModule.get(session.module_key) ?? []),
      session,
    ]);
  }

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">{student.full_name}</h1>
          <p className="text-muted-foreground text-sm">
            {student.classes?.name ?? "No class"}
            {student.roll_number ? ` · Roll ${student.roll_number}` : ""} ·{" "}
            {sessions.length} session{sessions.length === 1 ? "" : "s"} recorded
          </p>
        </div>
        {canErase && (
          <EraseStudentDialog
            studentName={student.full_name}
            action={eraseStudent.bind(null, id)}
          />
        )}
      </div>

      {byModule.size === 0 && (
        <Card>
          <CardContent className="text-muted-foreground py-8 text-center text-sm">
            No completed assessments yet. Trends and observations appear after
            the first validated sessions.
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4 lg:grid-cols-2">
        {[...byModule.entries()].map(([moduleKey, moduleSessions]) => {
          const moduleName = MODULE_NAMES[moduleKey] ?? moduleKey;
          const points = moduleSessions.map(toPoint);
          const observations = observeModule(moduleName, points);
          const accuracySeries = points
            .map((p) => p.accuracy)
            .filter((a): a is number => a != null)
            .map((a) => a * 100);
          const speedSeries = points
            .map((p) => p.medianDecisionMs)
            .filter((d): d is number => d != null);

          return (
            <Card key={moduleKey}>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center justify-between text-base">
                  {moduleName}
                  <span className="text-muted-foreground text-xs font-normal">
                    {moduleSessions.length} session
                    {moduleSessions.length === 1 ? "" : "s"}
                  </span>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex flex-wrap gap-6">
                  <div>
                    <p className="text-muted-foreground mb-1 text-xs uppercase tracking-wide">
                      Accuracy
                    </p>
                    <div className="text-emerald-600">
                      <Sparkline values={accuracySeries} />
                    </div>
                  </div>
                  <div>
                    <p className="text-muted-foreground mb-1 text-xs uppercase tracking-wide">
                      Decision time
                    </p>
                    <div className="text-indigo-500">
                      <Sparkline values={speedSeries} invert />
                    </div>
                  </div>
                </div>
                <ul className="space-y-1.5">
                  {observations.map((obs, i) => (
                    <li key={i} className="flex gap-2 text-sm">
                      <span aria-hidden>{observationBadge(obs.kind)}</span>
                      <span
                        className={
                          obs.kind === "attention"
                            ? "text-amber-600 dark:text-amber-500"
                            : undefined
                        }
                      >
                        {obs.text}
                      </span>
                    </li>
                  ))}
                </ul>
                <div className="text-muted-foreground text-xs">
                  {moduleSessions
                    .slice(-3)
                    .reverse()
                    .map((session) => (
                      <Link
                        key={session.id}
                        href={`/sessions/${session.id}`}
                        className="mr-3 underline-offset-2 hover:underline"
                      >
                        {new Date(session.started_at).toLocaleDateString()} ↗
                      </Link>
                    ))}
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <div className="space-y-3">
        <h2 className="text-lg font-semibold">
          Teacher notes{" "}
          <span className="text-muted-foreground text-sm font-normal">
            ({notes.length})
          </span>
        </h2>
        {isTeacher && <AddNoteForm action={addTeacherNote.bind(null, id)} />}
        {notes.length === 0 && (
          <p className="text-muted-foreground text-sm">
            No notes yet.{" "}
            {isTeacher
              ? "Your observations here travel with the student's record."
              : "Teachers can add observations from their account."}
          </p>
        )}
        {notes.map((note) => (
          <Card key={note.id}>
            <CardContent className="space-y-1 py-4">
              <p className="text-sm whitespace-pre-wrap">{note.body}</p>
              <p className="text-muted-foreground text-xs">
                {note.profiles?.full_name ?? "Teacher"} ·{" "}
                {new Date(note.created_at).toLocaleString()}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      <p className="text-muted-foreground max-w-2xl text-xs">
        <Badge variant="outline" className="mr-2">
          Note
        </Badge>
        Observations describe performance within MindSprint assessments only.
        They are educational comparisons, not measures of ability or any kind
        of diagnosis.
      </p>
    </div>
  );
}
