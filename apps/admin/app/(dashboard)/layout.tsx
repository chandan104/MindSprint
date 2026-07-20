import Link from "next/link";
import { redirect } from "next/navigation";
import {
  Activity,
  Brain,
  GraduationCap,
  LayoutDashboard,
  School,
  Users,
  UserSquare,
} from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { SignOutButton } from "./sign-out-button";

const NAV = [
  { href: "/", label: "Overview", icon: LayoutDashboard },
  { href: "/sessions", label: "Sessions", icon: Activity },
  { href: "/schools", label: "Schools", icon: School },
  { href: "/classes", label: "Classes", icon: GraduationCap },
  { href: "/teachers", label: "Teachers", icon: UserSquare },
  { href: "/students", label: "Students", icon: Users },
];

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  return (
    <div className="flex min-h-screen">
      <aside className="bg-sidebar border-sidebar-border flex w-56 flex-col border-r">
        <div className="flex items-center gap-2 px-4 py-5">
          <Brain className="text-primary size-6" aria-hidden />
          <span className="text-lg font-semibold">MindSprint</span>
        </div>
        <nav className="flex-1 space-y-1 px-2">
          {NAV.map(({ href, label, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className="hover:bg-sidebar-accent flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium"
            >
              <Icon className="size-4" aria-hidden />
              {label}
            </Link>
          ))}
        </nav>
        <div className="border-sidebar-border border-t p-3">
          <p className="text-muted-foreground mb-2 truncate text-xs">
            {user.email}
          </p>
          <SignOutButton />
        </div>
      </aside>
      <main className="flex-1 overflow-x-auto p-8">{children}</main>
    </div>
  );
}
