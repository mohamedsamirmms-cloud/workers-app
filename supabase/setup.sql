-- =====================================================================
--  تجهيز قاعدة البيانات لكل صفحات البرنامج (شغّله مرة واحدة)
--  آمن لو اتشغّل أكتر من مرة، ولو فيه جداول متعملة قبل كده مش هيمسحها،
--  ولو قواعد الأمان (security.sql) متشغلة مش بيلمسها.
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
do $$ begin
  -- القاعدة المفتوحة بس لو قواعد الأمان (security.sql) لسه متشغلتش
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'meals' and policyname like 'rls\_%') then
    drop policy if exists "logged in users" on public.meals;
    create policy "logged in users" on public.meals for all to authenticated using (true) with check (true);
  end if;
end $$;

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
  add column if not exists photo text,
  add column if not exists kind text;
alter table public.equipment enable row level security;
do $$ begin
  -- القاعدة المفتوحة بس لو قواعد الأمان (security.sql) لسه متشغلتش
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'equipment' and policyname like 'rls\_%') then
    drop policy if exists "logged in users" on public.equipment;
    create policy "logged in users" on public.equipment for all to authenticated using (true) with check (true);
  end if;
end $$;

-- مكان تخزين ملفات وصور المعدات
insert into storage.buckets (id, name, public) values ('equipment', 'equipment', false)
  on conflict (id) do nothing;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'rls\_equip%') then
    drop policy if exists "equipment files" on storage.objects;
    create policy "equipment files" on storage.objects for all to authenticated
      using (bucket_id = 'equipment') with check (bucket_id = 'equipment');
  end if;
end $$;

-- 3) الأرشيف (أعمدة جديدة في جدول الساكنين)
alter table public.workers
  add column if not exists archived boolean default false,
  add column if not exists archived_at date,
  add column if not exists archive_reason text,
  add column if not exists archive_note text;

-- 3أ) تاريخ انتهاء الإقامة لكل ساكن (للتنبيهات)
alter table public.workers
  add column if not exists iqama_expiry date;

-- 3ب2) منع تكرار رقم الإقامة (الفاضي مسموح يتكرر)
-- بيتعمل بس لو مفيش أرقام متكررة دلوقتي — لو فيه، صلّحها من البرنامج (مربع "رقم إقامة متكرر") وشغّل الملف تاني
do $$
begin
  if not exists (select 1 from public.workers where coalesce(trim(id_no::text), '') <> '' group by trim(id_no::text) having count(*) > 1) then
    create unique index if not exists workers_id_no_unique on public.workers ((trim(id_no::text))) where coalesce(trim(id_no::text), '') <> '';
  end if;
end $$;

-- 3ج) صورة إقامة ورخصة السواق في السيارات (الملفات بتتحفظ في bucket المعدات)
alter table if exists public.cars
  add column if not exists iqama_file text,
  add column if not exists license_file text;

-- 3ب) تجهيزات الغرف: غاز وسلندرات وغسالات وتلاجات
alter table if exists public.rooms
  add column if not exists gas boolean default false,
  add column if not exists cylinders int default 0,
  add column if not exists washers int default 0,
  add column if not exists fridges int default 0;

-- 3ب1) عدد الأسرّة في كل وحدة (عشان نعرف الفاضي)
alter table if exists public.rooms
  add column if not exists beds int;

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
do $$ begin
  -- القاعدة المفتوحة بس لو قواعد الأمان (security.sql) لسه متشغلتش
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'app_users' and policyname like 'rls\_%') then
    drop policy if exists "logged in users" on public.app_users;
    create policy "logged in users" on public.app_users for all to authenticated using (true) with check (true);
  end if;
end $$;

-- 5) الإعدادات
create table if not exists public.app_settings (key text primary key, value jsonb);
alter table public.app_settings enable row level security;
do $$ begin
  -- القاعدة المفتوحة بس لو قواعد الأمان (security.sql) لسه متشغلتش
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'app_settings' and policyname like 'rls\_%') then
    drop policy if exists "logged in users" on public.app_settings;
    create policy "logged in users" on public.app_settings for all to authenticated using (true) with check (true);
  end if;
end $$;

-- 6) فطار المجموعات: كل مجموعة ليها اسم وعدد وسعر للفرد، وتكلفة كل يوم
create table if not exists public.meal_groups (
  id bigint generated always as identity primary key,
  name text not null unique,
  people int default 0,
  price numeric default 3.5,
  sort int default 0,
  active boolean default true,
  created_at timestamptz default now()
);
create table if not exists public.group_meals (
  group_id bigint not null references public.meal_groups (id) on delete cascade,
  meal_date date not null,
  people numeric,
  amount numeric not null default 0,
  primary key (group_id, meal_date)
);
alter table public.meal_groups enable row level security;
alter table public.group_meals enable row level security;
do $$
declare t text;
begin
  foreach t in array array['meal_groups', 'group_meals'] loop
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = t) then
      if to_regprocedure('public.app_can(text)') is not null then
        -- الأمان متشغّل: القراءة لأي حد شغال، والتعديل لصفحة الوجبات
        execute format('create policy rls_read on public.%I for select to authenticated using (app_active())', t);
        execute format('create policy rls_write on public.%I for all to authenticated using (app_can(''meals'')) with check (app_can(''meals''))', t);
      else
        execute format('create policy "logged in users" on public.%I for all to authenticated using (true) with check (true)', t);
      end if;
    end if;
  end loop;
end $$;
revoke all on public.meal_groups, public.group_meals from anon;

-- 7) أسماء الأفراد جوه كل مجموعة فطار (ساكن أو أي اسم)
create table if not exists public.meal_group_members (
  id bigint generated always as identity primary key,
  group_id bigint not null references public.meal_groups (id) on delete cascade,
  worker_id bigint unique references public.workers (id) on delete set null,
  name text,
  created_at timestamptz default now()
);
alter table public.meal_group_members enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'meal_group_members') then
    if to_regprocedure('public.app_can(text)') is not null then
      create policy rls_read  on public.meal_group_members for select to authenticated using (app_active());
      create policy rls_write on public.meal_group_members for all    to authenticated using (app_can('meals')) with check (app_can('meals'));
    else
      create policy "logged in users" on public.meal_group_members for all to authenticated using (true) with check (true);
    end if;
  end if;
end $$;
revoke all on public.meal_group_members from anon;

