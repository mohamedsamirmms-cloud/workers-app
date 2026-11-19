// نسخ صور الإقامة وملفات المعدات من Supabase Storage وإرجاعها
//   node backup/storage.mjs download <فولدر>   ← ينزّل كل الملفات
//   node backup/storage.mjs upload   <فولدر>   ← يرجّع الملفات (بيستبدل الموجود)
// محتاج: SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY
import { mkdir, writeFile, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";

const [, , mode, dir] = process.argv;
const BASE = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const BUCKETS = (process.env.BUCKETS || "iqama,equipment").split(",").map(s => s.trim()).filter(Boolean);
const PARALLEL = 6;

if (!["download", "upload"].includes(mode) || !dir || !BASE || !KEY) {
  console.error("الاستخدام: node backup/storage.mjs download|upload <فولدر>  (ومحتاج SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY)");
  process.exit(2);
}

const headers = { Authorization: `Bearer ${KEY}`, apikey: KEY };
const enc = p => p.split("/").map(encodeURIComponent).join("/");

async function api(path, opts = {}, tries = 3) {
  for (let i = 1; ; i++) {
    const res = await fetch(BASE + path, { ...opts, headers: { ...headers, ...(opts.headers || {}) } });
    if (res.ok || i >= tries || (res.status < 500 && res.status !== 429)) return res;
    await new Promise(r => setTimeout(r, 1000 * i));
  }
}

// كل الملفات في الـ bucket (وجوه الفولدرات كمان)
async function listAll(bucket, prefix = "") {
  const out = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await api(`/storage/v1/object/list/${bucket}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: "name", order: "asc" } })
    });
    if (res.status === 400 || res.status === 404) {
      const t = await res.text();
      if (/not.?found/i.test(t)) return null; // الـ bucket مش موجود
      throw new Error(`list ${bucket}: ${res.status} ${t}`);
    }
    if (!res.ok) throw new Error(`list ${bucket}: ${res.status} ${await res.text()}`);
    const items = await res.json();
    for (const it of items) {
      const path = prefix + it.name;
      if (it.id === null || it.id === undefined) out.push(...(await listAll(bucket, path + "/")) || []);
      else out.push({ path, type: (it.metadata && it.metadata.mimetype) || "application/octet-stream", size: (it.metadata && it.metadata.size) || 0 });
    }
    if (items.length < 1000) return out;
  }
}

async function pool(items, fn) {
  let i = 0, done = 0;
  await Promise.all(Array.from({ length: PARALLEL }, async () => {
    while (i < items.length) {
      const item = items[i++];
      await fn(item);
      if (++done % 50 === 0) console.log(`  ${done}/${items.length}`);
    }
  }));
}

if (mode === "download") {
  const manifest = {};
  for (const bucket of BUCKETS) {
    const files = await listAll(bucket);
    if (files === null) { console.log(`⚠️ bucket ${bucket} مش موجود — اتخطّى`); continue; }
    console.log(`${bucket}: ${files.length} ملف`);
    await pool(files, async f => {
      const res = await api(`/storage/v1/object/${bucket}/${enc(f.path)}`);
      if (!res.ok) throw new Error(`download ${bucket}/${f.path}: ${res.status}`);
      const file = join(dir, bucket, f.path);
      await mkdir(dirname(file), { recursive: true });
      await writeFile(file, Buffer.from(await res.arrayBuffer()));
    });
    manifest[bucket] = files;
  }
  await mkdir(dir, { recursive: true });
  await writeFile(join(dir, "manifest.json"), JSON.stringify(manifest, null, 1));
  const total = Object.values(manifest).reduce((s, f) => s + f.length, 0);
  console.log(`✅ اتنزّل ${total} ملف`);
}

if (mode === "upload") {
  const manifest = JSON.parse(await readFile(join(dir, "manifest.json"), "utf8"));
  let total = 0;
  for (const [bucket, files] of Object.entries(manifest)) {
    // نعمل الـ bucket لو مش موجود (مشروع جديد)
    const mk = await api(`/storage/v1/bucket`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: bucket, name: bucket, public: false }) });
    if (!mk.ok && ![400, 409].includes(mk.status)) throw new Error(`bucket ${bucket}: ${mk.status} ${await mk.text()}`);
    console.log(`${bucket}: بيرجّع ${files.length} ملف`);
    await pool(files, async f => {
      const body = await readFile(join(dir, bucket, f.path));
      const res = await api(`/storage/v1/object/${bucket}/${enc(f.path)}`, { method: "POST", headers: { "Content-Type": f.type, "x-upsert": "true" }, body });
      if (!res.ok) throw new Error(`upload ${bucket}/${f.path}: ${res.status} ${await res.text()}`);
    });
    total += files.length;
  }
  console.log(`✅ اترجّع ${total} ملف`);
}
