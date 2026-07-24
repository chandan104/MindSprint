// Cognitive scoring: maps a student's canonical session metrics to
// per-domain performance INDICES (0-100). Pure function — same sessions in,
// same indices out — so every number a teacher sees is unit-tested.
//
// IMPORTANT (product law): these are indices of performance INSIDE MindSprint
// assessments, not measures of a child's cognitive ability, and never a
// diagnosis. Speed normalisation bands are provisional engineering estimates,
// to be recalibrated against pilot data.

export type ScoredSession = {
  moduleKey: string;
  startedAt: string;
  accuracy: number | null; // 0..1
  medianDecisionMs: number | null;
  reactionMs: number | null;
  hesitationCount: number | null;
};

export type CognitiveDomain =
  | "workingMemory"
  | "attention"
  | "processingSpeed"
  | "reasoning";

export const DOMAIN_LABELS: Record<CognitiveDomain, string> = {
  workingMemory: "Working Memory",
  attention: "Attention",
  processingSpeed: "Processing Speed",
  reasoning: "Reasoning",
};

// Which module feeds which cognitive domain.
const MODULE_DOMAIN: Record<string, CognitiveDomain> = {
  memory_recall: "workingMemory",
  attention_focus: "attention",
  visual_search: "attention",
  math_speed: "processingSpeed",
  pattern_recognition: "reasoning",
  sequence_logic: "reasoning",
};

export type CognitiveProfile = {
  domains: Record<CognitiveDomain, number | null>; // null = no data yet
  overall: number | null;
  trend: "improving" | "steady" | "declining" | "insufficient";
  confidence: "low" | "medium" | "high";
  sessionCount: number;
  strengths: CognitiveDomain[];
  areasToWatch: CognitiveDomain[];
};

/** Median-decision-time → 0..100 speed sub-score. Provisional band:
 * <=1000ms = 100, >=8000ms = 0, linear between. */
function speedScore(medianMs: number | null): number | null {
  if (medianMs == null) return null;
  if (medianMs <= 1000) return 100;
  if (medianMs >= 8000) return 0;
  return Math.round(100 * (1 - (medianMs - 1000) / 7000));
}

/** One session's 0..100 performance in its domain. Accuracy-led, blended
 * with speed; processing-speed weights speed more since it IS the point. */
function sessionScore(s: ScoredSession, domain: CognitiveDomain): number | null {
  const acc = s.accuracy == null ? null : Math.round(s.accuracy * 100);
  const spd = speedScore(s.medianDecisionMs);
  if (acc == null && spd == null) return null;
  if (acc == null) return spd;
  if (spd == null) return acc;
  const speedWeight = domain === "processingSpeed" ? 0.6 : 0.3;
  return Math.round(acc * (1 - speedWeight) + spd * speedWeight);
}

function mean(xs: number[]): number | null {
  return xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null;
}

export function computeCognitiveProfile(
  sessions: ScoredSession[]
): CognitiveProfile {
  const byDomain: Record<CognitiveDomain, number[]> = {
    workingMemory: [],
    attention: [],
    processingSpeed: [],
    reasoning: [],
  };

  const ordered = [...sessions].sort(
    (a, b) => Date.parse(a.startedAt) - Date.parse(b.startedAt)
  );

  for (const s of ordered) {
    const domain = MODULE_DOMAIN[s.moduleKey];
    if (!domain) continue;
    const score = sessionScore(s, domain);
    if (score != null) byDomain[domain].push(score);
  }

  const domains = {
    workingMemory: mean(byDomain.workingMemory),
    attention: mean(byDomain.attention),
    processingSpeed: mean(byDomain.processingSpeed),
    reasoning: mean(byDomain.reasoning),
  };

  const present = (Object.values(domains).filter((v) => v != null) as number[]);
  const overall = mean(present);

  // Trend: overall of the earlier half vs the later half of all sessions.
  const perSession = ordered
    .map((s) => {
      const d = MODULE_DOMAIN[s.moduleKey];
      return d ? sessionScore(s, d) : null;
    })
    .filter((v): v is number => v != null);
  let trend: CognitiveProfile["trend"] = "insufficient";
  if (perSession.length >= 4) {
    const mid = Math.floor(perSession.length / 2);
    const early = mean(perSession.slice(0, mid))!;
    const late = mean(perSession.slice(perSession.length - mid))!;
    const delta = late - early;
    trend = delta >= 5 ? "improving" : delta <= -5 ? "declining" : "steady";
  }

  const n = ordered.length;
  const confidence = n >= 10 ? "high" : n >= 3 ? "medium" : "low";

  const rankable = (Object.entries(domains) as [CognitiveDomain, number | null][])
    .filter((e) => e[1] != null) as [CognitiveDomain, number][];
  const strengths = rankable
    .filter(([, v]) => v >= 80)
    .sort((a, b) => b[1] - a[1])
    .map(([d]) => d);
  const areasToWatch = rankable
    .filter(([, v]) => v < 60)
    .sort((a, b) => a[1] - b[1])
    .map(([d]) => d);

  return {
    domains,
    overall,
    trend,
    confidence,
    sessionCount: n,
    strengths,
    areasToWatch,
  };
}
