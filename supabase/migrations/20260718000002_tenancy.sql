-- M2: Multi-tenant roster — schools, classes, students, teacher assignments.
-- Student PII is deliberately minimal: name, roll number, optional birth year.

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  grade smallint,
  created_at timestamptz not null default now()
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  full_name text not null,
  roll_number text,
  birth_year smallint check (birth_year is null or birth_year between 1990 and 2100),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.teacher_classes (
  teacher_id uuid not null references auth.users (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (teacher_id, class_id)
);

alter table public.user_roles
  add constraint user_roles_school_id_fkey
  foreign key (school_id) references public.schools (id) on delete set null;

create index classes_school_id_idx on public.classes (school_id);
create index students_school_id_idx on public.students (school_id);
create index students_class_id_idx on public.students (class_id);
create index teacher_classes_class_id_idx on public.teacher_classes (class_id);
