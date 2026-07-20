"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { ActionResult } from "./schools";

/** Permanent, audited erasure of a student and all derived data (DPDP path).
 * Authorization lives in the delete_student RPC — school_admin of the
 * student's school or super_admin; nothing here can widen that. */
export async function eraseStudent(
  studentId: string,
  formData: FormData
): Promise<ActionResult> {
  const reason = String(formData.get("reason") ?? "").trim();
  if (reason.length < 10) {
    return {
      ok: false,
      error: "Give a real reason (at least 10 characters) — it becomes the permanent audit record.",
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("delete_student", {
    p_student_id: studentId,
    p_reason: reason,
  });
  if (error) return { ok: false, error: error.message };

  revalidatePath("/students");
  return { ok: true };
}
