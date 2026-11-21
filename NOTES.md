# 📒 ملاحظات المشروع — سجل السكن

ملخص كامل للبرنامج عشان أي محادثة جديدة تفهمه بسرعة.
**في أي محادثة جديدة: "اقرا NOTES.md الأول".**

---

## 1. البرنامج في سطور

- برنامج ويب لإدارة **سكن العمال والمشروع**: الساكنين، الوجبات، التايم شيت، معدات وسيارات المشروع، الأرشيف، التقارير، المستخدمين والصلاحيات، والإعدادات.
- **الكود كله في ملف واحد:** `index.html` (حوالي 4700 سطر: CSS + HTML + JavaScript، من غير build).
- **الواجهة:** عربي (لهجة مصرية في الرسايل)، `dir="rtl"`، ومظبوطة للموبايل.
- **الاستضافة:** GitHub Pages من فرع `main` ← `https://mohamedsamirmms-cloud.github.io/workers-app/`
- **قاعدة البيانات والدخول والملفات:** Supabase (مشروع `workers-housing`، ref `xbckfzqifaywhrpuqkyo`، منطقة `ap-southeast-2`). المفتاح اللي في `index.html` هو الـ publishable key (عادي يبقى ظاهر).
- **المكتبات (CDN):** supabase-js 2.45.4، tesseract.js 5.1.1 (قراءة الصور)، xlsx 0.18.5 (Excel)، pdf.js 3.11.174 (بيتحمّل وقت الحاجة بس).

## 2. طريقة الشغل مع صاحب المشروع

- صاحب المشروع بيتكلم **مصري**، ومش مبرمج: الشرح يبقى خطوة بخطوة، ومن غير مصطلحات.
- **موافق إن التعديلات تترفع على `main` على طول** بعد التجربة (من غير ما نسأله كل مرة).
- قبل أي رفع: جرّب في المتصفح (Playwright بـ Supabase وهمي) وصوّر الشاشة على الكمبيوتر **والموبايل (390px)**، واتأكد إن مفيش scroll بالعرض.
- أي تغيير في قاعدة البيانات: إدّيله سطر SQL صغير يشغّله في **Supabase ← SQL Editor**، وحدّث `supabase/setup.sql` و `supabase/check.sql`.
- **متطلبش منه أسرار في الشات أبدًا** (باسوردات، مفاتيح). الأسرار بتتحط في GitHub Secrets بس.

## 3. الصفحات (`showPage(name)`)

| المفتاح | الصفحة | أهم الدوال |
|---|---|---|
| `dashboard` | لوحة التحكم: 5 مربعات بتفتح تفاصيل (ساكنين، حضور النهارده، وجبات، معدات، سيارات) + تنبيهات المستندات | `refreshDashboard`, `renderDashDocs`, `loadDashAtt`, `loadDashMeals`, `toggleDash` |
| `residents` | الساكنين: كروت بتفلتر، تابات المساكن، مربعات الغرف، **بيانات الوحدة** (غرف/حمامات/مطبخ/غاز/سلندر/غسالة/تلاجة)، جدول، إضافة/تعديل/أرشفة/حذف | `showWorkers`, `showRooms`, `showRoomInfo`, `saveRoomInfo`, `openBuilding`, `dashOpen` |
| `meals` | الوجبات: يومي (فطار/غداء لكل عامل) + حساب شهري | `showMeals`, `toggleMeal`, `mealAll`, `showMealMonth`, `exportMealMonth` |
| `timesheet` | التايم شيت: يومي + **كشف شهري لكل عامل** (تقويم/جدول) + **كشف شهري لكل العمال** (ملخص/بالأيام) | `showTimesheet`, `markPresent`, `saveTime`, `openTsMonth`, `showTsMonth`, `openTsAll`, `loadTsAll`, `exportTsAll` |
| `moves` | **معدات المشروع** (الاسم القديم في الكود `moves`): مستندات بأرقام وتواريخ ومرفقات، صورة لكل معدة، **رسومات لأنواع المعدات** (16 نوع بتتعرف من الاسم)، قراءة PDF/صورة تلقائيًا | `showEquipment`, `openEq`, `readEqFile`, `parseEqText`, `EQ_DOCS`, `EQ_KINDS`, `detectKind` |
| `cars` | سيارات المشروع: استمارة وتأمين وصيانة وعداد | `showCars`, `openCar`, `exportCars` |
| `archive` | الأرشيف: الساكنين اللي سابوا السكن (سبب + تاريخ + ملاحظة)، رجوع للسكن | `openArchive`, `restoreWorker`, `showArchive` |
| `reports` | 6 تقارير بشهر: ملخص شهري، السكن، الحضور، الوجبات، المستندات، حركة الساكنين + طباعة + Excel | `openReport`, `repMonthData`, `exportReport` |
| `users` | المستخدمين والصلاحيات (للمدير بس) | `loadMe`, `applyPermissions`, `showUsers`, `openUser` |
| `settings` | الإعدادات + نسخة Excel كاملة | `loadSettings`, `applySettings`, `saveSettings`, `fullBackup` |

