import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/server";

export default async function OverviewPage() {
  const supabase = await createClient();

  const [schools, classes, students, sessions] = await Promise.all([
    supabase.from("schools").select("id", { count: "exact", head: true }),
    supabase.from("classes").select("id", { count: "exact", head: true }),
    supabase
      .from("students")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
    supabase.from("sessions").select("id", { count: "exact", head: true }),
  ]);

  const stats = [
    { label: "Schools", value: schools.count ?? 0 },
    { label: "Classes", value: classes.count ?? 0 },
    { label: "Active students", value: students.count ?? 0 },
    { label: "Sessions recorded", value: sessions.count ?? 0 },
  ];

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-semibold">Overview</h1>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {stats.map((stat) => (
          <Card key={stat.label}>
            <CardHeader className="pb-2">
              <CardTitle className="text-muted-foreground text-sm font-medium">
                {stat.label}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-semibold">{stat.value}</p>
            </CardContent>
          </Card>
        ))}
      </div>
      <p className="text-muted-foreground text-sm">
        Recently finished sessions and the needs-review queue appear here once
        assessments ship (Phase 4).
      </p>
    </div>
  );
}
