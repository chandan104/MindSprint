import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import packageJson from "../../../package.json";

// Minimal liveness + dependency check for uptime monitoring. Public by
// design (health checks run unauthenticated); reveals no data, only
// whether the app can reach Supabase.
export async function GET() {
  const startedAt = Date.now();
  try {
    const supabase = await createClient();
    const { error } = await supabase
      .from("feature_flags")
      .select("key", { head: true, count: "exact" })
      .limit(1);
    if (error) throw error;
    return NextResponse.json({
      status: "ok",
      database: "reachable",
      version: packageJson.version,
      commit: process.env.VERCEL_GIT_COMMIT_SHA ?? "unknown",
      latencyMs: Date.now() - startedAt,
    });
  } catch (err) {
    return NextResponse.json(
      {
        status: "degraded",
        database: "unreachable",
        error: err instanceof Error ? err.message : "unknown error",
      },
      { status: 503 }
    );
  }
}