**حاجات عامة:**
- **الملف الشامل للعامل** (`showProfile`): صورة الإقامة (رفع/تغيير)، البيانات، حضور ووجبات الشهر، المعدات والسيارات اللي بيسوقها، طباعة.
- **الملف الشامل للمعدة** (`showEqProfile`) **وللسيارة** (`showCarProfile`): في نفس نافذة ملف الساكن (`#profileBox`). البيانات، الصورة أو رسمة النوع، كل مستند بحالته وأيامه ومرفقه، والسائق لينك لملفه (`driverWorker`)، وتعديل (لو ليه الصفحة) وطباعة. بيتفتح من زرار "👁️ الملف" أو الاسم في القايمة، ومن تنبيهات لوحة التحكم، ومن ملف الساكن.
- **صورة إقامة ورخصة السائق** في ملف المعدة والسيارة (`pfIdsHtml`, `pickPfDoc`, `uploadPfDoc`): بتظهر الصورة نفسها (والـ PDF لينك)، وفيه زرارين صوّر وارفع. ولو مفيش صورة إقامة والسائق ساكن، بتظهر صورته من ملف الساكن. للمعدات بتستخدم `iqama_file`/`license_file` الموجودين من قبل.
- **منع تكرار رقم الإقامة** (`normIqama`, `iqamaOwner`, `showDupMsg`, `dupIqamaIds`): الرقم بيتوحّد (أرقام عربي ← إنجليزي، ومن غير مسافات). في الإضافة والتعديل بتظهر رسالة وانت بتكتب، والحفظ بيتمنع. لو الرقم لساكن في الأرشيف، بيقترح "رجّعه للسكن". ولو فيه أرقام متكررة قديمة، بيظهر مربع "⛔ رقم إقامة متكرر" (فلتر `dup`). وفي قاعدة البيانات فيه unique index اسمه `workers_id_no_unique` على `trim(id_no::text)` (الفاضي مسموح يتكرر).
- **دمج السجلات المتكررة** (`openMerge`, `doMerge`): في فلتر `dup` فيه لوحة `#dupPanel` بكل الأرقام المتكررة (حتى اللي في الأرشيف) وزرار "🔗 دمج". الزرار بيظهر بس للي عنده residents وtimesheet وmeals. الدمج بينقل التايم شيت (لو نفس اليوم في الاتنين، بيفضل اللي ساعاته أكتر) والوجبات (لو نفس اليوم، بيجمعهم)، ويكمّل البيانات الناقصة، وبعدين يمسح السجل المتكرر. لما صاحب المشروع شغّل الفحص، طلع عنده 13 رقم متكرر وكلهم نفس الشخص متسجّل مرتين.
- **حسابي** (`openAccount`, `saveMyAccount`): زرار "👤 حسابي" تحت في القائمة (ودوس على الاسم كمان) — نافذة لأي مستخدم مهما كانت صلاحياته يغيّر اسمه وباسورده.
- **انتهاء الإقامة** (`iqama_expiry`): في الإضافة والتعديل، علامة ملوّنة جنب رقم الإقامة، مربع "⏳ إقامة منتهية أو قربت" (فلتر `iqama`)، في تنبيهات لوحة التحكم (لو ليه صفحة الساكنين) وتقرير المستندات والملف الشامل. `hasIqamaExp` بيتأكد إن العمود موجود قبل ما يبعته.
- **القائمة الجانبية** بتتضم لأيقونات (`toggleSidebar`، بتتحفظ في `localStorage`)، والصفحة تاخد عرض الشاشة.
- **الطباعة:** `printWith('print-profile' | 'print-report')`.
- العمال: `workers` (النشطين) و `archivedWorkers`، ودوّر بـ `findWorker(id)`. و`onDuty(w, date)` = كان في السكن اليوم ده (بعد القدوم وقبل الأرشفة) وبيُستخدم في حساب الغياب.

