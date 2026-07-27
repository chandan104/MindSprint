import { cache } from "react";
import { createClient } from "@/lib/supabase/server";

export type StudentHeader = {
  id: string;
  full_name: string;
  roll_number: string | null;
  is_active: boolean;
  classes: { name: string } | null;
};

export type ReportSession = {
  id: string;
  module_key: string;
  status: string;
  started_at: string;
  was_interrupted: boolean;
  session_metrics: {
    metrics_version: number;
    total_time_ms: number | null;
    accuracy: number | null;
    extra: Record<string, unknown>;
  }[];
};

export type StudentNote = {
  id: string;
  body: string;
  created_at: string;
  teacher_id: string;
  profiles: { full_name: string } | null;
};

export async function getStudentReport(studentId: string): Promise<{
  student: StudentHeader;
  sessions: ReportSession[];
  notes: StudentNote[];
}> {
  const supabase = await createClient();
  const [studentRes, sessionsRes, notesRes] = await Promise.all([
    supabase
      .from("students")
      .select("id, full_name, roll_number, is_active, classes(name)")
      .eq("id", studentId)
      .single(),
    supabase
      .from("sessions")
      .select(
        "id, module_key, status, started_at, was_interrupted, " +
          "session_metrics(metrics_version, total_time_ms, accuracy, extra)"
      )
      .eq("student_id", studentId)
      .order("started_at", { ascending: true }),
    // NOTE: teacher_notes.teacher_id references auth.users, not profiles, so an
    // embedded `profiles(full_name)` has no FK for PostgREST to follow and errors
    // ("Could not find a relationship … in the schema cache"). Author names are
    // resolved in a separate, relationship-independent query below.
    supabase
      .from("teacher_notes")
      .select("id, body, created_at, teacher_id")
      .eq("student_id", studentId)
      .order("created_at", { ascending: false }),
  ]);
  if (studentRes.error) {
    throw new Error(`Could not load student: ${studentRes.error.message}`);
  }
  if (sessionsRes.error) {
    throw new Error(`Could not load sessions: ${sessionsRes.error.message}`);
  }
  if (notesRes.error) {
    throw new Error(`Could not load notes: ${notesRes.error.message}`);
  }

  const rawNotes = (notesRes.data ?? []) as {
    id: string;
    body: string;
    created_at: string;
    teacher_id: string;
  }[];

  // Resolve author names (RLS-scoped: viewers who may not see other teachers'
  // profiles simply get the "Teacher" fallback — same as the old embed).
  const teacherIds = [...new Set(rawNotes.map((n) => n.teacher_id))];
  const nameById = new Map<string, string>();
  if (teacherIds.length > 0) {
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, full_name")
      .in("id", teacherIds);
    for (const p of profiles ?? []) {
      nameById.set(p.id as string, p.full_name as string);
    }
  }

  const notes: StudentNote[] = rawNotes.map((n) => ({
    ...n,
    profiles: nameById.has(n.teacher_id)
      ? { full_name: nameById.get(n.teacher_id)! }
      : null,
  }));

  return {
    student: studentRes.data as unknown as StudentHeader,
    sessions: sessionsRes.data as unknown as ReportSession[],
    notes,
  };
}

/** The authenticated user for this request. Wrapped in React `cache()` so the
 * layout and every page in one render share a single `auth.getUser()` round
 * trip instead of re-validating the JWT several times. */
export const getCurrentUser = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});

/** The signed-in user's platform role. UI-affordance only — RLS and the
 * definer RPCs enforce authorization server-side regardless. Also `cache()`d,
 * so the role query runs at most once per request even though the layout and
 * the page both ask for it. */
export const currentUserRole = cache(
  async (): Promise<"super_admin" | "school_admin" | "teacher" | null> => {
    const user = await getCurrentUser();
    if (!user) return null;
    const supabase = await createClient();
    const { data } = await supabase
      .from("user_roles")
      .select("role")
      .eq("user_id", user.id)
      .maybeSingle();
    return (data?.role as "super_admin" | "school_admin" | "teacher") ?? null;
  }
);

export async function currentUserIsTeacher(): Promise<boolean> {
  return (await currentUserRole()) === "teacher";
}
