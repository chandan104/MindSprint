import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { CohortComparison } from "@/lib/queries/cohort";

function Row({ label, value, sub }: { label: string; value: number | null; sub?: string }) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-sm">
        <span>
          {label}
          {sub ? <span className="text-muted-foreground"> · {sub}</span> : null}
        </span>
        <span className="font-mono">{value == null ? "—" : `${value}%`}</span>
      </div>
      <div className="bg-muted h-2 w-full overflow-hidden rounded-full">
        <div
          className="h-full rounded-full bg-indigo-500"
          style={{ width: `${value ?? 0}%` }}
        />
      </div>
    </div>
  );
}

export function CohortComparisonCard({ data }: { data: CohortComparison }) {
  if (data.studentOverall == null) return null;
  const vsClass =
    data.classAverage != null ? data.studentOverall - data.classAverage : null;

  return (
    <Card>
      <CardHeader>
        <CardTitle>How this compares</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <Row label="This student" value={data.studentOverall} />
        <Row
          label="Class average"
          value={data.classAverage}
          sub={`${data.classSize} student${data.classSize === 1 ? "" : "s"}`}
        />
        <Row
          label="School average"
          value={data.schoolAverage}
          sub={`${data.schoolSize} student${data.schoolSize === 1 ? "" : "s"}`}
        />
        {vsClass != null && (
          <p className="text-muted-foreground pt-1 text-sm">
            {vsClass > 2
              ? `Above the class average by ${vsClass} points.`
              : vsClass < -2
                ? `Below the class average by ${Math.abs(vsClass)} points — could use encouragement here.`
                : "Right around the class average."}
          </p>
        )}
        <p className="text-muted-foreground text-xs">
          Overall performance index across MindSprint assessments — an
          educational comparison, not a ranking or a measure of ability.
        </p>
      </CardContent>
    </Card>
  );
}
