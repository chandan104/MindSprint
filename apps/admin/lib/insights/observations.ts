// The Cognitive Intelligence voice, v1: plain-language observations derived
// from canonical session metrics. Pure functions — same sessions in, same
// words out — so the exact sentences teachers read are unit-tested.
//
// Guardrails (product law, not style):
// - Only validated, uninterrupted sessions are considered (caller filters).
// - Observations describe performance INSIDE the assessments, comparatively
//   and hedged. Never diagnostic, never clinical, never about the child's
//   abilities in general.

export type SessionPoint = {
  startedAt: string;
  accuracy: number | null; // 0..1
  medianDecisionMs: number | null;
  hesitationCount: number | null;
};

export type Observation = {
  kind: "positive" | "neutral" | "attention";
  text: string;
};

const MIN_SESSIONS = 3;

function mean(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function stddev(values: number[]): number | null {
  const m = mean(values);
  if (m == null || values.length < 2) return null;
  return Math.sqrt(mean(values.map((v) => (v - m) ** 2)) ?? 0);
}

function halves<T>(points: T[]): [T[], T[]] {
  const mid = Math.floor(points.length / 2);
  return [points.slice(0, mid), points.slice(points.length - mid)];
}

/** Observations for one module's sessions, oldest first. */
export function observeModule(
  moduleName: string,
  points: SessionPoint[]
): Observation[] {
  if (points.length < MIN_SESSIONS) {
    return [
      {
        kind: "neutral",
        text: `Not enough ${moduleName} sessions yet to see a trend — insights appear after ${MIN_SESSIONS} completed sessions.`,
      },
    ];
  }

  const observations: Observation[] = [];
  const n = points.length;

  const accuracies = points
    .map((p) => p.accuracy)
    .filter((a): a is number => a != null);
  const [firstAcc, lastAcc] = halves(accuracies);
  const firstAccMean = mean(firstAcc);
  const lastAccMean = mean(lastAcc);

  let accuracyTrend: "up" | "down" | "steady" | null = null;
  if (firstAccMean != null && lastAccMean != null) {
    const delta = lastAccMean - firstAccMean;
    if (delta >= 0.08) accuracyTrend = "up";
    else if (delta <= -0.08) accuracyTrend = "down";
    else accuracyTrend = "steady";
  }

  const decisions = points
    .map((p) => p.medianDecisionMs)
    .filter((d): d is number => d != null);
  const [firstDec, lastDec] = halves(decisions);
  const firstDecMean = mean(firstDec);
  const lastDecMean = mean(lastDec);
  const speedImproved =
    firstDecMean != null &&
    lastDecMean != null &&
    lastDecMean <= firstDecMean * 0.85;

  if (accuracyTrend === "up") {
    observations.push({
      kind: "positive",
      text: `${moduleName} accuracy improved across the last ${n} sessions.`,
    });
  } else if (accuracyTrend === "steady" && speedImproved) {
    observations.push({
      kind: "positive",
      text: `${moduleName} accuracy stayed steady while decisions got faster — a strong sign of growing confidence.`,
    });
  } else if (accuracyTrend === "steady" && n >= 4) {
    observations.push({
      kind: "neutral",
      text: `${moduleName} accuracy has stayed steady across ${n} sessions.`,
    });
  } else if (accuracyTrend === "down") {
    observations.push({
      kind: "attention",
      text: `${moduleName} accuracy dipped in recent sessions — could be worth revisiting together.`,
    });
  }

  if (speedImproved && accuracyTrend !== "steady") {
    observations.push({
      kind: "positive",
      text: `Decisions in ${moduleName} became faster over recent sessions.`,
    });
  }

  const firstSpread = stddev(firstDec);
  const lastSpread = stddev(lastDec);
  if (
    n >= 4 &&
    firstSpread != null &&
    lastSpread != null &&
    firstSpread > 0 &&
    lastSpread <= firstSpread * 0.6
  ) {
    observations.push({
      kind: "positive",
      text: `Decision speed in ${moduleName} became noticeably more consistent.`,
    });
  }

  const hesitations = points
    .map((p) => p.hesitationCount)
    .filter((h): h is number => h != null);
  const [firstHes, lastHes] = halves(hesitations);
  const firstHesMean = mean(firstHes);
  const lastHesMean = mean(lastHes);
  if (
    firstHesMean != null &&
    lastHesMean != null &&
    firstHesMean - lastHesMean >= 1
  ) {
    observations.push({
      kind: "positive",
      text: `Hesitation during ${moduleName} decreased across recent sessions.`,
    });
  }

  if (observations.length === 0) {
    observations.push({
      kind: "neutral",
      text: `${moduleName} performance is holding its own — no strong trend yet across ${n} sessions.`,
    });
  }

  return observations;
}
