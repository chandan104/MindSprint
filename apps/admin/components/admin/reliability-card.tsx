import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { computeReliability, type ReliabilityInput } from "@/lib/insights/reliability";

const RING: Record<string, string> = {
  high: "text-emerald-600 dark:text-emerald-400",
  medium: "text-amber-600 dark:text-amber-500",
  low: "text-rose-600 dark:text-rose-400",
};

/** Admin-only integrity signal. It describes the testing *conditions*, never
 * the child's performance, and is never fed into any cognitive score. */
export function ReliabilityCard(props: ReliabilityInput) {
  const { score, level, flags } = computeReliability(props);
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">Assessment reliability</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-wrap items-center gap-6">
        <div className={`text-4xl font-bold tabular-nums ${RING[level]}`}>
          {score}%
        </div>
        <ul className="flex-1 space-y-1 text-sm">
          {flags.map((f, i) => (
            <li key={i} className="flex items-center gap-2">
              <span aria-hidden>{f.severity === "warn" ? "⚠" : "✓"}</span>
              <span
                className={
                  f.severity === "warn"
                    ? "text-amber-700 dark:text-amber-500"
                    : "text-muted-foreground"
                }
              >
                {f.label}
              </span>
            </li>
          ))}
        </ul>
        <p className="text-muted-foreground w-full text-xs">
          Reflects testing conditions only (interruptions, timing, completion).
          It does <strong>not</strong> affect the child&apos;s cognitive scores.
        </p>
      </CardContent>
    </Card>
  );
}
