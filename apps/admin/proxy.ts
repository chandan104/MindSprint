import { type NextRequest } from "next/server";
// Relative import, not the "@/" alias: Vercel's Edge Function bundler has
// failed to resolve tsconfig path aliases from middleware.ts in monorepo
// deployments (Root Directory != repo root). A relative import sidesteps
// alias resolution entirely.
import { updateSession } from "./lib/supabase/middleware";

export async function proxy(request: NextRequest) {
  return await updateSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
