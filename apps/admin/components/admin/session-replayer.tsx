"use client";

// Session Replay: reconstructs what the child saw and did, purely from the
// event log — the platform's promise made visible. Adapted from the AI
// Studio prototype's strongest component, rebuilt on our event taxonomy and
// a pure state-derivation fold (lib/replay/replay-state).

import { useEffect, useMemo, useRef, useState } from "react";
import { Pause, Play, RotateCcw, Timer } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  deriveReplayState,
  type ReplayEvent,
} from "@/lib/replay/replay-state";

const SPEEDS = [1, 2, 4] as const;

export function SessionReplayer({
  events,
  studentName,
}: {
  events: ReplayEvent[];
  studentName: string;
}) {
  const duration = useMemo(
    () => (events.length ? Math.max(...events.map((e) => e.t_ms)) : 0),
    [events]
  );
  const [clock, setClock] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState<(typeof SPEEDS)[number]>(1);
  const frame = useRef<number | null>(null);
  const lastTick = useRef<number>(0);

  useEffect(() => {
    if (!playing) return;
    lastTick.current = performance.now();
    const tick = (now: number) => {
      const elapsed = (now - lastTick.current) * speed;
      lastTick.current = now;
      setClock((current) => {
        const next = current + elapsed;
        if (next >= duration) {
          setPlaying(false);
          return duration;
        }
        return next;
      });
      frame.current = requestAnimationFrame(tick);
    };
    frame.current = requestAnimationFrame(tick);
    return () => {
      if (frame.current != null) cancelAnimationFrame(frame.current);
    };
  }, [playing, speed, duration]);

  const state = useMemo(
    () => deriveReplayState(events, clock),
    [events, clock]
  );

  const restart = () => {
    setClock(0);
    setPlaying(true);
  };

  return (
    <div className="space-y-3 rounded-xl border p-4">
      <div className="flex flex-wrap items-center gap-2">
        <Button
          size="sm"
          onClick={() =>
            clock >= duration ? restart() : setPlaying((p) => !p)
          }
        >
          {playing ? (
            <Pause className="size-4" />
          ) : (
            <Play className="size-4" />
          )}
          {playing ? "Pause" : clock >= duration ? "Replay" : "Play"}
        </Button>
        <Button size="sm" variant="outline" onClick={() => setClock(0)}>
          <RotateCcw className="size-4" />
        </Button>
        {SPEEDS.map((s) => (
          <Button
            key={s}
            size="sm"
            variant={speed === s ? "default" : "outline"}
            onClick={() => setSpeed(s)}
          >
            {s}×
          </Button>
        ))}
        <span className="text-muted-foreground ml-auto font-mono text-xs">
          <Timer className="mr-1 inline size-3.5" />
          {(clock / 1000).toFixed(1)}s / {(duration / 1000).toFixed(1)}s
        </span>
      </div>

      <input
        type="range"
        min={0}
        max={duration}
        value={clock}
        onChange={(e) => {
          setPlaying(false);
          setClock(Number(e.target.value));
        }}
        className="accent-primary w-full"
        aria-label="Replay timeline"
      />

      {/* Reconstructed screen */}
      <div className="bg-muted/30 relative min-h-56 rounded-lg border p-4">
        <div className="mb-3 flex items-center justify-between">
          <span className="text-sm font-medium">{studentName}&apos;s screen</span>
          <div className="flex gap-2">
            {state.roundNumber > 0 && state.sequence.length > 0 && (
              <Badge variant="outline">Round {state.roundNumber}</Badge>
            )}
            {state.isHesitating && (
              <Badge variant="destructive">Hesitating…</Badge>
            )}
            <Badge variant="secondary" className="capitalize">
              {state.phase}
            </Badge>
          </div>
        </div>

        {state.phase === "idle" && (
          <p className="text-muted-foreground text-sm">
            Press play to watch the session unfold exactly as it was recorded.
          </p>
        )}

        {state.sequence.length > 0 && state.phase === "exposure" && (
          <div className="flex flex-wrap gap-2">
            {state.sequence.slice(0, state.revealedCount).map((item, i) => (
              <div
                key={`${item.itemId}-${i}`}
                className="bg-background rounded-lg border-2 border-indigo-400 px-4 py-3 text-sm font-semibold"
              >
                {item.label}
              </div>
            ))}
            {state.sequence.slice(state.revealedCount).map((item, i) => (
              <div
                key={`hidden-${item.itemId}-${i}`}
                className="text-muted-foreground rounded-lg border border-dashed px-4 py-3 text-sm"
              >
                ·
              </div>
            ))}
          </div>
        )}

        {state.sequence.length > 0 &&
          (state.phase === "recall" ||
            state.phase === "complete" ||
            state.phase === "aborted") && (
            <div className="space-y-3">
              <div className="flex flex-wrap gap-2">
                {state.sequence.map((item, i) => {
                  const matched = state.matchedIds.includes(item.itemId);
                  return (
                    <div
                      key={`slot-${i}`}
                      className={`rounded-lg border-2 px-4 py-3 text-sm font-semibold ${
                        matched
                          ? "border-emerald-500 bg-emerald-500/10"
                          : "text-muted-foreground border-dashed"
                      }`}
                    >
                      {matched ? item.label : "?"}
                    </div>
                  );
                })}
              </div>
              <TapTrail taps={state.taps} />
            </div>
          )}

        {state.question && state.phase === "question" && (
          <div className="space-y-3">
            <p className="text-2xl font-bold">{state.question.text} = ?</p>
            <div className="flex flex-wrap gap-2">
              {state.question.options.map((option) => {
                const tapped = state.taps.find(
                  (t) => t.itemId === option.itemId
                );
                return (
                  <div
                    key={option.itemId}
                    className={`rounded-lg border-2 px-5 py-3 font-semibold ${
                      tapped
                        ? tapped.isCorrect
                          ? "border-emerald-500 bg-emerald-500/10"
                          : "border-rose-500 bg-rose-500/10"
                        : "border-border"
                    }`}
                  >
                    {option.label}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {state.phase === "complete" && (
          <p className="mt-3 text-sm font-medium text-emerald-600">
            Session completed.
          </p>
        )}
        {state.phase === "aborted" && (
          <p className="text-destructive mt-3 text-sm font-medium">
            Session ended early
            {state.abortReason ? ` (${state.abortReason.replace("_", " ")})` : ""}.
          </p>
        )}
      </div>
    </div>
  );
}

function TapTrail({
  taps,
}: {
  taps: { label?: string; isCorrect?: boolean }[];
}) {
  if (taps.length === 0) return null;
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      <span className="text-muted-foreground text-xs">Taps:</span>
      {taps.map((tap, i) => (
        <span
          key={i}
          className={`rounded px-2 py-0.5 text-xs font-medium ${
            tap.isCorrect
              ? "bg-emerald-500/15 text-emerald-600"
              : "bg-rose-500/15 text-rose-600"
          }`}
        >
          {tap.label ?? "?"}
        </span>
      ))}
    </div>
  );
}
