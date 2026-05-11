-- BLE Attendance: role-based schema (Admin, Professor, Student)
-- Run this whole file in Supabase SQL editor.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.professors (
  id text primary key,
  full_name text not null,
  max_students int not null default 30 check (max_students between 1 and 30),
  created_at timestamptz not null default now()
);

create table if not exists public.students (
  id text primary key,
  full_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text not null,
  role text not null check (role in ('admin', 'professor', 'student')),
  linked_id text not null,
  full_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.subject_offerings (
  id uuid primary key default gen_random_uuid(),
  professor_id text not null references public.professors(id) on delete cascade,
  subject_code text not null,
  subject_title text not null,
  section text not null,
  beacon_uuid uuid not null,
  beacon_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.student_subject_enrollments (
  student_id text not null references public.students(id) on delete cascade,
  offering_id uuid not null references public.subject_offerings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (student_id, offering_id)
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  professor_id text not null references public.professors(id) on delete cascade,
  offering_id uuid not null references public.subject_offerings(id) on delete cascade,
  subject text not null,
  beacon_uuid uuid not null,
  beacon_name text not null,
  is_active boolean not null default true,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

-- Upgrade path for old schema versions where sessions.offering_id did not exist.
alter table public.sessions
  add column if not exists offering_id uuid;

-- Upgrade path for older sessions schemas.
alter table public.sessions
  add column if not exists subject text;
alter table public.sessions
  add column if not exists beacon_uuid uuid;
alter table public.sessions
  add column if not exists beacon_name text;
alter table public.sessions
  add column if not exists started_at timestamptz default now();
alter table public.sessions
  add column if not exists ended_at timestamptz;
alter table public.sessions
  add column if not exists is_active boolean default true;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'sessions_offering_id_fkey'
  ) then
    alter table public.sessions
      add constraint sessions_offering_id_fkey
      foreign key (offering_id) references public.subject_offerings(id) on delete cascade;
  end if;
end $$;

create unique index if not exists sessions_unique_active_offering_idx
  on public.sessions (offering_id, is_active)
  where is_active = true;

create index if not exists sessions_active_idx
  on public.sessions (is_active, started_at desc);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  student_id text not null references public.students(id) on delete cascade,
  student_name text not null,
  marked_at timestamptz not null default now(),
  device_name text,
  device_uuid uuid,
  device_mac text,
  device_fingerprint text
);

-- Upgrade path for older attendance schemas without device metadata.
alter table public.attendance
  add column if not exists device_name text;
alter table public.attendance
  add column if not exists device_uuid uuid;
alter table public.attendance
  add column if not exists device_mac text;
alter table public.attendance
  add column if not exists device_fingerprint text;

create unique index if not exists attendance_unique_session_student_idx
  on public.attendance (session_id, student_id);

create index if not exists attendance_device_fingerprint_idx
  on public.attendance (device_fingerprint)
  where device_fingerprint is not null;

create index if not exists attendance_device_uuid_idx
  on public.attendance (device_uuid)
  where device_uuid is not null;

create table if not exists public.student_devices (
  id uuid primary key default gen_random_uuid(),
  student_id text not null references public.students(id) on delete cascade,
  device_uuid uuid not null,
  device_name text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (student_id, device_uuid)
);

create index if not exists student_devices_device_uuid_idx
  on public.student_devices (device_uuid);

create index if not exists student_devices_student_id_idx
  on public.student_devices (student_id);

-- ---------- FUNCTIONS ----------

create or replace function public.app_login(
  p_username text,
  p_password text,
  p_role text
)
returns table (
  role text,
  linked_id text,
  full_name text,
  username text
)
language sql
security definer
set search_path = public
as $$
  select
    u.role,
    u.linked_id,
    u.full_name,
    u.username
  from public.app_users u
  where lower(u.username) = lower(trim(p_username))
    and u.role = trim(p_role)
    and u.password_hash = extensions.crypt(trim(p_password), u.password_hash)
  limit 1;
$$;

drop function if exists public.register_student(text, text, text, text);

create or replace function public.register_student(
  p_student_id text,
  p_full_name text,
  p_username text,
  p_password text,
  p_device_uuid uuid default null,
  p_device_name text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.app_users
    where lower(username) = lower(trim(p_username))
  ) then
    raise exception 'Username already exists.';
  end if;

  insert into public.students (id, full_name)
  values (trim(p_student_id), trim(p_full_name))
  on conflict (id) do update
  set full_name = excluded.full_name;

  insert into public.app_users (username, password_hash, role, linked_id, full_name)
  values (
    trim(p_username),
    extensions.crypt(trim(p_password), extensions.gen_salt('bf')),
    'student',
    trim(p_student_id),
    trim(p_full_name)
  );

  if p_device_uuid is not null then
    insert into public.student_devices (student_id, device_uuid, device_name)
    values (
      trim(p_student_id),
      p_device_uuid,
      nullif(trim(coalesce(p_device_name, '')), '')
    )
    on conflict (student_id, device_uuid) do update
      set device_name = coalesce(excluded.device_name, public.student_devices.device_name),
          last_seen_at = now();
  end if;

  return trim(p_student_id);
end;
$$;

create or replace function public.sync_student_device_from_attendance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.device_uuid is not null then
    insert into public.student_devices (student_id, device_uuid, device_name)
    values (
      new.student_id,
      new.device_uuid,
      nullif(trim(coalesce(new.device_name, '')), '')
    )
    on conflict (student_id, device_uuid) do update
      set device_name = coalesce(excluded.device_name, public.student_devices.device_name),
          last_seen_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_student_device_from_attendance on public.attendance;
create trigger trg_sync_student_device_from_attendance
after insert or update of device_uuid, device_name
on public.attendance
for each row
execute function public.sync_student_device_from_attendance();

alter table public.professors
  alter column max_students set default 30;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'professors_max_students_check'
  ) then
    alter table public.professors
      drop constraint professors_max_students_check;
  end if;
