import { createClient } from "@/lib/supabase/server";
import { JoinForm } from "./join-form";

export default async function JoinPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const supabase = await createClient();
  const { data: invite } = await supabase
    .from("teacher_invites")
    .select("email, status, schools(name)")
    .eq("token", token)
    .maybeSingle();

  if (!invite || invite.status !== "pending") {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="max-w-sm text-center">
          <h1 className="text-xl font-semibold">Invite not available</h1>
          <p className="text-muted-foreground mt-2 text-sm">
            This invite link is invalid, already used, or was revoked. Ask
            your school admin for a new one.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm space-y-4">
        <div>
          <h1 className="text-xl font-semibold">Join {invite.schools?.name}</h1>
          <p className="text-muted-foreground mt-1 text-sm">
            Create your teacher account for {invite.email}.
          </p>
        </div>
        <JoinForm token={token} email={invite.email} />
      </div>
    </div>
  );
}
