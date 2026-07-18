import { createClient } from "@/lib/supabase/server";

export type TeacherRow = {
  user_id: string;
  role: string;
  school_id: string | null;
  full_name: string | null;
  assignments: { class_id: string; class_name: string }[];
};

// Teachers are auth users with a `teacher` role. Creating new teacher
// accounts is a manual dashboard step in Phase 1 (see tools/seed-users.md);
// this page lists and assigns them. user_roles and profiles both key on
// auth.users with no FK between them, so PostgREST cannot embed the join —
// merge in JS instead.
export async function listTeachers(): Promise<TeacherRow[]> {
  const supabase = await createClient();

  const { data: roles, error } = await supabase
    .from("user_roles")
    .select("user_id, role, school_id")
    .eq("role", "teacher");
  if (error) throw new Error(`Could not load teachers: ${error.message}`);

  const [{ data: profiles, error: profileError }, { data: assignments, error: assignmentError }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id, full_name")
        .in("id", roles.map((r) => r.user_id)),
      supabase.from("teacher_classes").select("teacher_id, class_id, classes(name)"),
    ]);
  if (profileError)
    throw new Error(`Could not load teacher profiles: ${profileError.message}`);
  if (assignmentError)
    throw new Error(`Could not load assignments: ${assignmentError.message}`);

  const nameById = new Map(profiles.map((p) => [p.id, p.full_name]));

  return roles.map((r) => ({
    ...r,
    full_name: nameById.get(r.user_id) ?? null,
    assignments: assignments
      .filter((a) => a.teacher_id === r.user_id)
      .map((a) => ({
        class_id: a.class_id,
        class_name: a.classes?.name ?? "?",
      })),
  }));
}
