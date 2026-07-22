import { describe, expect, it } from "vitest";
import { parseStudentsCsv } from "@/lib/import/parse-students-csv";

describe("parseStudentsCsv", () => {
  it("parses valid rows with all columns", () => {
    const csv = [
      "full_name,roll_number,birth_year",
      "Aarav Sharma,4A-01,2016",
      "Diya Patel,4A-02,2016",
    ].join("\n");
    const result = parseStudentsCsv(csv);
    expect(result.validCount).toBe(2);
    expect(result.errorCount).toBe(0);
    expect(result.rows[0]).toMatchObject({
      full_name: "Aarav Sharma",
      roll_number: "4A-01",
      birth_year: 2016,
      error: null,
    });
  });

  it("handles column order from the header, not position", () => {
    const csv = ["birth_year,full_name,roll_number", "2015,Kabir Das,4A-03"].join(
      "\n"
    );
    const row = parseStudentsCsv(csv).rows[0];
    expect(row.full_name).toBe("Kabir Das");
    expect(row.birth_year).toBe(2015);
    expect(row.roll_number).toBe("4A-03");
  });

  it("treats missing optional columns as null", () => {
    const csv = ["full_name", "Meera Nair"].join("\n");
    const row = parseStudentsCsv(csv).rows[0];
    expect(row.error).toBeNull();
    expect(row.roll_number).toBeNull();
    expect(row.birth_year).toBeNull();
  });

  it("respects quoted fields with commas and escaped quotes", () => {
    const csv = [
      "full_name,roll_number",
      '"Rao, Jr.","R-1"',
      '"She said ""hi""",R-2',
    ].join("\n");
    const rows = parseStudentsCsv(csv).rows;
    expect(rows[0].full_name).toBe("Rao, Jr.");
    expect(rows[1].full_name).toBe('She said "hi"');
  });

  it("flags rows with a too-short name", () => {
    const csv = ["full_name", "A"].join("\n");
    const row = parseStudentsCsv(csv).rows[0];
    expect(row.error).toContain("at least 2 characters");
  });

  it("flags an out-of-range birth year but keeps the row visible", () => {
    const csv = ["full_name,birth_year", "Zara Ahmed,1850"].join("\n");
    const result = parseStudentsCsv(csv);
    expect(result.errorCount).toBe(1);
    expect(result.rows[0].error).toContain("looks wrong");
    expect(result.rows[0].full_name).toBe("Zara Ahmed");
  });

  it("errors clearly when the name column is missing", () => {
    const csv = ["name,roll_number", "Someone,R-1"].join("\n");
    const result = parseStudentsCsv(csv);
    expect(result.errorCount).toBe(1);
    expect(result.rows[0].error).toContain("full_name");
  });

  it("ignores blank lines and handles CRLF", () => {
    const csv = "full_name\r\nAarav\r\n\r\nDiya\r\n";
    const result = parseStudentsCsv(csv);
    expect(result.validCount).toBe(2);
  });

  it("skips invalid rows in the valid/error counts", () => {
    const csv = [
      "full_name,birth_year",
      "Valid One,2015",
      "X,2015",
      "Valid Two,3000",
    ].join("\n");
    const result = parseStudentsCsv(csv);
    expect(result.validCount).toBe(1);
    expect(result.errorCount).toBe(2);
  });
});
