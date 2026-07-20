"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

type ActionResult = { ok: true } | { ok: false; error: string };

/** The erasure ceremony: typed name confirmation + mandatory reason.
 * Deliberately heavier than any other admin action — this one is permanent. */
export function EraseStudentDialog({
  studentName,
  action,
}: {
  studentName: string;
  action: (formData: FormData) => Promise<ActionResult>;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [typed, setTyped] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const nameMatches = typed.trim() === studentName;

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button variant="destructive" size="sm">
            Erase student data
          </Button>
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Permanently erase {studentName}?</DialogTitle>
          <DialogDescription>
            This deletes the student and every assessment session, event,
            metric, and teacher note — permanently. An audit record of who
            erased, when, and why is kept. This cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-sm font-medium">
              Type the student&apos;s full name to confirm
            </label>
            <input
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              placeholder={studentName}
              className="border-input bg-background w-full rounded-md border p-2 text-sm"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium">
              Reason (kept in the audit ledger)
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={2}
              placeholder="e.g. Erasure requested by parent on 2026-07-20"
              className="border-input bg-background w-full rounded-md border p-2 text-sm"
            />
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Cancel
          </Button>
          <Button
            variant="destructive"
            disabled={!nameMatches || reason.trim().length < 10 || pending}
            onClick={() =>
              startTransition(async () => {
                setError(null);
                const formData = new FormData();
                formData.set("reason", reason);
                const result = await action(formData);
                if (!result.ok) {
                  setError(result.error);
                } else {
                  setOpen(false);
                  router.push("/students");
                }
              })
            }
          >
            {pending ? "Erasing…" : "Erase permanently"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