## 4. قاعدة البيانات (Supabase)

| الجدول | الأعمدة المهمة |
|---|---|
| `workers` | `id, name, id_no, iqama_expiry, country, job, sponsor, building, room, bed_no, arrival, blanket ('نعم'/'لا'), iqama_img, archived, archived_at, archive_reason, archive_note` |
| `rooms` | المفتاح `(building, room)`: `bedrooms, bathrooms, kitchen, gas, cylinders, washers, fridges` |
| `timesheet` | `worker_id, work_date, time_in, time_out, hours, overtime` (unique على `worker_id, work_date`) |
| `meals` | `id, worker_id, meal_date, breakfast, lunch` (unique على `worker_id, meal_date`) |
| `cars` | `id, plate, car_type, model, driver, reg_expiry, ins_expiry, last_service, km, notes, iqama_file, license_file` |
| `equipment` | `id, name, driver, kind, photo, iqama_no, license_no, operator_no, reg_expiry, ins_expiry, inspection_expiry, *_file, other_files (jsonb)` |
| `app_users` | `id, email, name, role, pages (text[]), active, last_login, created_at` |
| `app_settings` | `key='main'`, `value` jsonb: `name, sub, breakfast, lunch, hours, timeIn, warnDays, countries[], sponsors[]` |

**التخزين (Storage buckets، خاصة):** `iqama` (صور الإقامة)، `equipment` (صور وملفات المعدات، وصور إقامة ورخصة سواقين السيارات وأسماءها بتبدأ بـ `car_`). الكتابة في `equipment` مسموحة لصفحة `moves` أو `cars`. بنفتحها بروابط مؤقتة (`createSignedUrl(s)`).

**ملفات SQL في `supabase/`:**
- `setup.sql`: بيعمل/يكمّل كل الجداول والأعمدة. آمن يتشغّل كذا مرة، ومش بيفتح القواعد لو الأمان متشغّل.
- `security.sql`: قواعد RLS (شوف 5).
- `security-rollback.sql`: يرجّع كل حاجة مفتوحة لو حصلت مشكلة.
- `check.sql`: جدول ✅/❌ (18 بند) يأكد إن كله متجهز.
- **الحالة الحالية:** صاحب المشروع شغّل كل الأكواد، وكل البنود لحد 17 ✅. بند 18 (منع التكرار) محتاج: يصلّح الأرقام المتكررة لو فيه، وبعدين يشغّل سطر الـ index.

## 5. الصلاحيات والأمان

