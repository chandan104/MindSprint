// Simple horizontal bar comparison (module accuracy, etc). Dependency-free.
export function BarCompare({
  items,
  unit = "%",
}: {
  items: { label: string; value: number | null }[];
  unit?: string;
}) {
  const max = Math.max(100, ...items.map((i) => i.value ?? 0));
  return (
    <div className="space-y-2">
      {items.map((it) => (
        <div key={it.label} className="space-y-1">
          <div className="flex justify-between text-sm">
            <span>{it.label}</span>
            <span className="text-muted-foreground font-mono">
              {it.value == null ? "—" : `${it.value}${unit}`}
            </span>
          </div>
          <div className="bg-muted h-2 w-full overflow-hidden rounded-full">
            <div
              className="h-full rounded-full bg-indigo-500"
              style={{ width: `${((it.value ?? 0) / max) * 100}%` }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}
