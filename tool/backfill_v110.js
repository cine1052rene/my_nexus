// 1.1.0 백필: 기존 링크에 urlKey(중복 판별 키) + 글·게시물 링크의 description(og:description) 채우기.
// 규칙은 lib/shared/utils/link_key.dart · link_metadata_service.dart 와 같아야 한다.
// 실행: node tool/backfill_v110.js [--dry]   (firebase-tools 로그인 토큰 사용, status는 건드리지 않음)
const fs = require('fs');
const DRY = process.argv.includes('--dry');
const T = JSON.parse(fs.readFileSync(require('os').homedir() + '/.config/configstore/firebase-tools.json', 'utf-8')).tokens.access_token;
const BASE = 'https://firestore.googleapis.com/v1/projects/my-nexus-hub/databases/(default)/documents';
const H = { Authorization: 'Bearer ' + T, 'Content-Type': 'application/json', 'x-goog-user-project': 'my-nexus-hub' };
const FB_UA = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
const TRACK = new Set(['si','igsh','igshid','fbclid','gclid','feature','ref','ref_src','s','t','mibextid','rdid','share_url','is_from_webapp','sender_device','web_id','_r','_t','xmt','slof']);
const YT = /(?:youtu\.be\/|youtube\.com\/(?:shorts\/|embed\/|live\/|v\/|\S*?[?&]v=))([A-Za-z0-9_-]{11})/;

function key(raw) {
  const url = raw.trim(); const y = url.match(YT); if (y) return 'yt:' + y[1];
  let u; try { u = new URL(url); } catch { return url.toLowerCase(); }
  const host = u.hostname.toLowerCase().replace(/^(www|m|mobile)\./, '');
  const segs = u.pathname.split('/').filter(Boolean).map(decodeURIComponent);
  const after = m => { const i = segs.indexOf(m); return i >= 0 && i + 1 < segs.length ? segs[i + 1] : null; };
  if (host.endsWith('tiktok.com')) { const id = after('video') || after('photo'); if (id) return 'tt:' + id; }
  if (host.endsWith('instagram.com')) { const id = after('p') || after('reel') || after('reels') || after('tv'); if (id) return 'ig:' + id; }
  if (host.startsWith('threads.')) { const id = after('post'); if (id) return 'th:' + id; }
  if (host === 'x.com' || host === 'twitter.com') { const id = after('status'); if (id) return 'x:' + id; }
  const kept = [...u.searchParams.entries()].filter(([k]) => !TRACK.has(k) && !k.startsWith('utm_'));
  const q = kept.length ? '?' + kept.sort((a, b) => a[0] < b[0] ? -1 : 1).map(([k, v]) => k + '=' + v).join('&') : '';
  return (host + '/' + segs.join('/') + q).toLowerCase();
}
async function resolveTikTok(url) {
  const u = new URL(url);
  if (!(u.hostname.startsWith('vt.') || u.hostname.startsWith('vm.') || u.pathname.startsWith('/t/'))) return url;
  try { const r = await fetch(url, { redirect: 'manual' }); return (r.headers.get('location') || url).split('?')[0]; } catch { return url; }
}
const ent = s => s.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+);/gi, (m, e) => e[0] === '#' ? String.fromCharCode(e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : +e.slice(1)) : ({ amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' }[e] || m));
async function ogDesc(url, cat) {
  try {
    const meta = ['facebook', 'instagram', 'threads'].includes(cat);
    const r = await fetch(url, { headers: meta ? { 'User-Agent': FB_UA, 'Accept-Language': 'ko-KR,ko;q=0.9' } : {}, signal: AbortSignal.timeout(10000) });
    if (!r.ok) return null;
    const html = await r.text();
    const m = html.match(/<meta[^>]+property=["']og:description["'][^>]*content=["']([^"']*)["']/i) || html.match(/<meta[^>]+content=["']([^"']*)["'][^>]*property=["']og:description["']/i);
    if (!m) return null;
    const t = ent(m[1]).replace(/\s+/g, ' ').trim();
    if (t.length < 10 || /^(log in|sign up|로그인)/i.test(t)) return null;
    return t.slice(0, 1000);
  } catch { return null; }
}
(async () => {
  const r = await fetch(BASE + ':runQuery', { method: 'POST', headers: H, body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'links', allDescendants: true }], select: { fields: ['url', 'category', 'urlKey', 'description'].map(f => ({ fieldPath: f })) } } }) });
  const docs = (await r.json()).filter(x => x.document).map(x => x.document);
  let keys = 0, descs = 0, i = 0;
  for (const d of docs) {
    i++; const f = d.fields || {}; const url = f.url?.stringValue || ''; const cat = f.category?.stringValue || 'etc';
    if (!url || cat === 'memo' || cat === 'capture') continue;
    const upd = {};
    if (!f.urlKey) upd.urlKey = key(cat === 'tiktok' ? await resolveTikTok(url) : url);
    const needDesc = !['youtube', 'tiktok', 'twitter'].includes(cat) && !(f.description?.stringValue);
    if (needDesc) { const ds = await ogDesc(url, cat); if (ds) upd.description = ds; }
    if (!Object.keys(upd).length) continue;
    if (upd.urlKey) keys++; if (upd.description) descs++;
    if (!DRY) {
      const mask = Object.keys(upd).map(k => 'updateMask.fieldPaths=' + k).join('&');
      const w = await fetch('https://firestore.googleapis.com/v1/' + d.name + '?' + mask, { method: 'PATCH', headers: H, body: JSON.stringify({ fields: Object.fromEntries(Object.entries(upd).map(([k, v]) => [k, { stringValue: v }])) }) });
      if (!w.ok) console.log('쓰기 실패', w.status, (await w.text()).slice(0, 120));
    }
    if (i % 50 === 0) console.log(`${i}/${docs.length} 키 ${keys} 설명 ${descs}`);
  }
  console.log(`${DRY ? '[미리보기] ' : ''}완료: 링크 ${docs.length}개 중 urlKey ${keys}개, description ${descs}개`);
})();
