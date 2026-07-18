"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { assignmentSchema } from "@/lib/validation";
import type { ActionResult } from "./schools";

export async function assignClass(formData: FormData): Promise<ActionResult> {
  const parsed = assignmentSchema.safeParse({
    teacher_id: formData.get("teacher_id"),
    class_id: formData.get("class_id"),
  });
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { error } = await supabase.from("teacher_classes").insert(parsed.data);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/teachers");
  return { ok: true };
}

export async function unassignClass(
  teacherId: string,
  classId: string
): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("teacher_classes")
    .delete()
    .eq("teacher_id", teacherId)
    .eq("class_id", classId);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/teachers");
  return { ok: true };
}
