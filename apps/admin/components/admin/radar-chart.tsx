// Dependency-free SVG radar for the 4-domain cognitive profile. Values are
// 0..100; null domains render at the centre (no data).
export type RadarAxis = { label: string; value: number | null };

export function RadarChart({
  axes,
  size = 240,
}: {
  axes: RadarAxis[];
  size?: number;
}) {
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 34;
  const n = axes.length;

  const point = (i: number, radius: number) => {
    const angle = (Math.PI * 2 * i) / n - Math.PI / 2;
    return [cx + radius * Math.cos(angle), cy + radius * Math.sin(angle)];
  };

  const rings = [0.25, 0.5, 0.75, 1];
  const valuePoints = axes
    .map((a, i) => point(i, r * ((a.value ?? 0) / 100)))
    .map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`)
    .join(" ");

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img"
      aria-label="Cognitive profile radar">
      {rings.map((ring) => (
        <polygon
          key={ring}
          points={axes
            .map((_, i) => point(i, r * ring))
            .map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`)
            .join(" ")}
          className="fill-none stroke-muted"
          strokeWidth={1}
        />
      ))}
      {axes.map((_, i) => {
        const [x, y] = point(i, r);
        return (
          <line
            key={i}
            x1={cx}
            y1={cy}
            x2={x}
            y2={y}
            className="stroke-muted"
            strokeWidth={1}
          />
        );
      })}
      <polygon
        points={valuePoints}
        className="fill-indigo-500/25 stroke-indigo-500"
        strokeWidth={2}
      />
      {axes.map((a, i) => {
        const [x, y] = point(i, r + 16);
        return (
          <text
            key={a.label}
            x={x}
            y={y}
            textAnchor="middle"
            dominantBaseline="middle"
            className="fill-current text-[10px]"
          >
            {a.label}
          </text>
        );
      })}
    </svg>
  );
}
