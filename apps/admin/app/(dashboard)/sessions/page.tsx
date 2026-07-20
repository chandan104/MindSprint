import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { listRecentSessions } from "@/lib/queries/sessions";

const MODULE_NAMES: Record<string, string> = {
  memory_recall: "Memory Recall",
  math_speed: "Mathematics Speed",
  attention_focus: "Focus Tap",
  pattern_recognition: "Pattern Detective",
  visual_search: "Visual Search",
  sequence_logic: "Sequence Logic",
};

function statusBadge(status: string, interrupted: boolean) {
  if (interrupted) return <Badge variant="destructive">Interrupted</Badge>;
  switch (status) {
    case "validated":
      return <Badge>Validated</Badge>;
    case "uploaded":
      return <Badge variant="secondary">Processing</Badge>;
    default:
      return <Badge variant="destructive">Needs review</Badge>;
  }
}

export default async function SessionsPage() {
  const sessions = await listRecentSessions();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Sessions</h1>
        <p className="text-muted-foreground text-sm">
          Most recent assessment sessions. Metrics are canonical — computed
          server-side from the raw event log.
        </p>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Student</TableHead>
            <TableHead>Assessment</TableHead>
            <TableHead>Difficulty</TableHead>
            <TableHead>When</TableHead>
            <TableHead>Time</TableHead>
            <TableHead>Accuracy</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sessions.map((session) => {
            const metrics = session.session_metrics[0];
            const difficulty = session.level_versions?.levels?.difficulty;
            return (
              <TableRow key={session.id}>
                <TableCell className="font-medium">
                  <Link
                    href={`/sessions/${session.id}`}
                    className="hover:underline"
                  >
                    {session.students?.full_name ?? "Unknown"}
                  </Link>
                </TableCell>
                <TableCell>
                  {MODULE_NAMES[session.module_key] ?? session.module_key}
                </TableCell>
                <TableCell className="capitalize">{difficulty ?? "—"}</TableCell>
                <TableCell>
                  {new Date(session.started_at).toLocaleString()}
                </TableCell>
                <TableCell>
                  {metrics?.total_time_ms != null
                    ? `${(metrics.total_time_ms / 1000).toFixed(1)}s`
                    : "—"}
                </TableCell>
                <TableCell>
                  {metrics?.accuracy != null
                    ? `${Math.round(metrics.accuracy * 100)}%`
                    : "—"}
                </TableCell>
                <TableCell>
                  {statusBadge(session.status, session.was_interrupted)}
                </TableCell>
              </TableRow>
            );
          })}
          {sessions.length === 0 && (
            <TableRow>
              <TableCell
                colSpan={7}
                className="text-muted-foreground text-center"
              >
                No sessions yet. They appear here moments after a student
                finishes an assessment.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
