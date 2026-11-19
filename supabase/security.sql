-- =====================================================================
--  قواعد الأمان (RLS) لبرنامج سجل السكن
--  بتخلّي قاعدة البيانات نفسها تمنع كل مستخدم من الجداول اللي ملهاش
--  دعوة بصلاحيته، حتى لو حد حاول يوصل للبيانات من برّه البرنامج.
--
--  قبل ما تشغّله:
--    1) لازم يكون جدول app_users متعمل، وإنت دخلت البرنامج مرة على الأقل
--       (عشان تتسجّل "مدير"). الكود هيرفض يكمّل لو مفيش مدير شغال.
--    2) شغّله كله مرة واحدة في Supabase ← SQL Editor.
--  لو حصلت أي مشكلة شغّل security-rollback.sql يرجّع كل حاجة زي ما كانت.
-- =====================================================================

-- ---------- 0) أمان: لازم يكون فيه مدير شغال ----------
do $$
begin
  if not exists (select 1 from public.app_users where role = 'مدير' and active) then
    raise exception 'مفيش مدير شغال في app_users. ادخل البرنامج الأول عشان تتسجّل مدير، وبعدين شغّل الكود ده تاني.';
  end if;
end $$;

-- جدول الإعدادات (لو لسه متعملش)
create table if not exists public.app_settings (key text primary key, value jsonb);

-- ---------- 1) دوال الصلاحيات ----------
-- إيميل اللي داخل دلوقتي
create or replace function public.app_email() returns text
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- هل المستخدم متسجّل وحسابه شغال؟
create or replace function public.app_active() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from app_users u where lower(u.email) = app_email() and u.active)
$$;

-- هل المستخدم مدير؟
create or replace function public.app_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from app_users u where lower(u.email) = app_email() and u.active and u.role = 'مدير')
$$;

-- هل المستخدم يقدر يفتح صفحة معيّنة؟ (المدير يفتح كل حاجة)
create or replace function public.app_can(page text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from app_users u
    where lower(u.email) = app_email() and u.active
      and (u.role = 'مدير' or page = any(u.pages))
  )
$$;

-- جدول المستخدمين فاضي؟ (عشان أول حد يدخل يبقى مدير)
create or replace function public.app_users_empty() returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from app_users)
$$;

grant execute on function public.app_email(), public.app_active(), public.app_is_admin(),
  public.app_can(text), public.app_users_empty() to authenticated;

-- ---------- 2) نشيل القواعد القديمة المفتوحة ----------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('workers', 'rooms', 'timesheet', 'meals', 'cars', 'equipment', 'app_users', 'app_settings')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;

  -- قواعد التخزين الخاصة بصور الإقامة وملفات المعدات بس
  for r in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(qual, '') ~ '(iqama|equipment)' or coalesce(with_check, '') ~ '(iqama|equipment)')
  loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
end $$;

-- ---------- 3) نشغّل RLS على كل الجداول ----------
alter table public.workers      enable row level security;
alter table public.rooms        enable row level security;
alter table public.timesheet    enable row level security;
alter table public.meals        enable row level security;
alter table public.cars         enable row level security;
alter table public.equipment    enable row level security;
alter table public.app_users    enable row level security;
alter table public.app_settings enable row level security;

-- ---------- 4) القواعد الجديدة ----------
-- القراءة: أي مستخدم متسجّل وشغال (لوحة التحكم والتقارير والملف بيقروا من كذا جدول)
-- التعديل: حسب الصفحة المسموحة

-- الساكنين: يعدّل فيهم صفحة الساكنين أو الأرشيف
create policy rls_read  on public.workers for select to authenticated using (app_active());
create policy rls_write on public.workers for insert to authenticated with check (app_can('residents'));
create policy rls_edit  on public.workers for update to authenticated using (app_can('residents') or app_can('archive')) with check (app_can('residents') or app_can('archive'));
create policy rls_del   on public.workers for delete to authenticated using (app_can('residents') or app_can('archive'));

