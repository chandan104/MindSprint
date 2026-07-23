import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { listAuditLogs } from "@/lib/queries/audit";
import { currentUserRole } from "@/lib/queries/student-report";

function actionBadge(action: string) {
  switch (action) {
    case "INSERT":
      return <Badge>Created</Badge>;
    case "UPDATE":
      return <Badge variant="secondary">Updated</Badge>;
    case "DELETE":
      return <Badge variant="destructive">Deleted</Badge>;
    case "ERASE":
      return <Badge variant="destructive">Erased</Badge>;
    default:
      return <Badge variant="outline">{action}</Badge>;
  }
}

// A concise, human summary of what changed — full snapshots live in the
// before/after JSON but a teacher-readable name is what matters at a glance.
function describe(row: {
  action: string;
  entity: string;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
}): string {
  const snap = row.after ?? row.before ?? {};
  const name =
    (snap["full_name"] as string) ??
    (snap["name"] as string) ??
    (snap["email"] as string) ??
    (snap["version"] as string) ??
    (snap["key"] as string) ??
    (snap["reason"] as string) ??
    "";
  return name ? `${row.entity} · ${name}` : row.entity;
}

export default async function AuditPage() {
  const role = await currentUserRole();
  if (role !== "super_admin") {
    return (
      <div className="space-y-2">
        <h1 className="text-2xl font-semibold">Audit log</h1>
        <p className="text-muted-foreground text-sm">
          The audit log is available to super admins only.
        </p>
      </div>
    );
  }

  const logs = await listAuditLogs();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Audit log</h1>
        <p className="text-muted-foreground text-sm">
          Every change to schools, classes, students, teachers, content, and
          platform settings — who, what, and when. Most recent first.
        </p>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-44">When</TableHead>
            <TableHead>Action</TableHead>
            <TableHead>What changed</TableHead>
            <TableHead>By</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {logs.map((row) => (
            <TableRow key={row.id}>
              <TableCell className="text-muted-foreground whitespace-nowrap">
                {new Date(row.at).toLocaleString()}
              </TableCell>
              <TableCell>{actionBadge(row.action)}</TableCell>
              <TableCell>{describe(row)}</TableCell>
              <TableCell>{row.actor_name}</TableCell>
            </TableRow>
          ))}
          {logs.length === 0 && (
            <TableRow>
              <TableCell
                colSpan={4}
                className="text-muted-foreground text-center"
              >
                No changes recorded yet.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
