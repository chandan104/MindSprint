"use client";

import { Button } from "@/components/ui/button";

export function PrintButton({ label = "Print / Save as PDF" }: { label?: string }) {
  return (
    <Button className="no-print" onClick={() => window.print()}>
      {label}
    </Button>
  );
}
