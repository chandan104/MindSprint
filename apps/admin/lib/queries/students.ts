import { createClient } from "@/lib/supabase/server";

export type StudentRow = {
  id: string;
  full_name: string;
  roll_number: string | null;
  birth_year: number | null;
  is_active: boolean;
  class_id: string;
  classes: { name: string } | null;
};

export async function listStudents(): Promise<StudentRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("students")
    .select(
      "id, full_name, roll_number, birth_year, is_active, class_id, classes(name)"
    )
    .order("full_name");
  if (error) throw new Error(`Could not load students: ${error.message}`);
  return data;
}
