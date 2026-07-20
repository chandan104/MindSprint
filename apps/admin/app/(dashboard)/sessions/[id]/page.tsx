import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SessionReplayer } from "@/components/admin/session-replayer";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { getSessionDetail } from "@/lib/queries/sessions";

function ms(value: unknown): string {
  if (typeof value !== "number") return "—";
  return value >= 1000 ? `${(value / 1000).toFixed(2)}s` : `${value}ms`;
}

export default async function SessionDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { session, events } = await getSessionDetail(id);
  const canonical = session.session_metrics[0];
  const extra = (canonical?.extra ?? {}) as Record<string, unknown>;
  const provisional = session.provisional_metrics ?? null;

  // Drift audit: provisional (device) vs canonical (server) headline values.
  const provisionalAccuracy =
    provisional && typeof provisional["accuracy"] === "number"
      ? (provisional["accuracy"] as number)
      : null;
  const accuracyAgrees =
    canonical?.accuracy != null && provisionalAccuracy != null
      ? Math.abs(canonical.accuracy - provisionalAccuracy) < 0.005
      : null;

  const stats: { label: string; value: string }[] = [
    { label: "Total time", value: ms(canonical?.total_time_ms) },
    {
      label: "Accuracy",
      value:
        canonical?.accuracy != null
          ? `${Math.round(canonical.accuracy * 100)}%`
          : "—",
    },
    { label: "Errors", value: `${canonical?.error_count ?? "—"}` },
    { label: "Reaction", value: ms(extra["reaction_time_ms"]) },
    { label: "Recall", value: ms(extra["recall_time_ms"]) },
    { label: "Median decision", value: ms(extra["median_decision_ms"]) },
    { label: "Fastest decision", value: ms(extra["fastest_decision_ms"]) },
    { label: "Longest pause", value: ms(extra["longest_pause_ms"]) },
    { label: "Hesitations", value: `${extra["hesitation_count"] ?? "—"}` },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-2xl font-semibold">
            {session.students?.full_name ?? "Unknown student"}
          </h1>
          <p className="text-muted-foreground text-sm">
            {session.level_versions?.levels?.name ?? session.module_key} ·{" "}
            <span className="capitalize">
              {session.level_versions?.levels?.difficulty ?? ""}
            </span>{" "}
            · {new Date(session.started_at).toLocaleString()}
          </p>
        </div>
        <div className="flex gap-2">
          {session.was_interrupted && (
            <Badge variant="destructive">Interrupted — timing untrusted</Badge>
          )}
          {accuracyAgrees === false && (
            <Badge variant="destructive">Device/server metric drift</Badge>
          )}
          <Badge variant={session.status === "validated" ? "default" : "secondary"}>
            {session.status}
          </Badge>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        {stats.map((stat) => (
          <Card key={stat.label}>
            <CardHeader className="pb-1">
              <CardTitle className="text-muted-foreground text-xs font-medium uppercase tracking-wide">
                {stat.label}
              </CardTitle>
            </CardHeader>
            <CardContent className="text-xl font-semibold">
              {stat.value}
            </CardContent>
          </Card>
        ))}
      </div>

      <div>
        <h2 className="mb-2 text-lg font-semibold">Session replay</h2>
        <SessionReplayer
          events={events}
          studentName={session.students?.full_name ?? "Student"}
        />
      </div>

      <div>
        <h2 className="mb-2 text-lg font-semibold">
          Event log{" "}
          <span className="text-muted-foreground text-sm font-normal">
            ({events.length} events — the session&apos;s source of truth)
          </span>
        </h2>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-14">#</TableHead>
              <TableHead className="w-24">t (ms)</TableHead>
              <TableHead>Event</TableHead>
              <TableHead>Detail</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {events.map((event) => (
              <TableRow key={event.seq}>
                <TableCell className="text-muted-foreground">
                  {event.seq}
                </TableCell>
                <TableCell className="font-mono">{event.t_ms}</TableCell>
                <TableCell className="font-medium">{event.event_type}</TableCell>
                <TableCell className="text-muted-foreground max-w-md truncate font-mono text-xs">
                  {summarize(event.event_type, event.payload)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}

function summarize(type: string, payload: Record<string, unknown>): string {
  switch (type) {
    case "tap_registered":
      return `${payload["label"] ?? ""} — ${
        payload["is_correct"] === true
          ? "correct"
          : payload["is_correct"] === false
            ? "wrong"
            : "neutral"
      }`;
    case "question_displayed":
      return `${payload["question_text"] ?? ""} (answer: ${payload["expected_answer"] ?? "?"})`;
    case "sequence_display_started": {
      const sequence = payload["sequence"];
      return Array.isArray(sequence)
        ? sequence
            .map((item) => (item as Record<string, unknown>)["label"])
            .join(" → ")
        : "";
    }
    case "item_displayed":
      return `${payload["label"] ?? ""} @ position ${payload["position_index"] ?? "?"}`;
    case "answer_submitted":
      return `${payload["answer"] ?? ""} — ${payload["is_correct"] === true ? "correct" : "wrong"}`;
    case "session_aborted":
      return `${payload["reason"] ?? ""}`;
    default:
      return "";
  }
}
