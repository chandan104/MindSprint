import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/server";
import { getOverviewCounts } from "@/lib/queries/sessions";

export default async function OverviewPage() {
  const supabase = await createClient();

  const [schools, classes, counts] = await Promise.all([
    supabase.from("schools").select("id", { count: "exact", head: true }),
    supabase.from("classes").select("id", { count: "exact", head: true }),
    getOverviewCounts(),
  ]);

  const stats = [
    { label: "Sessions today", value: counts.sessionsToday, href: "/sessions" },
    { label: "Active students", value: counts.students, href: "/students" },
    { label: "Classes", value: classes.count ?? 0, href: "/classes" },
    { label: "Schools", value: schools.count ?? 0, href: "/schools" },
  ];

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-semibold">Overview</h1>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {stats.map((stat) => (
          <Link key={stat.label} href={stat.href}>
            <Card className="hover:bg-accent/40 transition">
              <CardHeader className="pb-2">
                <CardTitle className="text-muted-foreground text-sm font-medium">
                  {stat.label}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-3xl font-semibold">{stat.value}</p>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {(counts.pending > 0 || counts.invalid > 0) && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {counts.pending > 0 && (
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">
                  Processing
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-semibold">{counts.pending}</p>
                <p className="text-muted-foreground text-sm">
                  Uploaded sessions awaiting canonical metrics (the sweep runs
                  every minute).
                </p>
              </CardContent>
            </Card>
          )}
          {counts.invalid > 0 && (
            <Card className="border-destructive/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-destructive text-sm font-medium">
                  Needs review
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-semibold">{counts.invalid}</p>
                <p className="text-muted-foreground text-sm">
                  Sessions whose metrics computation failed —{" "}
                  <Link className="underline" href="/sessions">
                    inspect them
                  </Link>
                  .
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      )}
    </div>
  );
}
