import { describe, expect, it } from "vitest";
import {
  assignmentSchema,
  classSchema,
  schoolSchema,
  studentSchema,
} from "@/lib/validation";

const uuid = "00000000-0000-4000-8000-000000000001";

describe("schoolSchema", () => {
  it("accepts a normal name and trims it", () => {
    const parsed = schoolSchema.parse({ name: "  Demo School  " });
    expect(parsed.name).toBe("Demo School");
  });

  it("rejects one-character names", () => {
    expect(schoolSchema.safeParse({ name: "A" }).success).toBe(false);
  });
});

describe("classSchema", () => {
  it("coerces grade from form-data strings", () => {
    const parsed = classSchema.parse({ name: "4A", grade: "4", school_id: uuid });
    expect(parsed.grade).toBe(4);
  });

  it("rejects grades outside 1-12", () => {
    expect(
      classSchema.safeParse({ name: "4A", grade: "13", school_id: uuid }).success
    ).toBe(false);
  });

  it("rejects a missing school", () => {
    expect(
      classSchema.safeParse({ name: "4A", grade: null, school_id: "not-a-uuid" })
        .success
    ).toBe(false);
  });
});

describe("studentSchema", () => {
  const valid = {
    full_name: "Aarav Sharma",
    roll_number: "4A-01",
    birth_year: "2016",
    class_id: uuid,
  };

  it("accepts a valid student and coerces birth year", () => {
    const parsed = studentSchema.parse(valid);
    expect(parsed.birth_year).toBe(2016);
  });

  it("allows null roll number and birth year (PII minimum is optional)", () => {
    const parsed = studentSchema.parse({
      ...valid,
      roll_number: null,
      birth_year: null,
    });
    expect(parsed.roll_number).toBeNull();
    expect(parsed.birth_year).toBeNull();
  });

  it("rejects birth years before 1990 and in the future", () => {
    expect(studentSchema.safeParse({ ...valid, birth_year: "1800" }).success).toBe(false);
    expect(
      studentSchema.safeParse({
        ...valid,
        birth_year: String(new Date().getFullYear() + 1),
      }).success
    ).toBe(false);
  });
});

describe("assignmentSchema", () => {
  it("requires two uuids", () => {
    expect(
      assignmentSchema.safeParse({ teacher_id: uuid, class_id: uuid }).success
    ).toBe(true);
    expect(
      assignmentSchema.safeParse({ teacher_id: uuid, class_id: "x" }).success
    ).toBe(false);
  });
});
