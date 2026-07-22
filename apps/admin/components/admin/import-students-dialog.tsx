"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
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
import {
  parseStudentsCsv,
  type ParseResult,
} from "@/lib/import/parse-students-csv";
import {
  bulkImportStudents,
  type BulkImportResult,
} from "@/lib/actions/students";

type ClassOption = { value: string; label: string };

export function ImportStudentsDialog({
  classes,
}: {
  classes: ClassOption[];
}) {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [open, setOpen] = useState(false);
  const [classId, setClassId] = useState("");
  const [parsed, setParsed] = useState<ParseResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function reset() {
    setParsed(null);
    setError(null);
    setDone(null);
    if (fileRef.current) fileRef.current.value = "";
  }

  async function onFile(file: File) {
    setError(null);
    setDone(null);
    const text = await file.text();
    setParsed(parseStudentsCsv(text));
  }

  function commit() {
    if (!parsed || !classId) return;
    const rows = parsed.rows
      .filter((r) => r.error === null)
      .map((r) => ({
        full_name: r.full_name,
        roll_number: r.roll_number,
        birth_year: r.birth_year,
      }));
    startTransition(async () => {
      const result: BulkImportResult = await bulkImportStudents(classId, rows);
      if (result.ok) {
        setDone(`Imported ${result.inserted} student(s).`);
        setParsed(null);
        if (fileRef.current) fileRef.current.value = "";
        router.refresh();
      } else {
        setError(result.error);
      }
    });
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) reset();
      }}
    >
      <DialogTrigger
        render={
          <Button variant="outline">Import CSV</Button>
        }
      />
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Import students from CSV</DialogTitle>
          <DialogDescription>
            Columns: <code>full_name</code> (required),{" "}
            <code>roll_number</code>, <code>birth_year</code>. First row is the
            header. Up to 500 rows.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-sm font-medium">Class</label>
            <select
              value={classId}
              onChange={(e) => setClassId(e.target.value)}
              className="border-input bg-background w-full rounded-md border p-2 text-sm"
            >
              <option value="">-- Choose a class --</option>
              {classes.map((c) => (
                <option key={c.value} value={c.value}>
                  {c.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">CSV file</label>
            <input
              ref={fileRef}
              type="file"
              accept=".csv,text/csv"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onFile(f);
              }}
              className="text-sm"
            />
          </div>

          {parsed && (
            <div className="max-h-64 overflow-y-auto rounded-md border">
              <table className="w-full text-left text-xs">
                <thead className="bg-muted sticky top-0">
                  <tr>
                    <th className="p-2">Name</th>
                    <th className="p-2">Roll</th>
                    <th className="p-2">Year</th>
                    <th className="p-2">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {parsed.rows.map((r) => (
                    <tr key={r.line} className="border-t">
                      <td className="p-2">{r.full_name || "—"}</td>
                      <td className="p-2">{r.roll_number ?? "—"}</td>
                      <td className="p-2">{r.birth_year ?? "—"}</td>
                      <td className="p-2">
                        {r.error ? (
                          <span className="text-destructive">{r.error}</span>
                        ) : (
                          <span className="text-emerald-600">ok</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {parsed && (
            <p className="text-muted-foreground text-sm">
              {parsed.validCount} valid · {parsed.errorCount} skipped. Only
              valid rows are imported.
            </p>
          )}
          {error && <p className="text-destructive text-sm">{error}</p>}
          {done && <p className="text-sm text-emerald-600">{done}</p>}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Close
          </Button>
          <Button
            onClick={commit}
            disabled={
              pending ||
              !classId ||
              !parsed ||
              parsed.validCount === 0
            }
          >
            {pending
              ? "Importing…"
              : parsed
                ? `Import ${parsed.validCount}`
                : "Import"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