end $$;

alter table public.professors
  add constraint professors_max_students_check
  check (max_students between 1 and 30);

-- Hard cleanup: remove all overloaded versions first to avoid PostgREST ambiguity.
do $$
declare
  fn record;
begin
  for fn in
    select
      n.nspname as schema_name,
      p.proname as func_name,
      pg_get_function_identity_arguments(p.oid) as identity_args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_create_professor', 'admin_create_professor_account')
  loop
    execute format(
      'drop function if exists %I.%I(%s);',
      fn.schema_name,
      fn.func_name,
      fn.identity_args
    );
  end loop;
end $$;

-- Single canonical function used by app RPC.
create or replace function public.admin_create_professor_account(
  p_professor_id text,
  p_full_name text,
  p_username text,
  p_password text,
  p_max_students int default 30
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.app_users
    where lower(username) = lower(trim(p_username))
  ) then
    raise exception 'Username already exists.';
  end if;

  insert into public.professors (id, full_name, max_students)
  values (
    trim(p_professor_id),
    trim(p_full_name),
    least(greatest(coalesce(p_max_students, 30), 1), 30)
  )
  on conflict (id) do update
  set full_name = excluded.full_name,
      max_students = excluded.max_students;

  insert into public.app_users (username, password_hash, role, linked_id, full_name)
  values (
    trim(p_username),
    extensions.crypt(trim(p_password), extensions.gen_salt('bf')),
    'professor',
    trim(p_professor_id),
    trim(p_full_name)
  );

  return trim(p_professor_id);
end;
$$;

