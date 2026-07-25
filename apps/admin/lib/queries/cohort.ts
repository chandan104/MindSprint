import { createClient } from "@/lib/supabase/server";
import {
  computeCognitiveProfile,
  type ScoredSession,
} from "@/lib/insights/cognitive-score";

export type CohortComparison = {
  studentOverall: number | null;
  classAverage: number | null;
  schoolAverage: number | null;
  classSize: number;
  schoolSize: number;
};

type Row = {
  student_id: string;
  module_key: string;
  started_at: string;
  was_interrupted: boolean;
  status: string;
  students: { class_id: string } | null;
  session_metrics: {
    accuracy: number | null;
    extra: Record<string, unknown>;
  }[];
};

function toScored(r: Row): ScoredSession {
  const extra = (r.session_metrics[0]?.extra ?? {}) as Record<string, unknown>;
  const num = (k: string) =>
    typeof extra[k] === "number" ? (extra[k] as number) : null;
  return {
    moduleKey: r.module_key,
    startedAt: r.started_at,
    accuracy: r.session_metrics[0]?.accuracy ?? null,
    medianDecisionMs: num("median_decision_ms"),
    reactionMs: num("reaction_time_ms"),
    hesitationCount: num("hesitation_count"),
  };
}

/** Student's overall cognitive index vs their class and school averages.
 * Every read runs as the signed-in user, so RLS scopes the cohort to what
 * they may see — no service role, no cross-tenant leakage. */
export async function getCohortComparison(
  studentId: string
): Promise<CohortComparison> {
  const supabase = await createClient();

  const { data: student } = await supabase
    .from("students")
    .select("class_id, school_id")
    .eq("id", studentId)
    .single();
  if (!student) {
    return {
      studentOverall: null,
      classAverage: null,
      schoolAverage: null,
      classSize: 0,
      schoolSize: 0,
    };
  }

  const { data, error } = await supabase
    .from("sessions")
    .select(
      "student_id, module_key, started_at, was_interrupted, status, " +
        "students!inner(class_id), session_metrics(accuracy, extra)"
    )
    .eq("school_id", student.school_id)
    .eq("status", "validated")
    .eq("was_interrupted", false)
    .limit(5000);
  if (error) throw new Error(`Could not load cohort: ${error.message}`);

  const rows = (data ?? []) as unknown as Row[];

  // Group sessions by student, compute each student's overall index.
  const byStudent = new Map<string, { classId: string; sessions: ScoredSession[] }>();
  for (const r of rows) {
    const entry = byStudent.get(r.student_id) ?? {
      classId: r.students?.class_id ?? "",
      sessions: [],
    };
    entry.sessions.push(toScored(r));
    byStudent.set(r.student_id, entry);
  }

  const overalls: { studentId: string; classId: string; overall: number }[] = [];
  for (const [sid, entry] of byStudent) {
    const overall = computeCognitiveProfile(entry.sessions).overall;
    if (overall != null) {
      overalls.push({ studentId: sid, classId: entry.classId, overall });
    }
  }

  const mean = (xs: number[]) =>
    xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null;

  const classOveralls = overalls
    .filter((o) => o.classId === student.class_id)
    .map((o) => o.overall);
  const schoolOveralls = overalls.map((o) => o.overall);
  const self = overalls.find((o) => o.studentId === studentId)?.overall ?? null;

  return {
    studentOverall: self,
    classAverage: mean(classOveralls),
    schoolAverage: mean(schoolOveralls),
    classSize: classOveralls.length,
    schoolSize: schoolOveralls.length,
  };
}
