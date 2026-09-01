// Firestore 보안 규칙 회귀 테스트
//
//   실행:  node test/firestore_rules_test.js     (firebase login 상태 필요)
//
// "컴파일 성공"과 "실제로 막힘"은 완전히 별개다. 실제로 중첩된
// `match /{document=**}` 가 users/{userId} 문서 자신에게도 매칭돼서
// 과금 필드 보호를 통째로 무력화한 적이 있는데, 컴파일도 배포도
// 멀쩡히 통과했다. 규칙을 건드리면 반드시 이 테스트를 돌릴 것.
//
// Rules Test API(firebaserules.googleapis.com) 사용 — 에뮬레이터 불필요.
const fs = require('fs');
const os = require('os');
const path = require('path');

const cfg = JSON.parse(
  fs.readFileSync(path.join(os.homedir(), '.config/configstore/firebase-tools.json'), 'utf-8'));
const rules = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf-8');
// firebase-tools에 내장된 공개 OAuth 클라이언트 (CLI 소스에 공개된 값)
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const P = '/databases/(default)/documents';
const T = '2026-09-01T00:00:00Z';
const auth = uid => ({uid, token:{}});
const base = {uid:'u1', email:'a@b.c', displayName:'A', plan:'free', dailyUsage:5, lastUsageDate:'2026-09-01', isPremium:false};

const cases = [
 ['DENY','isPremium=true 로 승격 시도','update',`${P}/users/u1`,auth('u1'),{...base,isPremium:true},base],
 ['DENY','dailyUsage 0으로 리셋 시도','update',`${P}/users/u1`,auth('u1'),{...base,dailyUsage:0},base],
 ['DENY','lastUsageDate 과거로 조작','update',`${P}/users/u1`,auth('u1'),{...base,lastUsageDate:'2020-01-01'},base],
 ['ALLOW','일반 프로필 필드 수정','update',`${P}/users/u1`,auth('u1'),{...base,displayName:'B'},base],
 ['DENY','유저 문서 삭제(카운터 리셋 우회)','delete',`${P}/users/u1`,auth('u1'),null,base],
 ['ALLOW','최초 문서 생성(무료 기본값)','create',`${P}/users/u1`,auth('u1'),{uid:'u1',email:'a@b.c',plan:'free',dailyUsage:0,lastUsageDate:''},null],
 ['DENY','생성부터 isPremium=true','create',`${P}/users/u1`,auth('u1'),{uid:'u1',dailyUsage:0,lastUsageDate:'',isPremium:true},null],
 ['DENY','생성부터 dailyUsage=-999','create',`${P}/users/u1`,auth('u1'),{uid:'u1',dailyUsage:-999,lastUsageDate:''},null],
 ['ALLOW','내 링크 읽기','get',`${P}/users/u1/links/L1`,auth('u1'),null,{url:'x'}],
 ['DENY','남의 링크 읽기','get',`${P}/users/u2/links/L1`,auth('u1'),null,{url:'x'}],
 ['DENY','남의 유저문서 수정','update',`${P}/users/u2`,auth('u1'),{...base,displayName:'hack'},base],
 ['DENY','미로그인 접근','get',`${P}/users/u1`,null,null,base],
 ['ALLOW','내 링크 생성','create',`${P}/users/u1/links/L1`,auth('u1'),{url:'x'},null],
 ['ALLOW','내 설정 문서 쓰기','update',`${P}/users/u1/settings/myroom_tags`,auth('u1'),{tags:['a']},{tags:[]}],
 ['ALLOW','깊은 중첩 하위문서','get',`${P}/users/u1/links/L1/notes/N1`,auth('u1'),null,{t:'x'}],
 ['DENY','남의 설정 쓰기','update',`${P}/users/u2/settings/myroom_tags`,auth('u1'),{tags:['h']},{tags:[]}],
 // ── 무료 한도 설정 문서 ──
 ['ALLOW','한도 설정 읽기(로그인)','get',`${P}/config/limits`,auth('u1'),null,{dailyFree:10,monthlyFree:100}],
 ['DENY','한도 설정 읽기(미로그인)','get',`${P}/config/limits`,null,null,{dailyFree:10,monthlyFree:100}],
 ['DENY','한도 상향 조작','update',`${P}/config/limits`,auth('u1'),{dailyFree:99999,monthlyFree:99999},{dailyFree:10,monthlyFree:100}],
 ['DENY','한도 문서 삭제','delete',`${P}/config/limits`,auth('u1'),null,{dailyFree:10,monthlyFree:100}],
 // ── 월간 사용량 필드 보호 ──
 ['DENY','monthlyUsage 리셋 시도','update',`${P}/users/u1`,auth('u1'),{...base,monthlyUsage:0},{...base,monthlyUsage:80,lastUsageMonth:'2026-09'}],
 ['DENY','lastUsageMonth 조작','update',`${P}/users/u1`,auth('u1'),{...base,lastUsageMonth:'1999-01'},{...base,monthlyUsage:80,lastUsageMonth:'2026-09'}],
];

const testSuite = {testCases: cases.map(([exp,,m,docPath,a,newData,oldData])=>{
  const req = {path: docPath, method:m, time:T};
  if (a) req.auth = a;
  if (newData) req.resource = {data:newData};
  const tc = {expectation:exp, request:req};
  if (oldData) tc.resource = {data:oldData};
  return tc;
})};

(async()=>{
 const r = await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:new URLSearchParams({client_id:CLIENT_ID,client_secret:CLIENT_SECRET,refresh_token:cfg.tokens.refresh_token,grant_type:'refresh_token'})});
 const tok = (await r.json()).access_token;
 const res = await fetch('https://firebaserules.googleapis.com/v1/projects/my-nexus-hub:test',{method:'POST',
  headers:{Authorization:'Bearer '+tok,'Content-Type':'application/json'},
  body:JSON.stringify({source:{files:[{name:'firestore.rules',content:rules}]},testSuite})});
 const j = await res.json();
 if (j.error) return console.error('ERR', JSON.stringify(j.error).slice(0,500));
 if (j.issues) console.log('ISSUES', JSON.stringify(j.issues).slice(0,800)); 
 let pass=0, fail=0;
 (j.testResults||[]).forEach((t,i)=>{
   const ok = t.state === 'SUCCESS';
   ok?pass++:fail++;
   console.log(`${ok?'✅':'❌'} [기대 ${cases[i][0]}] ${cases[i][1]}${ok?'':'  ← 실패! '+JSON.stringify(t.errorPosition||'')}`);
 });
 console.log(`\n통과 ${pass} / 실패 ${fail}`);
})();
