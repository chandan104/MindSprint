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
import { CrudDialog } from "@/components/admin/crud-dialog";
import { createSchool, deleteSchool, updateSchool } from "@/lib/actions/schools";
import { listSchools } from "@/lib/queries/schools";

export default async function SchoolsPage() {
  const schools = await listSchools();

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Schools</h1>
        <CrudDialog
          title="Add school"
          trigger={<Button>Add school</Button>}
          fields={[{ name: "name", label: "School name", required: true }]}
          action={createSchool}
        />
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Classes</TableHead>
            <TableHead className="w-40 text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {schools.map((school) => (
            <TableRow key={school.id}>
              <TableCell className="font-medium">{school.name}</TableCell>
              <TableCell>{school.classes[0]?.count ?? 0}</TableCell>
              <TableCell className="space-x-2 text-right">
                <CrudDialog
                  title="Edit school"
                  trigger={
                    <Button size="sm" variant="outline">
                      Edit
                    </Button>
                  }
                  fields={[
                    {
                      name: "name",
                      label: "School name",
                      required: true,
                      defaultValue: school.name,
                    },
                  ]}
                  action={updateSchool.bind(null, school.id)}
                />
                <ConfirmActionButton
                  label="Delete"
                  confirmTitle={`Delete ${school.name}?`}
                  confirmBody="This removes the school and all of its classes and students. This cannot be undone."
                  action={deleteSchool.bind(null, school.id)}
                />
              </TableCell>
            </TableRow>
          ))}
          {schools.length === 0 && (
            <TableRow>
              <TableCell colSpan={3} className="text-muted-foreground text-center">
                No schools yet.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
