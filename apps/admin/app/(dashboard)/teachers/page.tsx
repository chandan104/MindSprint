import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { CrudDialog } from "@/components/admin/crud-dialog";
import { UnassignBadgeButton } from "./unassign-badge-button";
import { assignClass } from "@/lib/actions/teachers";
import { listClasses } from "@/lib/queries/classes";
import { listTeachers } from "@/lib/queries/teachers";

export default async function TeachersPage() {
  const [teachers, classes] = await Promise.all([listTeachers(), listClasses()]);

  const classOptions = classes.map((c) => ({
    value: c.id,
    label: `${c.name}${c.schools ? ` — ${c.schools.name}` : ""}`,
  }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Teachers</h1>
        <p className="text-muted-foreground mt-1 text-sm">
          Teacher accounts are created in the Supabase dashboard in this phase
          (see tools/seed-users.md). Assign classes to teachers here.
        </p>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Assigned classes</TableHead>
            <TableHead className="w-36 text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {teachers.map((teacher) => (
            <TableRow key={teacher.user_id}>
              <TableCell className="font-medium">
                {teacher.full_name ?? "Unnamed teacher"}
              </TableCell>
              <TableCell className="space-x-1.5">
                {teacher.assignments.length === 0 && (
                  <Badge variant="secondary">No classes</Badge>
                )}
                {teacher.assignments.map((assignment) => (
                  <UnassignBadgeButton
                    key={assignment.class_id}
                    teacherId={teacher.user_id}
                    classId={assignment.class_id}
                    className={assignment.class_name}
                  />
                ))}
              </TableCell>
              <TableCell className="text-right">
                <CrudDialog
                  title="Assign class"
                  trigger={
                    <Button size="sm" variant="outline">
                      Assign class
                    </Button>
                  }
                  fields={[
                    {
                      name: "teacher_id",
                      label: "Teacher",
                      required: true,
                      options: [
                        {
                          value: teacher.user_id,
                          label: teacher.full_name ?? teacher.user_id,
                        },
                      ],
                      defaultValue: teacher.user_id,
                    },
                    {
                      name: "class_id",
                      label: "Class",
                      required: true,
                      options: classOptions,
                    },
                  ]}
                  action={assignClass}
                />
              </TableCell>
            </TableRow>
          ))}
          {teachers.length === 0 && (
            <TableRow>
              <TableCell colSpan={3} className="text-muted-foreground text-center">
                No teachers yet. Create teacher accounts per tools/seed-users.md.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
