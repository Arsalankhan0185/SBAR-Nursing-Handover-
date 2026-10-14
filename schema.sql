-- SBAR Shift Handover: initial PostgreSQL schema for Supabase.
-- Run this whole file in Supabase Dashboard > SQL Editor.
-- Keep Row Level Security enabled. Do not add a service_role key to frontend code.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'Staff member',
  role text not null default 'nurse' check (role in ('admin','nurse')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wards (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  floor text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  mr_number text not null unique,
  age integer check (age is null or age between 0 and 125),
  gender text not null default 'Not recorded',
  ward text not null,
  floor text,
  room_number text,
  bed_number text not null,
  diagnosis text not null,
  allergies text,
  clinical_status text not null default 'Stable' check (clinical_status in ('Stable','Guarded','High risk','Not assessed')),
  admission_date date,
  discharged_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nursing_assessments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  shift text not null check (shift in ('Morning','Evening','Night')),
  assessed_at timestamptz not null default now(),
  consciousness text,
  pain_score integer check (pain_score is null or pain_score between 0 and 10),
  skin_wound text,
  lines_devices text,
  notes text not null,
  nurse_name text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.vital_signs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  observed_at timestamptz not null default now(),
  blood_pressure text,
  pulse_bpm numeric check (pulse_bpm is null or pulse_bpm >= 0),
  respiratory_rate numeric check (respiratory_rate is null or respiratory_rate >= 0),
  spo2_percent numeric check (spo2_percent is null or spo2_percent between 0 and 100),
  temperature_c numeric,
  gcs integer check (gcs is null or gcs between 3 and 15),
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.medication_records (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  medication_name text not null,
  dose text not null,
  route text,
  scheduled_at timestamptz not null,
  administered_at timestamptz,
  status text not null default 'Pending' check (status in ('Administered','Pending','Refused','Withheld','Not given')),
  notes text,
  administered_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.investigations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  test_name text not null,
  invoice_number text,
  status text not null default 'Ordered' check (status in ('Ordered','Collected','Pending','Result available','Reviewed','Cancelled')),
  result_at timestamptz,
  result_text text,
  report_url text,
  follow_up text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.sbar_handovers (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  shift text not null check (shift in ('Morning','Evening','Night')),
  outgoing_nurse text not null,
  incoming_nurse text not null,
  situation text not null,
  background text,
  assessment text not null,
  recommendation text not null,
  outstanding_actions text,
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.care_tasks (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  description text not null,
  due_at timestamptz,
  priority text not null default 'Routine' check (priority in ('Routine','Urgent','Critical')),
  assigned_to text,
  status text not null default 'Open' check (status in ('Open','In progress','Completed','Cancelled')),
  completed_at timestamptz,
  completed_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.discharge_plans (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete restrict,
  status text not null default 'Planning' check (status in ('Planning','Not ready','Awaiting medical decision','Ready for authorized review','Discharged')),
  target_date date,
  medication_reconciliation boolean not null default false,
  patient_education boolean not null default false,
  follow_up_documented boolean not null default false,
  pending_results_handed_over boolean not null default false,
  follow_up_details text,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  table_name text not null,
  record_id uuid,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists patients_ward_bed_idx on public.patients(ward, bed_number);
create index if not exists nursing_patient_time_idx on public.nursing_assessments(patient_id, assessed_at desc);
create index if not exists vitals_patient_time_idx on public.vital_signs(patient_id, observed_at desc);
create index if not exists meds_patient_time_idx on public.medication_records(patient_id, scheduled_at desc);
create index if not exists investigations_patient_time_idx on public.investigations(patient_id, created_at desc);
create index if not exists handovers_patient_time_idx on public.sbar_handovers(patient_id, created_at desc);
create index if not exists tasks_status_due_idx on public.care_tasks(status, due_at);
create index if not exists discharge_patient_time_idx on public.discharge_plans(patient_id, created_at desc);

-- Profile created on sign-up. New accounts are nurses; an administrator must promote approved admins.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, active)
  values (new.id, coalesce(nullif(new.raw_user_meta_data->>'full_name',''), split_part(new.email,'@',1), 'Staff member'), 'nurse', true)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- SECURITY DEFINER helper functions avoid recursive RLS checks on profiles.
create or replace function public.is_active_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true); $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role = 'admin'); $$;

-- Audit trigger records row-level changes. Audit records are visible only to admins.
create or replace function public.write_audit_log()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    insert into public.audit_logs(actor_id,table_name,record_id,action,new_data) values (auth.uid(),tg_table_name,new.id,'INSERT',to_jsonb(new));
    return new;
  elsif (tg_op = 'UPDATE') then
    insert into public.audit_logs(actor_id,table_name,record_id,action,old_data,new_data) values (auth.uid(),tg_table_name,new.id,'UPDATE',to_jsonb(old),to_jsonb(new));
    return new;
  elsif (tg_op = 'DELETE') then
    insert into public.audit_logs(actor_id,table_name,record_id,action,old_data) values (auth.uid(),tg_table_name,old.id,'DELETE',to_jsonb(old));
    return old;
  end if;
  return null;
end;
$$;

-- Updated timestamps for mutable entities.
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists patients_updated_at on public.patients;
create trigger patients_updated_at before update on public.patients for each row execute procedure public.set_updated_at();
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
drop trigger if exists discharge_updated_at on public.discharge_plans;
create trigger discharge_updated_at before update on public.discharge_plans for each row execute procedure public.set_updated_at();

-- RLS must be enabled for every API-exposed table.
alter table public.profiles enable row level security;
alter table public.wards enable row level security;
alter table public.patients enable row level security;
alter table public.nursing_assessments enable row level security;
alter table public.vital_signs enable row level security;
alter table public.medication_records enable row level security;
alter table public.investigations enable row level security;
alter table public.sbar_handovers enable row level security;
alter table public.care_tasks enable row level security;
alter table public.discharge_plans enable row level security;
alter table public.audit_logs enable row level security;

-- Least-privilege grants. Anonymous users have no table access.
revoke all on public.profiles, public.wards, public.patients, public.nursing_assessments, public.vital_signs, public.medication_records, public.investigations, public.sbar_handovers, public.care_tasks, public.discharge_plans, public.audit_logs from anon;
grant select on public.profiles to authenticated;
grant update (full_name, active, role) on public.profiles to authenticated;
grant select, insert, update on public.wards to authenticated;
grant select, insert, update on public.patients to authenticated;
grant select, insert on public.nursing_assessments to authenticated;
grant select, insert on public.vital_signs to authenticated;
grant select, insert, update on public.medication_records to authenticated;
grant select, insert, update on public.investigations to authenticated;
grant select, insert, update on public.sbar_handovers to authenticated;
grant select, insert, update on public.care_tasks to authenticated;
grant select, insert, update on public.discharge_plans to authenticated;
grant select on public.audit_logs to authenticated;
grant usage, select on sequence public.audit_logs_id_seq to authenticated;

-- Profiles: staff may read their own profile; only admins can read/update other profiles.
drop policy if exists profile_self_select on public.profiles;
create policy profile_self_select on public.profiles for select to authenticated using (id = auth.uid() and public.is_active_staff());
drop policy if exists profile_admin_select on public.profiles;
create policy profile_admin_select on public.profiles for select to authenticated using (public.is_admin());
drop policy if exists profile_admin_update on public.profiles;
create policy profile_admin_update on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Active staff can read wards; admins manage them.
drop policy if exists wards_staff_select on public.wards;
create policy wards_staff_select on public.wards for select to authenticated using (public.is_active_staff());
drop policy if exists wards_admin_insert on public.wards;
create policy wards_admin_insert on public.wards for insert to authenticated with check (public.is_admin() and (created_by is null or created_by = auth.uid()));
drop policy if exists wards_admin_update on public.wards;
create policy wards_admin_update on public.wards for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Clinical records: signed-in active staff only. Delete is intentionally not granted for clinical history.
drop policy if exists patients_staff_select on public.patients;
create policy patients_staff_select on public.patients for select to authenticated using (public.is_active_staff());
drop policy if exists patients_staff_insert on public.patients;
create policy patients_staff_insert on public.patients for insert to authenticated with check (public.is_active_staff() and created_by = auth.uid());
drop policy if exists patients_staff_update on public.patients;
create policy patients_staff_update on public.patients for update to authenticated using (public.is_active_staff()) with check (public.is_active_staff());

-- Reusable policies are explicit per table to keep RLS review straightforward.
do $$
declare t text;
begin
  foreach t in array array['nursing_assessments','vital_signs','medication_records','investigations','sbar_handovers','care_tasks','discharge_plans'] loop
    execute format('drop policy if exists %I on public.%I', t || '_staff_select', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_active_staff())', t || '_staff_select', t);
    execute format('drop policy if exists %I on public.%I', t || '_staff_insert', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_active_staff() and created_by = auth.uid())', t || '_staff_insert', t);
    execute format('drop policy if exists %I on public.%I', t || '_staff_update', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_active_staff()) with check (public.is_active_staff())', t || '_staff_update', t);
  end loop;
end $$;

drop policy if exists audit_admin_select on public.audit_logs;
create policy audit_admin_select on public.audit_logs for select to authenticated using (public.is_admin());

-- Install append-only audit triggers on clinical data and profile/ward changes.
do $$
declare t text;
begin
  foreach t in array array['profiles','wards','patients','nursing_assessments','vital_signs','medication_records','investigations','sbar_handovers','care_tasks','discharge_plans'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_audit', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute procedure public.write_audit_log()', t || '_audit', t);
  end loop;
end $$;

-- Seed ward names. Admins can edit them later.
insert into public.wards(name,floor) values
 ('ICU','As configured by hospital'),('Cardiac','As configured by hospital'),('Surgical','As configured by hospital'),('Medical','As configured by hospital')
on conflict (name) do nothing;

-- AFTER the first authorized user signs up and their profile exists, promote them by running:
-- update public.profiles set role = 'admin' where id = 'AUTH-USER-UUID-HERE';
-- Replace the UUID with the intended admin user's id from Authentication > Users.
