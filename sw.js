// نسخة البرنامج على الجهاز: بيفتح أسرع، وبيفتح حتى لو النت ضعيف
// البيانات (Supabase) مش بتتخزن هنا أبدًا — بتيجي من السيرفر كل مرة
const CACHE = "sakan-v1";
const SHELL = ["./", "./index.html", "./manifest.webmanifest", "./icons/icon-192.png", "./icons/icon-512.png"];
const CDN = ["cdn.jsdelivr.net", "cdnjs.cloudflare.com"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  // البرنامج نفسه: من النت الأول (عشان أي تعديل يوصل على طول)، ولو مفيش نت من النسخة اللي على الجهاز
  if (url.origin === self.location.origin) {
    e.respondWith(fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match("./index.html"))));
    return;
  }
  // المكتبات (Supabase، Excel، قراية الصور): من الجهاز على طول، وتتحدّث في الخلفية
  if (CDN.includes(url.hostname)) {
    e.respondWith(caches.open(CACHE).then(c => c.match(req).then(hit => {
      const net = fetch(req).then(res => { if (res.ok) c.put(req, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    })));
  }
  // أي حاجة تانية (Supabase API والصور): زي ما هي من غير تخزين
});
