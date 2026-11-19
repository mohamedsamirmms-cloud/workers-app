-- =====================================================================
--  تجهيز قاعدة البيانات لكل صفحات البرنامج (شغّله مرة واحدة)
--  آمن لو اتشغّل أكتر من مرة، ولو فيه جداول متعملة قبل كده مش هيمسحها.
--  بعده: ادخل البرنامج، وبعدين شغّل security.sql
-- =====================================================================

-- 1) الوجبات
create table if not exists public.meals (
  id bigint generated always as identity primary key,
  worker_id bigint,
  meal_date date not null,
  breakfast boolean default false,
  lunch boolean default false,
  unique (worker_id, meal_date)
);
alter table public.meals enable row level security;
drop policy if exists "logged in users" on public.meals;
create policy "logged in users" on public.meals for all to authenticated using (true) with check (true);

-- 2) معدات المشروع
create table if not exists public.equipment (
  id bigint generated always as identity primary key,
  name text not null,
  driver text,
  other_files jsonb default '[]'
);
alter table public.equipment
  add column if not exists iqama_no text,           add column if not exists iqama_file text,
  add column if not exists license_no text,         add column if not exists license_file text,
  add column if not exists reg_expiry date,         add column if not exists reg_file text,
  add column if not exists ins_expiry date,         add column if not exists ins_file text,
  add column if not exists inspection_expiry date,  add column if not exists inspection_file text,
  add column if not exists operator_no text,        add column if not exists operator_file text,
  add column if not exists photo text;
alter table public.equipment enable row level security;
drop policy if exists "logged in users" on public.equipment;
create policy "logged in users" on public.equipment for all to authenticated using (true) with check (true);

-- مكان تخزين ملفات وصور المعدات
insert into storage.buckets (id, name, public) values ('equipment', 'equipment', false)
  on conflict (id) do nothing;
drop policy if exists "equipment files" on storage.objects;
create policy "equipment files" on storage.objects for all to authenticated
  using (bucket_id = 'equipment') with check (bucket_id = 'equipment');

-- 3) الأرشيف (أعمدة جديدة في جدول الساكنين)
alter table public.workers
  add column if not exists archived boolean default false,
  add column if not exists archived_at date,
  add column if not exists archive_reason text,
  add column if not exists archive_note text;

-- 4) المستخدمين
create table if not exists public.app_users (
  id bigint generated always as identity primary key,
  email text unique not null,
  name text,
  role text default 'مشاهد',
  pages text[] default '{}',
  active boolean default true,
  last_login timestamptz,
  created_at timestamptz default now()
);
alter table public.app_users enable row level security;
drop policy if exists "logged in users" on public.app_users;
create policy "logged in users" on public.app_users for all to authenticated using (true) with check (true);

-- 5) الإعدادات
create table if not exists public.app_settings (key text primary key, value jsonb);
alter table public.app_settings enable row level security;
drop policy if exists "logged in users" on public.app_settings;
create policy "logged in users" on public.app_settings for all to authenticated using (true) with check (true);
