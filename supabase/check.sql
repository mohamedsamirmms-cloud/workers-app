-- =====================================================================
--  فحص: هل التجهيز والأمان اتعملوا؟ شغّله في SQL Editor واقرا الجدول
-- =====================================================================
select item as "البند", case when ok then '✅' else '❌' end as "الحالة" from (values
  (1,  'جدول الوجبات',                    to_regclass('public.meals') is not null),
  (2,  'جدول المعدات',                    to_regclass('public.equipment') is not null),
  (3,  'أعمدة المعدات الجديدة (صورة، أرقام، نوع)', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'equipment' and column_name = 'photo')
                                          and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'equipment' and column_name = 'operator_no')
                                          and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'equipment' and column_name = 'kind')),
  (4,  'مكان تخزين ملفات المعدات',         exists (select 1 from storage.buckets where id = 'equipment')),
  (5,  'أعمدة الأرشيف في الساكنين',         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'workers' and column_name = 'archived')),
  (6,  'جدول المستخدمين',                  to_regclass('public.app_users') is not null),
  (7,  'جدول الإعدادات',                   to_regclass('public.app_settings') is not null),
  (8,  'فيه مدير شغال',                    case when to_regclass('public.app_users') is null then false else
                                            (xpath('/row/c/text()', query_to_xml('select count(*) as c from public.app_users where role = ''مدير'' and active', false, true, '')))[1]::text::int > 0 end),
  (9,  'الأمان: دوال الصلاحيات',            to_regprocedure('public.app_can(text)') is not null),
  (10, 'الأمان: قواعد الجداول',             (select count(*) from pg_policies where schemaname = 'public' and policyname like 'rls\_%') >= 20),
  (11, 'الأمان: القواعد القديمة المفتوحة اتشالت', (select count(*) from pg_policies where schemaname = 'public' and policyname like 'rls\_%') >= 20
                                            and not exists (select 1 from pg_policies where schemaname = 'public'
                                            and tablename in ('workers', 'rooms', 'timesheet', 'meals', 'cars', 'equipment', 'app_users', 'app_settings')
                                            and policyname not like 'rls\_%')),
  (12, 'الأمان: حماية الصلاحيات من التغيير', exists (select 1 from pg_trigger where tgname = 'app_users_guard')),
  (13, 'الأمان: صور الإقامة وملفات المعدات', (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'rls\_%') = 8)
,
  (14, 'تجهيزات الغرف (غاز، سلندر، غسالة، تلاجة)', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'rooms' and column_name = 'fridges')),
  (15, 'تاريخ انتهاء الإقامة في الساكنين',   exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'workers' and column_name = 'iqama_expiry')),
  (16, 'صورة الإقامة والرخصة في السيارات',  exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'cars' and column_name = 'license_file')),
  (17, 'مشرف السيارات يقدر يرفع ملفات',      not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'rls_equip_write')
                                            or exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'rls_equip_write' and with_check like '%cars%')),
  (18, 'منع تكرار رقم الإقامة',              exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'workers_id_no_unique')),
  (19, 'فطار المجموعات (جدولين)',            to_regclass('public.meal_groups') is not null and to_regclass('public.group_meals') is not null),
  (20, 'فطار المجموعات: الأمان',             (select count(*) from pg_policies where schemaname = 'public' and tablename in ('meal_groups', 'group_meals') and policyname like 'rls\_%') = 4),
  (21, 'أسماء مجموعات الفطار',              to_regclass('public.meal_group_members') is not null),
  (22, 'عدد الأسرّة في الوحدات',             exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'rooms' and column_name = 'beds'))
) as t(n, item, ok)
order by n;
