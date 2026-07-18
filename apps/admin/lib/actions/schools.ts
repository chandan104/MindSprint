"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { schoolSchema } from "@/lib/validation";

export type ActionResult = { ok: true } | { ok: false; error: string };

export async function createSchool(formData: FormData): Promise<ActionResult> {
  const parsed = schoolSchema.safeParse({ name: formData.get("name") });
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { error } = await supabase.from("schools").insert(parsed.data);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/schools");
  return { ok: true };
}

export async function updateSchool(id: string, formData: FormData): Promise<ActionResult> {
  const parsed = schoolSchema.safeParse({ name: formData.get("name") });
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { error } = await supabase.from("schools").update(parsed.data).eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/schools");
  return { ok: true };
}

export async function deleteSchool(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("schools").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/schools");
  return { ok: true };
}
