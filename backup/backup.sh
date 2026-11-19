#!/usr/bin/env bash
# عمل نسخة احتياطية مشفّرة: قاعدة البيانات + صور الإقامة + ملفات المعدات
#   backup/backup.sh <اسم الملف بدون امتداد>
# محتاج: SUPABASE_DB_URL و SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY و BACKUP_PASSWORD
# الناتج: <الاسم>.tar.gz.gpg (ميتفتحش غير بالباسورد)
set -euo pipefail

NAME="${1:-backup-$(date -u +%Y-%m-%d)}"
PG_BIN="${PG_BIN:-}"
missing=""
for v in SUPABASE_DB_URL SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY BACKUP_PASSWORD; do
  [ -n "${!v:-}" ] || missing="$missing $v"
done
[ -z "$missing" ] || { echo "❌ ناقص:$missing"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/out"

# نشيل المسافات والسطور الفاضية اللي ممكن تتلزق مع الرابط بالغلط
SUPABASE_DB_URL="$(printf '%s' "$SUPABASE_DB_URL" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
export SUPABASE_DB_URL

# فحص شكل رابط قاعدة البيانات (من غير ما نطبع الباسورد)
python3 - <<'PY'
import os, urllib.parse as u
url = os.environ["SUPABASE_DB_URL"]
scheme, _, rest = url.partition("://")
cred, _, server = rest.rpartition("@")       # آخر @ هو اللي قبل السيرفر
user, _, raw_pw = cred.partition(":")
hostport, _, db = server.partition("/")
host, _, port = hostport.partition(":")
pw = u.unquote(raw_pw)
print("🔎 فحص الرابط:")
print("   البداية:", scheme + "://", "✅" if scheme in ("postgresql", "postgres") else "❌ لازم يبدأ بـ postgresql://")
print("   المستخدم:", user, "✅" if user.startswith("postgres.") else "❌ لازم يبقى postgres.<رقم المشروع>")
print("   السيرفر:", host, "✅" if host.endswith("pooler.supabase.com") else "❌ لازم Session pooler")
print("   البورت:", port, "✅" if port == "5432" else "❌ لازم 5432 (Session pooler)")
print("   قاعدة البيانات:", db, "✅" if db.split("?")[0] == "postgres" else "❌ لازم postgres")
print("   طول الباسورد:", len(pw), "حرف")
if pw.startswith("[") or pw.endswith("]"):
    print("   ❌ الباسورد لسه حواليه أقواس [ ] — شيلهم")
if "YOUR-" in pw.upper():
    print("   ❌ الباسورد لسه مكتوب فيه YOUR-PASSWORD — حط الباسورد الحقيقي")
if pw != pw.strip():
    print("   ❌ فيه مسافة في أول أو آخر الباسورد")
if cred.count("@") or any(c in raw_pw for c in "#/?"):
    print("   ⚠️ الباسورد فيه رموز بتبوّظ الرابط — استخدم حروف وأرقام بس")
PY

echo "🗄️ قاعدة البيانات..."
"${PG_BIN}pg_dump" "$SUPABASE_DB_URL" --schema=public --no-owner --no-privileges -Fc -f "$WORK/out/database.dump"
N=$("${PG_BIN}pg_restore" -l "$WORK/out/database.dump" | grep -c " TABLE DATA public " || true)
echo "   $N جدول"
# لو الجداول الأساسية مش موجودة في النسخة يبقى فيه مشكلة في الاتصال أو الصلاحيات
for t in workers timesheet; do
  "${PG_BIN}pg_restore" -l "$WORK/out/database.dump" | grep -q " TABLE DATA public $t " || { echo "❌ جدول $t مش في النسخة"; exit 1; }
done

echo "🖼️ الصور والملفات..."
node "$(dirname "$0")/storage.mjs" download "$WORK/out/storage"

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$WORK/out/created_at.txt"
tar czf "$WORK/backup.tar.gz" -C "$WORK/out" .
gpg --batch --yes --quiet --pinentry-mode loopback --passphrase "$BACKUP_PASSWORD" \
  --symmetric --cipher-algo AES256 -o "$NAME.tar.gz.gpg" "$WORK/backup.tar.gz"
echo "🔒 $NAME.tar.gz.gpg ($(du -h "$NAME.tar.gz.gpg" | cut -f1))"