create or replace function public.admin_create_subject_offering(
  p_professor_id text,
  p_subject_code text,
  p_subject_title text,
  p_section text,
  p_beacon_uuid text,
  p_beacon_name text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not exists (
    select 1 from public.professors
    where id = trim(p_professor_id)
  ) then
    raise exception 'Professor not found.';
  end if;

  insert into public.subject_offerings (
    professor_id,
    subject_code,
    subject_title,
    section,
    beacon_uuid,
    beacon_name
  ) values (
    trim(p_professor_id),
    trim(p_subject_code),
    trim(p_subject_title),
    trim(p_section),
    trim(p_beacon_uuid)::uuid,
    trim(p_beacon_name)
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.get_student_dashboard(
  p_student_id text
)
returns table (
  offering_id uuid,
  subject_code text,
  subject_title text,
  section text,
  professor_id text,
  professor_name text,
  beacon_uuid uuid,
  beacon_name text
)
language sql
security definer
set search_path = public
as $$
  select
    so.id as offering_id,
    so.subject_code,
    so.subject_title,
    so.section,
    so.professor_id,
    p.full_name as professor_name,
    so.beacon_uuid,
    so.beacon_name
  from public.student_subject_enrollments sse
  join public.subject_offerings so on so.id = sse.offering_id
  join public.professors p on p.id = so.professor_id
  where sse.student_id = trim(p_student_id)
    and so.is_active = true
  order by so.subject_code, so.section;
$$;

create or replace function public.admin_assign_student_to_offering(
  p_student_id text,
  p_offering_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject_code text;
begin
  select so.subject_code
  into v_subject_code
  from public.subject_offerings so
  where so.id = p_offering_id;

  if v_subject_code is null then
    raise exception 'Offering not found.';
  end if;

  delete from public.student_subject_enrollments sse
  using public.subject_offerings so
  where sse.offering_id = so.id
    and sse.student_id = trim(p_student_id)
    and so.subject_code = v_subject_code;

  insert into public.student_subject_enrollments (student_id, offering_id)
  values (trim(p_student_id), p_offering_id)
  on conflict (student_id, offering_id) do nothing;
end;
$$;

create or replace function public.get_admin_enrollments()
returns table (
  student_id text,
  student_name text,
  offering_id uuid,
  professor_id text,
  professor_name text,
  subject_code text,
  subject_title text,
  section text
)
language sql
security definer
set search_path = public
as $$
  select
    sse.student_id,
    s.full_name as student_name,
    sse.offering_id,
    so.professor_id,
    p.full_name as professor_name,
    so.subject_code,
    so.subject_title,
    so.section
  from public.student_subject_enrollments sse
  join public.students s on s.id = sse.student_id
  join public.subject_offerings so on so.id = sse.offering_id
  join public.professors p on p.id = so.professor_id
  order by s.full_name, so.subject_code, so.section;
$$;

create or replace function public.update_display_name(
  p_role text,
  p_linked_id text,
  p_full_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if trim(p_role) = 'student' then
    update public.students
    set full_name = trim(p_full_name)
    where id = trim(p_linked_id);
  elsif trim(p_role) = 'professor' then
    update public.professors
    set full_name = trim(p_full_name)
    where id = trim(p_linked_id);
  else
    raise exception 'Invalid role.';
  end if;

  update public.app_users
  set full_name = trim(p_full_name)
  where role = trim(p_role)
    and linked_id = trim(p_linked_id);
end;
$$;

create or replace function public.get_professor_session_history(
  p_professor_id text
)
returns table (
  session_id uuid,
  subject_code text,
  subject_title text,
  section text,
  started_at timestamptz,
  ended_at timestamptz,
  is_active boolean
)
language sql
security definer
set search_path = public
as $$
  select
    s.id as session_id,
    so.subject_code,
    so.subject_title,
    so.section,
    s.started_at,
    s.ended_at,
    s.is_active
  from public.sessions s
  join public.subject_offerings so on so.id = s.offering_id
  where s.professor_id = trim(p_professor_id)
  order by s.started_at desc;
$$;

create or replace function public.get_professor_session_attendees(
  p_professor_id text,
  p_session_id uuid
)
returns table (
  student_id text,
  student_name text,
  marked_at timestamptz,
  device_used text
)
language sql
security definer
set search_path = public
as $$
  select
    a.student_id,
    a.student_name,
    a.marked_at,
    coalesce(
      case
        when nullif(trim(a.device_name), '') is not null and a.device_uuid is not null
          then trim(a.device_name) || ' (UUID-Device: ' || a.device_uuid::text || ')'
        when nullif(trim(a.device_name), '') is not null
          then trim(a.device_name)
        when a.device_uuid is not null
          then 'UUID-Device: ' || a.device_uuid::text
        else null
      end,
      nullif(trim(a.device_name), ''),
      case when a.device_uuid is not null then 'UUID-Device: ' || a.device_uuid::text else null end,
      nullif(trim(a.device_fingerprint), ''),
      'Unknown device'
    ) as device_used
  from public.attendance a
  join public.sessions s on s.id = a.session_id
  where s.id = p_session_id
    and s.professor_id = trim(p_professor_id)
  order by a.marked_at asc;
$$;

create or replace function public.get_session_device_anomalies(
  p_session_id uuid
)
returns table (
  device_uuid uuid,
  students_count bigint,
  student_ids text[],
  student_names text[],
  first_marked_at timestamptz,
  last_marked_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    a.device_uuid,
    count(distinct a.student_id) as students_count,
    array_agg(distinct a.student_id order by a.student_id) as student_ids,
    array_agg(distinct a.student_name order by a.student_name) as student_names,
    min(a.marked_at) as first_marked_at,
    max(a.marked_at) as last_marked_at
  from public.attendance a
  where a.session_id = p_session_id
    and a.device_uuid is not null
  group by a.device_uuid
  having count(distinct a.student_id) > 1
  order by students_count desc, first_marked_at asc;
$$;

create or replace function public.get_student_attendance_history(
  p_student_id text
)
returns table (
  subject_code text,
  subject_title text,
  section text,
  professor_name text,
  session_started_at timestamptz,
  marked_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    so.subject_code,
    so.subject_title,
    so.section,
    p.full_name as professor_name,
    s.started_at as session_started_at,
    a.marked_at
  from public.attendance a
  join public.sessions s on s.id = a.session_id
  join public.subject_offerings so on so.id = s.offering_id
  join public.professors p on p.id = s.professor_id
  where a.student_id = trim(p_student_id)
  order by a.marked_at desc;
$$;

-- ---------- CLEAR HISTORY (RLS-SAFE) ----------

create or replace function public.clear_professor_history(
  p_professor_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Ensure deletes succeed when RLS is enabled (function runs as definer).
  perform set_config('row_security', 'off', true);
  delete from public.sessions
  where professor_id = trim(p_professor_id);
end;
$$;

create or replace function public.clear_student_history(
  p_student_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('row_security', 'off', true);
  delete from public.attendance
  where student_id = trim(p_student_id);
end;
$$;

grant execute on function public.app_login(text, text, text) to anon, authenticated;
grant execute on function public.register_student(text, text, text, text, uuid, text) to anon, authenticated;
grant execute on function public.admin_create_professor_account(text, text, text, text, int) to anon, authenticated;
grant execute on function public.admin_create_subject_offering(text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.admin_assign_student_to_offering(text, uuid) to anon, authenticated;
grant execute on function public.get_admin_enrollments() to anon, authenticated;
grant execute on function public.get_student_dashboard(text) to anon, authenticated;
grant execute on function public.get_professor_session_history(text) to anon, authenticated;
grant execute on function public.get_professor_session_attendees(text, uuid) to anon, authenticated;
grant execute on function public.get_session_device_anomalies(uuid) to anon, authenticated;
grant execute on function public.get_student_attendance_history(text) to anon, authenticated;
grant execute on function public.update_display_name(text, text, text) to anon, authenticated;
grant execute on function public.clear_professor_history(text) to anon, authenticated;
grant execute on function public.clear_student_history(text) to anon, authenticated;

-- ---------- RLS ----------

alter table public.professors enable row level security;
alter table public.students enable row level security;
alter table public.app_users enable row level security;
alter table public.subject_offerings enable row level security;
alter table public.student_subject_enrollments enable row level security;
alter table public.sessions enable row level security;
alter table public.attendance enable row level security;

drop policy if exists "open read professors" on public.professors;
create policy "open read professors" on public.professors for select to anon using (true);

drop policy if exists "open read students" on public.students;
create policy "open read students" on public.students for select to anon using (true);

drop policy if exists "open read subject offerings" on public.subject_offerings;
create policy "open read subject offerings" on public.subject_offerings for select to anon using (true);

drop policy if exists "open read student enrollments" on public.student_subject_enrollments;
create policy "open read student enrollments" on public.student_subject_enrollments for select to anon using (true);

drop policy if exists "open insert student enrollments" on public.student_subject_enrollments;
create policy "open insert student enrollments" on public.student_subject_enrollments for insert to anon with check (true);

drop policy if exists "open update student enrollments" on public.student_subject_enrollments;
create policy "open update student enrollments" on public.student_subject_enrollments for update to anon using (true) with check (true);

drop policy if exists "open read sessions" on public.sessions;
create policy "open read sessions" on public.sessions for select to anon using (true);

drop policy if exists "open insert sessions" on public.sessions;
create policy "open insert sessions" on public.sessions for insert to anon with check (true);

drop policy if exists "open update sessions" on public.sessions;
create policy "open update sessions" on public.sessions for update to anon using (true) with check (true);

drop policy if exists "open delete sessions" on public.sessions;
create policy "open delete sessions" on public.sessions for delete to anon using (true);

drop policy if exists "open read attendance" on public.attendance;
create policy "open read attendance" on public.attendance for select to anon using (true);

drop policy if exists "open insert attendance" on public.attendance;
create policy "open insert attendance" on public.attendance for insert to anon with check (true);

drop policy if exists "open delete attendance" on public.attendance;
create policy "open delete attendance" on public.attendance for delete to anon using (true);

drop policy if exists "deny direct app users select" on public.app_users;
create policy "deny direct app users select" on public.app_users for select to anon using (false);

-- ---------- SEED ADMIN ----------

insert into public.app_users (username, password_hash, role, linked_id, full_name)
values (
  'ADMIN-NATH',
  extensions.crypt('1234567890', extensions.gen_salt('bf')),
  'admin',
  'ADMIN-NATH',
  'Administrator Nathan'
)
on conflict (username) do update
set password_hash = excluded.password_hash,
    role = excluded.role,
    linked_id = excluded.linked_id,
    full_name = excluded.full_name;

-- Force PostgREST to refresh function/schema cache.
notify pgrst, 'reload schema';
