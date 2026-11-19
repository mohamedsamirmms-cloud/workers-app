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
