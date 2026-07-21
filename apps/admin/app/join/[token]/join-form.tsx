"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";

export function JoinForm({ token, email }: { token: string; email: string }) {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("Use at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Passwords don't match.");
      return;
    }
    setPending(true);
    const supabase = createClient();

    const { error: signUpError } = await supabase.auth.signUp({
      email,
      password,
    });
    if (signUpError) {
      setError(signUpError.message);
      setPending(false);
      return;
    }

    // Email confirmation may be required depending on project auth settings;
    // if so there is no session yet to claim with.
    const { data: sessionData } = await supabase.auth.getSession();
    if (!sessionData.session) {
      setPending(false);
      router.push("/login?message=Check your email to confirm your account, then sign in.");
      return;
    }

    const { error: claimError } = await supabase.rpc("claim_teacher_invite", {
      p_token: token,
    });
    setPending(false);
    if (claimError) {
      setError(claimError.message);
      return;
    }
    router.push("/");
  }

  return (
    <form onSubmit={submit} className="space-y-3">
      <div>
        <label className="mb-1 block text-sm font-medium">Email</label>
        <input
          value={email}
          disabled
          className="border-input bg-muted w-full rounded-md border p-2 text-sm"
        />
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium">Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="border-input bg-background w-full rounded-md border p-2 text-sm"
          required
        />
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium">Confirm password</label>
        <input
          type="password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          className="border-input bg-background w-full rounded-md border p-2 text-sm"
          required
        />
      </div>
      {error && <p className="text-destructive text-sm">{error}</p>}
      <Button type="submit" disabled={pending} className="w-full">
        {pending ? "Creating account…" : "Create account & join"}
      </Button>
    </form>
  );
}
