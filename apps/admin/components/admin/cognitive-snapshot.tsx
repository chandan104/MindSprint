import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  DOMAIN_LABELS,
  type CognitiveDomain,
  type CognitiveProfile,
} from "@/lib/insights/cognitive-score";

const ORDER: CognitiveDomain[] = [
  "workingMemory",
  "attention",
  "processingSpeed",
  "reasoning",
];

function Bar({ value }: { value: number | null }) {
  const pct = value ?? 0;
  const tone =
    value == null
      ? "bg-muted"
      : value >= 80
        ? "bg-emerald-500"
        : value >= 60
          ? "bg-indigo-500"
          : "bg-amber-500";
  return (
    <div className="bg-muted h-2.5 w-full overflow-hidden rounded-full">
      <div
        className={`h-full rounded-full ${tone}`}
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

const TREND_LABEL: Record<CognitiveProfile["trend"], string> = {
  improving: "Improving",
  steady: "Steady",
  declining: "Needs attention",
  insufficient: "Not enough data yet",
};

export function CognitiveSnapshot({ profile }: { profile: CognitiveProfile }) {
  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle>Cognitive snapshot</CardTitle>
        <div className="flex gap-2">
          <Badge variant="outline" className="capitalize">
            {profile.confidence} confidence
          </Badge>
          <Badge
            variant={
              profile.trend === "declining" ? "destructive" : "secondary"
            }
          >
            {TREND_LABEL[profile.trend]}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {profile.overall == null ? (
          <p className="text-muted-foreground text-sm">
            No completed assessments yet — the snapshot appears once sessions
            are recorded.
          </p>
        ) : (
          <>
            <div className="grid gap-3 sm:grid-cols-2">
              {ORDER.map((d) => (
                <div key={d} className="space-y-1">
                  <div className="flex justify-between text-sm">
                    <span>{DOMAIN_LABELS[d]}</span>
                    <span className="text-muted-foreground font-mono">
                      {profile.domains[d] == null ? "—" : `${profile.domains[d]}%`}
                    </span>
                  </div>
                  <Bar value={profile.domains[d]} />
                </div>
              ))}
            </div>

            <div className="flex items-center justify-between border-t pt-3">
              <span className="text-sm font-medium">Overall</span>
              <span className="text-2xl font-semibold">{profile.overall}%</span>
            </div>

            {(profile.strengths.length > 0 ||
              profile.areasToWatch.length > 0) && (
              <div className="grid gap-3 sm:grid-cols-2">
                <div>
                  <p className="text-muted-foreground mb-1 text-xs font-semibold uppercase">
                    Strengths
                  </p>
                  {profile.strengths.length ? (
                    <ul className="text-sm">
                      {profile.strengths.map((d) => (
                        <li key={d}>✅ {DOMAIN_LABELS[d]}</li>
                      ))}
                    </ul>
                  ) : (
                    <p className="text-muted-foreground text-sm">—</p>
                  )}
                </div>
                <div>
                  <p className="text-muted-foreground mb-1 text-xs font-semibold uppercase">
                    Areas to watch
                  </p>
                  {profile.areasToWatch.length ? (
                    <ul className="text-sm">
                      {profile.areasToWatch.map((d) => (
                        <li key={d} className="text-amber-600 dark:text-amber-500">
                          🔎 {DOMAIN_LABELS[d]}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="text-muted-foreground text-sm">—</p>
                  )}
                </div>
              </div>
            )}
          </>
        )}
        <p className="text-muted-foreground text-xs">
          Performance indices within MindSprint assessments — educational
          comparison only, not a measure of ability or any diagnosis.
        </p>
      </CardContent>
    </Card>
  );
}