-- بيانات الغرف
create policy rls_read  on public.rooms for select to authenticated using (app_active());
create policy rls_write on public.rooms for all    to authenticated using (app_can('residents')) with check (app_can('residents'));

-- التايم شيت
create policy rls_read  on public.timesheet for select to authenticated using (app_active());
create policy rls_write on public.timesheet for all    to authenticated using (app_can('timesheet')) with check (app_can('timesheet'));

-- الوجبات
create policy rls_read  on public.meals for select to authenticated using (app_active());
create policy rls_write on public.meals for all    to authenticated using (app_can('meals')) with check (app_can('meals'));

-- السيارات
create policy rls_read  on public.cars for select to authenticated using (app_active());
create policy rls_write on public.cars for all    to authenticated using (app_can('cars')) with check (app_can('cars'));

-- المعدات
create policy rls_read  on public.equipment for select to authenticated using (app_active());
create policy rls_write on public.equipment for all    to authenticated using (app_can('moves')) with check (app_can('moves'));

-- الإعدادات: الكل يقرا (الأسعار وساعات اليوم)، واللي معاه صفحة الإعدادات يعدّل
create policy rls_read  on public.app_settings for select to authenticated using (app_active());
create policy rls_write on public.app_settings for all    to authenticated using (app_can('settings')) with check (app_can('settings'));

-- المستخدمين: كل واحد يشوف نفسه، والمدير يشوف الكل
create policy rls_read  on public.app_users for select to authenticated
  using (lower(email) = app_email() or app_is_admin());
-- الإضافة: المدير، أو أول حد يدخل لما الجدول فاضي (ويسجّل نفسه بس)
create policy rls_write on public.app_users for insert to authenticated
  with check (app_is_admin() or (app_users_empty() and lower(email) = app_email() and role = 'مدير'));
-- التعديل: المدير، أو الشخص نفسه (اسمه وآخر دخول بس — شوف الـ trigger تحت)
create policy rls_edit  on public.app_users for update to authenticated
  using (app_is_admin() or lower(email) = app_email())
  with check (app_is_admin() or lower(email) = app_email());
create policy rls_del   on public.app_users for delete to authenticated using (app_is_admin());

-- مستخدم عادي ميقدرش يغيّر صلاحيته أو صفحاته أو يشغّل حسابه بنفسه
create or replace function public.app_users_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not app_is_admin() then
    if new.role is distinct from old.role or new.pages is distinct from old.pages
       or new.active is distinct from old.active or lower(new.email) is distinct from lower(old.email) then
      raise exception 'مش مسموح: الصلاحيات بيغيّرها المدير بس';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists app_users_guard on public.app_users;
create trigger app_users_guard before update on public.app_users
  for each row execute function public.app_users_guard();

-- ---------- 5) التخزين (صور الإقامة وملفات المعدات) ----------
create policy rls_iqama_read  on storage.objects for select to authenticated
  using (bucket_id = 'iqama' and app_active());
create policy rls_iqama_write on storage.objects for insert to authenticated
  with check (bucket_id = 'iqama' and (app_can('residents') or app_can('archive')));
create policy rls_iqama_edit  on storage.objects for update to authenticated
  using (bucket_id = 'iqama' and (app_can('residents') or app_can('archive')));
create policy rls_iqama_del   on storage.objects for delete to authenticated
  using (bucket_id = 'iqama' and (app_can('residents') or app_can('archive')));

create policy rls_equip_read  on storage.objects for select to authenticated
  using (bucket_id = 'equipment' and app_active());
create policy rls_equip_write on storage.objects for insert to authenticated
  with check (bucket_id = 'equipment' and app_can('moves'));
create policy rls_equip_edit  on storage.objects for update to authenticated
  using (bucket_id = 'equipment' and app_can('moves'));
create policy rls_equip_del   on storage.objects for delete to authenticated
  using (bucket_id = 'equipment' and app_can('moves'));

-- ---------- 6) الزوار من غير تسجيل دخول مايشوفوش أي حاجة ----------
revoke all on public.workers, public.rooms, public.timesheet, public.meals, public.cars,
  public.equipment, public.app_users, public.app_settings from anon;
