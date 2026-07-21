"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";

// App Router error boundary: catches render/render-path errors anywhere
// under this segment so a bug shows a recoverable screen, not a blank page
// or a raw stack trace in front of a teacher.
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // eslint-disable-next-line no-console -- production error surface;
    // replace with a real monitoring sink when one is adopted (backlog).
    console.error("[MindSprint admin] unhandled error", error);
  }, [error]);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
      <h1 className="text-xl font-semibold">Something went wrong</h1>
      <p className="text-muted-foreground max-w-sm text-sm">
        This screen hit an unexpected error. Your data is safe — try again,
        or go back and retry the action.
      </p>
      {error.digest && (
        <p className="text-muted-foreground font-mono text-xs">
          Reference: {error.digest}
        </p>
      )}
      <Button onClick={reset}>Try again</Button>
    </div>
  );
}
