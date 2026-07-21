import { createClient } from "@/lib/supabase/server";

export type InviteRow = {
  id: string;
  email: string;
  token: string;
  status: string;
  created_at: string;
  schools: { name: string } | null;
};

export async function listPendingInvites(): Promise<InviteRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("teacher_invites")
    .select("id, email, token, status, created_at, schools(name)")
    .eq("status", "pending")
    .order("created_at", { ascending: false });
  if (error) throw new Error(`Could not load invites: ${error.message}`);
  return data as unknown as InviteRow[];
}
