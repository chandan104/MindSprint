"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { ActionResult } from "./schools";

export async function inviteTeacher(formData: FormData): Promise<ActionResult> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const schoolId = String(formData.get("school_id") ?? "");
  if (!email.includes("@")) return { ok: false, error: "Enter a valid email." };
  if (!schoolId) return { ok: false, error: "Choose a school." };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: "Not signed in." };

  const { error } = await supabase.from("teacher_invites").insert({
    email,
    school_id: schoolId,
    invited_by: user.id,
  });
  if (error) {
    const message = error.message.includes("teacher_invites_pending_email_idx")
      ? "This email already has a pending invite for this school."
      : error.message;
    return { ok: false, error: message };
  }

  revalidatePath("/teachers");
  return { ok: true };
}

export async function revokeInvite(inviteId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("teacher_invites")
    .update({ status: "revoked" })
    .eq("id", inviteId);
  if (error) return { ok: false, error: error.message };
  revalidatePath("/teachers");
  return { ok: true };
}
