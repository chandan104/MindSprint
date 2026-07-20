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
    supabase
      .from("teacher_notes")
      .select("id, body, created_at, teacher_id, profiles(full_name)")
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
  return {
    student: studentRes.data as unknown as StudentHeader,
    sessions: sessionsRes.data as unknown as ReportSession[],
    notes: notesRes.data as unknown as StudentNote[],
  };
}

/** The signed-in user's platform role. UI-affordance only — RLS and the
 * definer RPCs enforce authorization server-side regardless. */
export async function currentUserRole(): Promise<
  "super_admin" | "school_admin" | "teacher" | null
> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", user.id)
    .maybeSingle();
  return (data?.role as "super_admin" | "school_admin" | "teacher") ?? null;
}

export async function currentUserIsTeacher(): Promise<boolean> {
  return (await currentUserRole()) === "teacher";
}
