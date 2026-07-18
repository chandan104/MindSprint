import { createClient } from "@/lib/supabase/server";

export type SchoolRow = {
  id: string;
  name: string;
  created_at: string;
  classes: { count: number }[];
};

export async function listSchools(): Promise<SchoolRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("schools")
    .select("id, name, created_at, classes(count)")
    .order("name");
  if (error) throw new Error(`Could not load schools: ${error.message}`);
  return data;
}
