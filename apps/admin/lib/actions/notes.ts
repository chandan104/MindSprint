"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { ActionResult } from "./schools";

export async function addTeacherNote(
  studentId: string,
  formData: FormData
): Promise<ActionResult> {
  const body = String(formData.get("body") ?? "").trim();
  if (body.length === 0) return { ok: false, error: "Write a note first." };
  if (body.length > 2000) {
    return { ok: false, error: "Notes are limited to 2000 characters." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: "Not signed in." };

  // RLS is the real gate (teacher role + own teacher_id); this insert simply
  // fails for non-teachers.
  const { error } = await supabase.from("teacher_notes").insert({
    student_id: studentId,
    teacher_id: user.id,
    body,
  });
  if (error) return { ok: false, error: error.message };

  revalidatePath(`/students/${studentId}`);
  return { ok: true };
}
