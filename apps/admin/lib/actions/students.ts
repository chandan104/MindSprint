"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { studentSchema } from "@/lib/validation";
import type { ActionResult } from "./schools";

async function schoolIdForClass(classId: string): Promise<string | null> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("classes")
    .select("school_id")
    .eq("id", classId)
    .maybeSingle();
  return data?.school_id ?? null;
}

function parseStudent(formData: FormData) {
  return studentSchema.safeParse({
    full_name: formData.get("full_name"),
    roll_number: formData.get("roll_number") || null,
    birth_year: formData.get("birth_year") || null,
    class_id: formData.get("class_id"),
  });
}

export async function createStudent(formData: FormData): Promise<ActionResult> {
  const parsed = parseStudent(formData);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const schoolId = await schoolIdForClass(parsed.data.class_id);
  if (!schoolId) return { ok: false, error: "Class not found" };

  const supabase = await createClient();
  const { error } = await supabase
    .from("students")
    .insert({ ...parsed.data, school_id: schoolId });
  if (error) return { ok: false, error: error.message };

  revalidatePath("/students");
  return { ok: true };
}

export async function updateStudent(id: string, formData: FormData): Promise<ActionResult> {
  const parsed = parseStudent(formData);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const schoolId = await schoolIdForClass(parsed.data.class_id);
  if (!schoolId) return { ok: false, error: "Class not found" };

  const supabase = await createClient();
  const { error } = await supabase
    .from("students")
    .update({ ...parsed.data, school_id: schoolId })
    .eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/students");
  return { ok: true };
}

export type BulkImportRow = {
  full_name: string;
  roll_number: string | null;
  birth_year: number | null;
};

export type BulkImportResult =
  | { ok: true; inserted: number }
  | { ok: false; error: string };

/** Inserts validated rows into one class in a single request. RLS enforces
 * school scope; the audit trigger records each insert. Re-validated
 * server-side (never trust the client's parse). */
export async function bulkImportStudents(
  classId: string,
  rows: BulkImportRow[]
): Promise<BulkImportResult> {
  if (rows.length === 0) return { ok: false, error: "Nothing to import." };
  if (rows.length > 500) {
    return { ok: false, error: "Import up to 500 students at a time." };
  }

  const clean: BulkImportRow[] = [];
  for (const row of rows) {
    const parsed = studentSchema
      .pick({ full_name: true, roll_number: true, birth_year: true })
      .safeParse(row);
    if (!parsed.success) {
      return {
        ok: false,
        error: `Invalid row (${row.full_name || "unnamed"}): ${parsed.error.issues[0].message}`,
      };
    }
    clean.push(parsed.data);
  }

  const schoolId = await schoolIdForClass(classId);
  if (!schoolId) return { ok: false, error: "Class not found" };

  const supabase = await createClient();
  const { error } = await supabase
    .from("students")
    .insert(clean.map((r) => ({ ...r, class_id: classId, school_id: schoolId })));
  if (error) return { ok: false, error: error.message };

  revalidatePath("/students");
  return { ok: true, inserted: clean.length };
}

export async function deactivateStudent(id: string): Promise<ActionResult> {
  // Soft-delete: assessment history must survive roster changes. Hard
  // deletion (the DPDP erasure path) is an audited RPC in a later phase.
  const supabase = await createClient();
  const { error } = await supabase
    .from("students")
    .update({ is_active: false })
    .eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/students");
  return { ok: true };
}
