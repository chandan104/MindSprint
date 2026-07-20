"use client";

import { useRef, useState, useTransition } from "react";
import { Button } from "@/components/ui/button";

type ActionResult = { ok: true } | { ok: false; error: string };

export function AddNoteForm({
  action,
}: {
  action: (formData: FormData) => Promise<ActionResult>;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  return (
    <form
      ref={formRef}
      action={(formData) =>
        startTransition(async () => {
          setError(null);
          const result = await action(formData);
          if (!result.ok) setError(result.error);
          else formRef.current?.reset();
        })
      }
      className="space-y-2"
    >
      <textarea
        name="body"
        rows={3}
        maxLength={2000}
        placeholder="Add an observation about this student — e.g. 'Much more confident on sequences today; hesitated only on the last item.'"
        className="border-input bg-background w-full rounded-md border p-3 text-sm"
      />
      {error && <p className="text-destructive text-sm">{error}</p>}
      <Button size="sm" type="submit" disabled={pending}>
        {pending ? "Saving…" : "Add note"}
      </Button>
    </form>
  );
}
