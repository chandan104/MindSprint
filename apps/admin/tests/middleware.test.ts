import { describe, expect, it } from "vitest";
import { isProtectedPath } from "@/lib/supabase/middleware";

describe("isProtectedPath", () => {
  it("leaves the login page public", () => {
    expect(isProtectedPath("/login")).toBe(false);
    expect(isProtectedPath("/login/reset")).toBe(false);
  });

  it("protects everything else", () => {
    expect(isProtectedPath("/")).toBe(true);
    expect(isProtectedPath("/schools")).toBe(true);
    expect(isProtectedPath("/students")).toBe(true);
    expect(isProtectedPath("/loginish")).toBe(true);
  });
});
