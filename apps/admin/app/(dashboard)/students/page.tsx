import Link from "next/link";
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
import { ConfirmActionButton } from "@/components/admin/confirm-action-button";
import { CrudDialog, type FieldDef } from "@/components/admin/crud-dialog";
import { listClasses } from "@/lib/queries/classes";
import { listStudents } from "@/lib/queries/students";
import {
  createStudent,
  deactivateStudent,
  updateStudent,
} from "@/lib/actions/students";

export default async function StudentsPage() {
  const [students, classes] = await Promise.all([listStudents(), listClasses()]);

  const classOptions = classes.map((c) => ({
    value: c.id,
    label: `${c.name}${c.schools ? ` — ${c.schools.name}` : ""}`,
  }));

  const fields = (row?: (typeof students)[number]): FieldDef[] => [
    {
      name: "full_name",
      label: "Full name",
      required: true,
      defaultValue: row?.full_name,
    },
    { name: "roll_number", label: "Roll number", defaultValue: row?.roll_number },
    {
      name: "birth_year",
      label: "Birth year (optional)",
      type: "number",
      defaultValue: row?.birth_year,
    },
    {
      name: "class_id",
      label: "Class",
      required: true,
      options: classOptions,
      defaultValue: row?.class_id,
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Students</h1>
        <CrudDialog
          title="Add student"
          trigger={<Button>Add student</Button>}
          fields={fields()}
          action={createStudent}
        />
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Roll</TableHead>
            <TableHead>Class</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="w-44 text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {students.map((student) => (
            <TableRow key={student.id}>
              <TableCell className="font-medium">
                <Link
                  href={`/students/${student.id}`}
                  className="hover:underline"
                >
                  {student.full_name}
                </Link>
              </TableCell>
              <TableCell>{student.roll_number ?? "—"}</TableCell>
              <TableCell>{student.classes?.name ?? "—"}</TableCell>
              <TableCell>
                {student.is_active ? (
                  <Badge>Active</Badge>
                ) : (
                  <Badge variant="secondary">Inactive</Badge>
                )}
              </TableCell>
              <TableCell className="space-x-2 text-right">
                <CrudDialog
                  title="Edit student"
                  trigger={
                    <Button size="sm" variant="outline">
                      Edit
                    </Button>
                  }
                  fields={fields(student)}
                  action={updateStudent.bind(null, student.id)}
                />
                {student.is_active && (
                  <ConfirmActionButton
                    label="Deactivate"
                    confirmTitle={`Deactivate ${student.full_name}?`}
                    confirmBody="The student disappears from teacher rosters. Assessment history is kept. Permanent erasure is a separate audited step."
                    action={deactivateStudent.bind(null, student.id)}
                  />
                )}
              </TableCell>
            </TableRow>
          ))}
          {students.length === 0 && (
            <TableRow>
              <TableCell colSpan={5} className="text-muted-foreground text-center">
                No students yet.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
