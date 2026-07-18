import { createClient } from "@/lib/supabase/server";

export type ClassRow = {
  id: string;
  name: string;
  grade: number | null;
  school_id: string;
  schools: { name: string } | null;
  students: { count: number }[];
};

export async function listClasses(): Promise<ClassRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("classes")
    .select("id, name, grade, school_id, schools(name), students(count)")
    .order("grade")
    .order("name");
  if (error) throw new Error(`Could not load classes: ${error.message}`);
  return data;
}
