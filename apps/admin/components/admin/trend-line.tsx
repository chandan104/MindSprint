// Dependency-free labeled SVG line chart for a single metric over sessions.
// Distinct from the tiny Sparkline: has axes labels, points, and a value
// range. invert=true for "lower is better" series (times, hesitation).
export function TrendLine({
  values,
  label,
  unit = "",
  invert = false,
  height = 120,
}: {
  values: number[];
  label: string;
  unit?: string;
  invert?: boolean;
  height?: number;
}) {
  const width = 320;
  const padX = 8;
  const padY = 14;
  if (values.length < 2) {
    return (
      <div>
        <p className="mb-1 text-sm font-medium">{label}</p>
        <p className="text-muted-foreground text-xs">Not enough sessions yet.</p>
      </div>
    );
  }
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const x = (i: number) =>
    padX + (i * (width - padX * 2)) / (values.length - 1);
  const y = (v: number) => {
    const norm = (v - min) / span;
    return padY + (invert ? norm : 1 - norm) * (height - padY * 2);
  };
  const line = values.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
  const first = values[0];
  const last = values[values.length - 1];

  return (
    <div>
      <div className="mb-1 flex items-baseline justify-between">
        <p className="text-sm font-medium">{label}</p>
        <p className="text-muted-foreground font-mono text-xs">
          {first}
          {unit} → {last}
          {unit}
        </p>
      </div>
      <svg
        width="100%"
        viewBox={`0 0 ${width} ${height}`}
        role="img"
        aria-label={`${label} over ${values.length} sessions`}
        className="text-indigo-500"
      >
        <polyline
          points={line}
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        {values.map((v, i) => (
          <circle key={i} cx={x(i)} cy={y(v)} r={2.5} fill="currentColor" />
        ))}
      </svg>
    </div>
  );
}
