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
import { CopyInviteLink } from "@/components/admin/copy-invite-link";
import { CrudDialog } from "@/components/admin/crud-dialog";
import { UnassignBadgeButton } from "./unassign-badge-button";
import { assignClass } from "@/lib/actions/teachers";
import { inviteTeacher, revokeInvite } from "@/lib/actions/invites";
import { listClasses } from "@/lib/queries/classes";
import { listPendingInvites } from "@/lib/queries/invites";
import { listSchools } from "@/lib/queries/schools";
import { listTeachers } from "@/lib/queries/teachers";

export default async function TeachersPage() {
  const [teachers, classes, invites, schools] = await Promise.all([
    listTeachers(),
    listClasses(),
    listPendingInvites(),
    listSchools(),
  ]);

  const classOptions = classes.map((c) => ({
    value: c.id,
    label: `${c.name}${c.schools ? ` — ${c.schools.name}` : ""}`,
  }));

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Teachers</h1>
          <p className="text-muted-foreground mt-1 text-sm">
            Invite a teacher by email — they sign up and join your school
            themselves.
          </p>
        </div>
        <CrudDialog
          title="Invite teacher"
          trigger={<Button>Invite teacher</Button>}
          fields={[
            { name: "email", label: "Email", required: true, type: "email" },
            {
              name: "school_id",
              label: "School",
              required: true,
              options: schools.map((s) => ({ value: s.id, label: s.name })),
            },
          ]}
          action={inviteTeacher}
        />
      </div>

      {invites.length > 0 && (
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Pending invites</h2>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Email</TableHead>
                <TableHead>School</TableHead>
                <TableHead>Invited</TableHead>
                <TableHead className="w-64 text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {invites.map((invite) => (
                <TableRow key={invite.id}>
                  <TableCell className="font-medium">{invite.email}</TableCell>
                  <TableCell>{invite.schools?.name ?? "—"}</TableCell>
                  <TableCell>
                    {new Date(invite.created_at).toLocaleDateString()}
                  </TableCell>
                  <TableCell className="space-x-2 text-right">
                    <CopyInviteLink token={invite.token} />
                    <ConfirmActionButton
                      label="Revoke"
                      confirmTitle={`Revoke invite for ${invite.email}?`}
                      confirmBody="The link stops working immediately."
                      action={revokeInvite.bind(null, invite.id)}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      <div className="space-y-2">
        <h2 className="text-lg font-semibold">Active teachers</h2>
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
                  No teachers yet. Invite one above.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
