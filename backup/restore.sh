#!/usr/bin/env bash
# استرجاع نسخة احتياطية
#   backup/restore.sh <ملف.tar.gz.gpg>
# محتاج: SUPABASE_DB_URL و SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY و BACKUP_PASSWORD
# - لو جداول البرنامج موجودة: بيمسح بياناتها ويحط بيانات النسخة (كله في خطوة واحدة؛ لو فشل مفيش حاجة بتتغير)
# - لو مشروع جديد فاضي: بيعمل الجداول الأول وبعدين البيانات
set -euo pipefail

FILE="${1:?اكتب اسم ملف النسخة}"
PG_BIN="${PG_BIN:-}"
PSQL="${PG_BIN}psql"; PG_RESTORE="${PG_BIN}pg_restore"
for v in SUPABASE_DB_URL BACKUP_PASSWORD; do
  [ -n "${!v:-}" ] || { echo "❌ ناقص $v"; exit 1; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "🔓 فك التشفير..."
gpg --batch --yes --quiet --pinentry-mode loopback --passphrase "$BACKUP_PASSWORD" -d -o "$WORK/backup.tar.gz" "$FILE"
tar xzf "$WORK/backup.tar.gz" -C "$WORK"
DUMP="$WORK/database.dump"
[ -f "$DUMP" ] || { echo "❌ الملف مافيهوش database.dump"; exit 1; }

# الجداول اللي في النسخة
mapfile -t TABLES < <("$PG_RESTORE" -l "$DUMP" | sed -n 's/.* TABLE DATA public \([^ ]*\) .*/\1/p' | sort -u)
echo "📋 جداول في النسخة: ${TABLES[*]}"

# مشروع جديد؟ (مفيش جدول workers)
EXISTS=$("$PSQL" "$SUPABASE_DB_URL" -X -t -A -c "select to_regclass('public.workers') is not null")
if [ "$EXISTS" != "t" ]; then
  echo "🆕 مشروع جديد — بيعمل الجداول..."
  "$PG_RESTORE" --schema-only --no-owner --no-privileges --schema=public -f "$WORK/schema.sql" "$DUMP"
  "$PSQL" "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=1 --single-transaction -f "$WORK/schema.sql"
fi

# نمسح بيانات الجداول الموجودة ونحط بيانات النسخة في transaction واحدة
TRUNC=""
for t in "${TABLES[@]}"; do
  ok=$("$PSQL" "$SUPABASE_DB_URL" -X -t -A -c "select to_regclass('public.\"$t\"') is not null")
  [ "$ok" = "t" ] && TRUNC="$TRUNC public.\"$t\","
done
"$PG_RESTORE" --data-only --no-owner --no-privileges --schema=public -f "$WORK/data.sql" "$DUMP"
{
  [ -n "$TRUNC" ] && echo "truncate ${TRUNC%,} restart identity cascade;"
  cat "$WORK/data.sql"
} > "$WORK/restore.sql"
echo "🗄️ بيرجّع البيانات..."
"$PSQL" "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=1 --single-transaction -f "$WORK/restore.sql"

# الأعداد بعد الاسترجاع
for t in "${TABLES[@]}"; do
  echo "   $t: $("$PSQL" "$SUPABASE_DB_URL" -X -t -A -c "select count(*) from public.\"$t\"") صف"
done

if [ -d "$WORK/storage" ] && [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  echo "🖼️ بيرجّع الصور والملفات..."
  node "$(dirname "$0")/storage.mjs" upload "$WORK/storage"
fi
echo "✅ الاسترجاع خلص"
