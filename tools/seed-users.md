# Pilot auth users (one-time manual setup)

Auth users cannot be created by plain SQL seeds. Create these three accounts
once per environment (local Studio at http://127.0.0.1:54323 → Authentication,
or the hosted dashboard → Authentication → Users → Add user), then run the
SQL below to grant roles.

| Email (example) | Role | Scope |
|---|---|---|
| superadmin@yourdomain | super_admin | platform |
| schooladmin@yourdomain | school_admin | MindSprint Demo School |
| teacher@yourdomain | teacher | MindSprint Demo School, both classes |

After creating the users, run (SQL editor, as postgres), substituting the
real user UUIDs from the Authentication page:

```sql
insert into public.user_roles (user_id, role, school_id) values
  ('<SUPERADMIN-UUID>', 'super_admin', null),
  ('<SCHOOLADMIN-UUID>', 'school_admin', '00000000-0000-4000-8000-000000000001'),
  ('<TEACHER-UUID>', 'teacher', '00000000-0000-4000-8000-000000000001');

insert into public.teacher_classes (teacher_id, class_id) values
  ('<TEACHER-UUID>', '00000000-0000-4000-8000-000000000101'),
  ('<TEACHER-UUID>', '00000000-0000-4000-8000-000000000102');

insert into public.profiles (id, full_name) values
  ('<SUPERADMIN-UUID>', 'Super Admin'),
  ('<SCHOOLADMIN-UUID>', 'School Admin'),
  ('<TEACHER-UUID>', 'Demo Teacher');
```

Hosted project only: also enable the custom access token hook under
Authentication → Hooks → Customize Access Token (JWT) Claims →
`public.custom_access_token_hook`, or tokens will not carry
`user_role`/`school_id` and every RLS check will deny.
