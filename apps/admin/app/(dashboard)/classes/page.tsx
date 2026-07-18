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
import { createClass, deleteClass, updateClass } from "@/lib/actions/classes";
import { listClasses } from "@/lib/queries/classes";
import { listSchools } from "@/lib/queries/schools";

export default async function ClassesPage() {
  const [classes, schools] = await Promise.all([listClasses(), listSchools()]);

  const schoolOptions = schools.map((s) => ({ value: s.id, label: s.name }));
  const fields = (row?: (typeof classes)[number]): FieldDef[] => [
    { name: "name", label: "Class name", required: true, defaultValue: row?.name },
    {
      name: "grade",
      label: "Grade (1–12)",
      type: "number",
      defaultValue: row?.grade,
    },
    {
      name: "school_id",
      label: "School",
      required: true,
      options: schoolOptions,
      defaultValue: row?.school_id,
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Classes</h1>
        <CrudDialog
          title="Add class"
          trigger={<Button>Add class</Button>}
          fields={fields()}
          action={createClass}
        />
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Grade</TableHead>
            <TableHead>School</TableHead>
            <TableHead>Students</TableHead>
            <TableHead className="w-40 text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {classes.map((row) => (
            <TableRow key={row.id}>
              <TableCell className="font-medium">{row.name}</TableCell>
              <TableCell>{row.grade ?? "—"}</TableCell>
              <TableCell>{row.schools?.name ?? "—"}</TableCell>
              <TableCell>{row.students[0]?.count ?? 0}</TableCell>
              <TableCell className="space-x-2 text-right">
                <CrudDialog
                  title="Edit class"
                  trigger={
                    <Button size="sm" variant="outline">
                      Edit
                    </Button>
                  }
                  fields={fields(row)}
                  action={updateClass.bind(null, row.id)}
                />
                <ConfirmActionButton
                  label="Delete"
                  confirmTitle={`Delete ${row.name}?`}
                  confirmBody="This removes the class and all of its students. This cannot be undone."
                  action={deleteClass.bind(null, row.id)}
                />
              </TableCell>
            </TableRow>
          ))}
          {classes.length === 0 && (
            <TableRow>
              <TableCell colSpan={5} className="text-muted-foreground text-center">
                No classes yet.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
