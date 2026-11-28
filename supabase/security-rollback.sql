-- =====================================================================
--  رجوع: بيشيل قواعد الأمان ويرجّع كل الجداول مفتوحة لأي حد عامل
--  تسجيل دخول (زي ما كانت قبل security.sql).
--  استخدمه بس لو حصلت مشكلة بعد تشغيل security.sql.
-- =====================================================================

do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('workers', 'rooms', 'timesheet', 'meals', 'cars', 'equipment', 'app_users', 'app_settings', 'meal_groups', 'group_meals', 'meal_group_members', 'purchases', 'equipment_log', 'maintenance', 'ts_groups', 'ts_group_members')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
  for r in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname like 'rls\_%'
  loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
end $$;

drop trigger if exists app_users_guard on public.app_users;
drop policy if exists "iqama files" on storage.objects;
drop policy if exists "equipment files" on storage.objects;

create policy "logged in users" on public.workers      for all to authenticated using (true) with check (true);
create policy "logged in users" on public.rooms        for all to authenticated using (true) with check (true);
create policy "logged in users" on public.timesheet    for all to authenticated using (true) with check (true);
create policy "logged in users" on public.meals        for all to authenticated using (true) with check (true);
create policy "logged in users" on public.cars         for all to authenticated using (true) with check (true);
create policy "logged in users" on public.equipment    for all to authenticated using (true) with check (true);
create policy "logged in users" on public.app_users    for all to authenticated using (true) with check (true);
create policy "logged in users" on public.app_settings for all to authenticated using (true) with check (true);
do $$ begin
  if to_regclass('public.meal_groups') is not null then
    create policy "logged in users" on public.meal_groups for all to authenticated using (true) with check (true);
    create policy "logged in users" on public.group_meals for all to authenticated using (true) with check (true);
  end if;
  if to_regclass('public.meal_group_members') is not null then
    create policy "logged in users" on public.meal_group_members for all to authenticated using (true) with check (true);
  end if;
  if to_regclass('public.purchases') is not null then
    create policy "logged in users" on public.purchases for all to authenticated using (true) with check (true);
  end if;
  if to_regclass('public.equipment_log') is not null then
    create policy "logged in users" on public.equipment_log for all to authenticated using (true) with check (true);
  end if;
  if to_regclass('public.maintenance') is not null then
    create policy "logged in users" on public.maintenance for all to authenticated using (true) with check (true);
  end if;
  if to_regclass('public.ts_groups') is not null then
    create policy "logged in users" on public.ts_groups for all to authenticated using (true) with check (true);
    create policy "logged in users" on public.ts_group_members for all to authenticated using (true) with check (true);
  end if;
end $$;

create policy "iqama files" on storage.objects for all to authenticated
  using (bucket_id = 'iqama') with check (bucket_id = 'iqama');
create policy "equipment files" on storage.objects for all to authenticated
  using (bucket_id = 'equipment') with check (bucket_id = 'equipment');
