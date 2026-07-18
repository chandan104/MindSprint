import { z } from "zod";

// Shared between server actions and tests. Student fields are the deliberate
// PII minimum (spec §10): name, roll, birth year — nothing else about a child.

export const schoolSchema = z.object({
  name: z.string().trim().min(2, "School name needs at least 2 characters").max(120),
});

export const classSchema = z.object({
  name: z.string().trim().min(1, "Class name is required").max(80),
  grade: z.coerce.number().int().min(1).max(12).nullable(),
  school_id: z.string().uuid("Choose a school"),
});

export const studentSchema = z.object({
  full_name: z.string().trim().min(2, "Student name needs at least 2 characters").max(120),
  roll_number: z.string().trim().max(20).nullable(),
  birth_year: z.coerce
    .number()
    .int()
    .min(1990, "Birth year looks wrong")
    .max(new Date().getFullYear(), "Birth year cannot be in the future")
    .nullable(),
  class_id: z.string().uuid("Choose a class"),
});

export const assignmentSchema = z.object({
  teacher_id: z.string().uuid(),
  class_id: z.string().uuid("Choose a class"),
});
