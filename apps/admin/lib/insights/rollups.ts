// Time-bucketed rollups for the student dashboard: group sessions into ISO
// weeks or calendar months and average a metric per bucket. Pure — same
// sessions in, same buckets out — so the charts are unit-tested.

export type RollupPoint = { label: string; value: number };

type Dated = { startedAt: string; value: number | null };

function isoWeekKey(d: Date): string {
  // ISO-8601 week: Thursday-anchored. Returns e.g. "2026-W30".
  const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil(
    ((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7
  );
  return `${date.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function monthKey(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

function bucket(items: Dated[], keyOf: (d: Date) => string): RollupPoint[] {
  const groups = new Map<string, number[]>();
  for (const it of items) {
    if (it.value == null) continue;
    const key = keyOf(new Date(it.startedAt));
    groups.set(key, [...(groups.get(key) ?? []), it.value]);
  }
  return [...groups.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([label, values]) => ({
      label,
      value: Math.round(values.reduce((a, b) => a + b, 0) / values.length),
    }));
}

export function weeklyRollup(items: Dated[]): RollupPoint[] {
  return bucket(items, isoWeekKey);
}

export function monthlyRollup(items: Dated[]): RollupPoint[] {
  return bucket(items, monthKey);
}

export type ModuleAverage = { moduleKey: string; avgAccuracy: number | null; sessions: number };

/** Per-module accuracy averages for the module-comparison chart. */
export function moduleAverages(
  sessions: { moduleKey: string; accuracy: number | null }[]
): ModuleAverage[] {
  const groups = new Map<string, number[]>();
  const counts = new Map<string, number>();
  for (const s of sessions) {
    counts.set(s.moduleKey, (counts.get(s.moduleKey) ?? 0) + 1);
    if (s.accuracy != null) {
      groups.set(s.moduleKey, [...(groups.get(s.moduleKey) ?? []), s.accuracy]);
    }
  }
  return [...counts.entries()].map(([moduleKey, sessions]) => {
    const accs = groups.get(moduleKey) ?? [];
    return {
      moduleKey,
      sessions,
      avgAccuracy: accs.length
        ? Math.round((accs.reduce((a, b) => a + b, 0) / accs.length) * 100)
        : null,
    };
  });
}
