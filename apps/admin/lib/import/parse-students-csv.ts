// Dependency-free CSV parsing for bulk student import. Handles quoted fields,
// escaped quotes, and CRLF. Pure function — the same rows in always produce
// the same parsed+validated result, so it is fully unit-testable and the
// preview the admin sees is exactly what will be committed.

export type ParsedStudentRow = {
  line: number;
  full_name: string;
  roll_number: string | null;
  birth_year: number | null;
  error: string | null;
};

export type ParseResult = {
  rows: ParsedStudentRow[];
  validCount: number;
  errorCount: number;
};

/** Splits one CSV line into fields, respecting quotes. */
function splitLine(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      fields.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  fields.push(current);
  return fields.map((f) => f.trim());
}

/**
 * Expected columns (header row, case-insensitive): full_name (required),
 * roll_number (optional), birth_year (optional). Extra columns are ignored;
 * column order is taken from the header, not assumed.
 */
export function parseStudentsCsv(text: string): ParseResult {
  const currentYear = new Date().getFullYear();
  const lines = text
    .split(/\r?\n/)
    .map((l) => l)
    .filter((l, i) => l.trim().length > 0 || i === 0);

  if (lines.length === 0) {
    return { rows: [], validCount: 0, errorCount: 0 };
  }

  const header = splitLine(lines[0]).map((h) => h.toLowerCase());
  const nameIdx = header.indexOf("full_name");
  const rollIdx = header.indexOf("roll_number");
  const yearIdx = header.indexOf("birth_year");

  const rows: ParsedStudentRow[] = [];
  let validCount = 0;
  let errorCount = 0;

  if (nameIdx === -1) {
    // Whole file is unusable without a name column; surface one clear error.
    return {
      rows: [
        {
          line: 1,
          full_name: "",
          roll_number: null,
          birth_year: null,
          error: 'Header must include a "full_name" column.',
        },
      ],
      validCount: 0,
      errorCount: 1,
    };
  }

  for (let i = 1; i < lines.length; i++) {
    const fields = splitLine(lines[i]);
    const fullName = (fields[nameIdx] ?? "").trim();
    const rollRaw = rollIdx >= 0 ? (fields[rollIdx] ?? "").trim() : "";
    const yearRaw = yearIdx >= 0 ? (fields[yearIdx] ?? "").trim() : "";

    let error: string | null = null;
    let birthYear: number | null = null;

    if (fullName.length < 2) {
      error = "Name needs at least 2 characters.";
    } else if (fullName.length > 120) {
      error = "Name is too long (max 120).";
    } else if (rollRaw.length > 20) {
      error = "Roll number is too long (max 20).";
    } else if (yearRaw.length > 0) {
      const parsed = Number(yearRaw);
      if (!Number.isInteger(parsed) || parsed < 1990 || parsed > currentYear) {
        error = `Birth year "${yearRaw}" looks wrong.`;
      } else {
        birthYear = parsed;
      }
    }

    if (error) errorCount++;
    else validCount++;

    rows.push({
      line: i + 1,
      full_name: fullName,
      roll_number: rollRaw.length > 0 ? rollRaw : null,
      birth_year: birthYear,
      error,
    });
  }

  return { rows, validCount, errorCount };
}
