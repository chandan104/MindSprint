import Link from "next/link";
import { redirect } from "next/navigation";
import {
  Activity,
  Brain,
  GraduationCap,
  LayoutDashboard,
  ScrollText,
  School,
  Users,
  UserSquare,
} from "lucide-react";
import { currentUserRole, getCurrentUser } from "@/lib/queries/student-report";
import packageJson from "../../package.json";
import { SignOutButton } from "./sign-out-button";

const NAV = [
  { href: "/", label: "Overview", icon: LayoutDashboard },
  { href: "/sessions", label: "Sessions", icon: Activity },
  { href: "/schools", label: "Schools", icon: School },
  { href: "/classes", label: "Classes", icon: GraduationCap },
  { href: "/teachers", label: "Teachers", icon: UserSquare },
  { href: "/students", label: "Students", icon: Users },
];

const SUPER_ADMIN_NAV = [
  { href: "/audit", label: "Audit log", icon: ScrollText },
];

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  // Both are React `cache()`d: this validates the JWT and reads the role once
  // per request, shared with whatever page renders inside this layout.
  const [user, role] = await Promise.all([getCurrentUser(), currentUserRole()]);
  if (!user) redirect("/login");
  const nav =
    role === "super_admin" ? [...NAV, ...SUPER_ADMIN_NAV] : NAV;

  return (
    <div className="flex min-h-screen">
      <aside className="bg-sidebar border-sidebar-border flex w-56 flex-col border-r">
        <div className="flex items-center gap-2 px-4 py-5">
          <Brain className="text-primary size-6" aria-hidden />
          <span className="text-lg font-semibold">Skill Lab</span>
        </div>
        <nav className="flex-1 space-y-1 px-2">
          {nav.map(({ href, label, icon: Icon }) => (
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
          <p className="text-muted-foreground/60 mt-3 font-mono text-[10px]">
            v{packageJson.version}
            {process.env.VERCEL_GIT_COMMIT_SHA
              ? ` · ${process.env.VERCEL_GIT_COMMIT_SHA.slice(0, 7)}`
              : ""}
          </p>
        </div>
      </aside>
      <main className="flex-1 overflow-x-auto p-8">{children}</main>
    </div>
  );
}
