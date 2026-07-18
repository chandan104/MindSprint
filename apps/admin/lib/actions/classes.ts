"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { classSchema } from "@/lib/validation";
import type { ActionResult } from "./schools";

function parseClass(formData: FormData) {
  return classSchema.safeParse({
    name: formData.get("name"),
    grade: formData.get("grade") || null,
    school_id: formData.get("school_id"),
  });
}

export async function createClass(formData: FormData): Promise<ActionResult> {
  const parsed = parseClass(formData);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { error } = await supabase.from("classes").insert(parsed.data);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/classes");
  return { ok: true };
}

export async function updateClass(id: string, formData: FormData): Promise<ActionResult> {
  const parsed = parseClass(formData);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { error } = await supabase.from("classes").update(parsed.data).eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/classes");
  return { ok: true };
}

export async function deleteClass(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("classes").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/classes");
  return { ok: true };
}