- **الأدوار** (`ROLES` في الكود): مدير (كل حاجة)، مشرف سكن، مشرف مشروع، مدخل بيانات، مشاهد. كل مستخدم ليه `pages[]`، والمدير ممكن يغيّرها.
- **في البرنامج:** القائمة ومربعات لوحة التحكم بتظهر حسب الصفحات (`myPages`, `canOpen`). أول حد يدخل والجدول فاضي بيبقى مدير، والبرنامج بيسأل السيرفر بـ `rpc('app_users_empty')`.
- **في قاعدة البيانات (`security.sql`):** دوال `app_email()`, `app_active()`, `app_is_admin()`, `app_can(page)`, `app_users_empty()`.
  - القراءة: أي مستخدم متسجّل وشغال.
  - الكتابة حسب الصفحة: `workers` ← residents/archive، `rooms` ← residents، `timesheet` ← timesheet، `meals` ← meals، `cars` ← cars، `equipment` ← moves، `app_settings` ← settings، `app_users` ← المدير (والشخص يعدّل اسمه بس).
  - Trigger `app_users_guard` بيمنع غير المدير يغيّر الصلاحيات (التعديل من SQL Editor مسموح للتصليح).
  - الزوار (anon) ملهمش أي صلاحية.
- اتجرّب على PostgreSQL محلي (60 اختبار).

## 6. النسخ الاحتياطي

- **GitHub Actions** `.github/workflows/backup.yml`: كل يوم **3:17 الفجر بتوقيت السعودية** (`17 0 * * *` UTC) + زرار يدوي.
  - `backup/backup.sh`: `pg_dump` لـ schema `public` + تنزيل الـ buckets بـ `backup/storage.mjs` + tar + تشفير **gpg AES256** بـ `BACKUP_PASSWORD`.
  - بيتحفظ Artifact لمدة **90 يوم**. **الريبو عام، فالتشفير إجباري.**
  - فيه فحص لشكل رابط قاعدة البيانات من غير ما الباسورد يظهر.
- **الاسترجاع:** `.github/workflows/restore.yml` (يدوي: `run_id` + كتابة `RESTORE`) ← `backup/restore.sh`. بيمسح ويرجّع في transaction واحدة، ويشتغل على مشروع جديد فاضي.
- **Secrets (في GitHub):** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (legacy service_role), `SUPABASE_DB_URL` (Session pooler، بورت 5432، يوزر `postgres.<ref>`), `BACKUP_PASSWORD`.
- **الحالة:** شغال ✅، وصاحب المشروع فتح النسخة بالباسورد، وبيرفع نسخة شهرية على Google Drive.
- الشرح بالتفصيل: `backup/README.md`.

## 7. أسلوب الكود

- CSS في أول الملف، مجمّع بتعليقات عربي (`/* الوجبات */` …). الألوان: كحلي `#1e3a5f`، برتقالي `#e08a1e`، أخضر `#16a34a`، أحمر `#c0392b`.
- مكونات بتتكرر: `.stat` (كروت أرقام، ومعاها `.click` و`.on`)، `.chip` (فلاتر)، `.res-head`، `.res-panel`، `.icon-btns`، `.badge ok/bad/warn/miss`، `.tsm-head` (رأس النوافذ).
- **الموبايل:** `@media (max-width: 700px)` الجداول بتتحول لكروت (grid)، و`800px` للقائمة. استخدم `box-sizing: border-box` جوه الصفحات.
- التواريخ `YYYY-MM-DD` بـ `toLocaleDateString("en-CA")`، والعرض بالعربي بـ `"ar-EG"`.
- `fetchAll(() => query)` بيجيب أكتر من 1000 صف على دفعات (لازم `order`).
- `expiryBadge(date)` و `expiryState(date)` بيستخدموا `WARN_DAYS` من الإعدادات.

## 8. معلّق / أفكار جاية

**صغير ومعلّق:**
- فرعين قديمين على GitHub ملهمش لازمة: `add-meals-page` و `meals-total-row`.

**أفكار اقترحناها (بالأولوية):**
1. انتهاء الجواز والرخصة لكل ساكن (الإقامة اتعملت ✅).
2. سجل التعديلات (مين عمل إيه وإمتى).
3. الأسرّة الفاضية لكل وحدة.
4. زرار "وجبات للحاضرين" (ربط الوجبات بالتايم شيت).
5. إيميل تنبيهات كل صباح.
6. يشتغل من غير نت (PWA + تسجيل حضور ووجبات offline ويترفعوا بعدين).
