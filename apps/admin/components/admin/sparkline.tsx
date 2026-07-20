// Dependency-free inline sparkline. Charts arrive with the benchmarks
// milestone; a trend line per module is all this page needs.
export function Sparkline({
  values,
  width = 140,
  height = 36,
  stroke = "currentColor",
  invert = false,
}: {
  values: number[];
  width?: number;
  height?: number;
  stroke?: string;
  /** For "lower is better" series (times): downward slope renders upward. */
  invert?: boolean;
}) {
  if (values.length < 2) {
    return (
      <span className="text-muted-foreground text-xs">not enough data</span>
    );
  }
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const pad = 3;
  const points = values
    .map((value, i) => {
      const x = pad + (i * (width - pad * 2)) / (values.length - 1);
      const raw = (value - min) / span;
      const y = pad + (invert ? raw : 1 - raw) * (height - pad * 2);
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");
  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      role="img"
      aria-label={`Trend over ${values.length} sessions`}
    >
      <polyline
        points={points}
        fill="none"
        stroke={stroke}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
