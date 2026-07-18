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
