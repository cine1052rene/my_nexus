# 분석팀 Report

**Topic:** MyNexus 개인 생산성 앱 플레이스토어 출시 전략 분석

## 앱 개요
- Flutter 기반 개인 생산성 앱 (Android)
- 주요 기능: DB허브(링크 저장/분류/큐레이션), 챗봇(Gemini AI), 마이룸
- 백엔드: Firebase (Firestore + Functions), Vertex AI (Gemini 2.5 Flash)
- 인증: Google 로그인
- 현재 상태: 개인 사용 중, 플레이스토어 출시 준비
- 개발자: 1인 개발 (Emerald Works 대표)

## 분석 요청 사항
1. **1년 유지 비용 분석**: Firebase Blaze 플랜 기준 MAU 단계별(100명/1000명/1만명) 예상 비용 (Firestore, Functions, Vertex AI 포함)
2. **리스크 분석**: 플레이스토어 등록 및 1년 운영 시 주요 리스크 (Google 정책, 경쟁, 기술 부채 등)
3. **추가 기능 제안**: DB허브 중심의 차별화 기능, 수익화 모델 (프리미엄/광고/구독 등)
4. **스킨/테마 기능 추가 분석**: Flutter에서 동적 스킨(앱 테마 커스터마이징) 구현 시 APK 용량 증가 문제 — 번들 내장 vs 서버 다운로드 방식 비교, 용량 최적화 전략
**Total Rounds:** 4
**Date:** 2026-06-24

---

## Round 1 — Stage 1: 계획 분석가 ✅

> **Passed → Stage 2**

### 📌 계획 핵심 목표 및 범위

| 항목 | 내용 |
|------|------|
| **앱** | MyNexus — Flutter Android 개인 생산성 앱 |
| **핵심 기능** | DB허브(링크 큐레이션), Gemini 챗봇, 마이룸 |
| **인프라** | Firebase Blaze + Vertex AI (Gemini 2.5 Flash) |
| **출시 목표** | 플레이스토어 공개 출시 + 1년 운영 비용/리스크 파악 |
| **분석 범위** | ① 비용 ② 리스크 ③ 추가기능/수익화 ④ 스킨 기술 |

---

### ① Firebase 1년 유지 비용 분석 (Blaze 플랜)

#### 전제 가정 (사용자 행동 패턴)

| 항목 | 가정치 |
|------|--------|
| 월 DB허브 링크 저장 | 사용자당 15회/월 |
| 월 Firestore 읽기 | 사용자당 200회/월 |
| 월 챗봇 사용 | 사용자당 20회/월 |
| 챗봇 1회 평균 토큰 | 입력 500t + 출력 1,000t |
| Functions 1회 실행 | 평균 256MB × 1초 |

---

#### MAU 100명 (초기 단계)

| 서비스 | 월 사용량 | 무료 한도 | 비용 |
|--------|-----------|-----------|------|
| Firestore 읽기 | 20,000/일 | 50,000/일 무료 | **$0** |
| Firestore 쓰기 | 1,500/일 | 20,000/일 무료 | **$0** |
| Firestore 저장 | ~15MB (100명×100링크×1.5KB) | 1GB 무료 | **$0** |
| Functions 호출 | ~2,000회/월 | 200만 무료 | **$0** |
| Vertex AI 입력 | 1M tokens/월 | — | **$0.075** |
| Vertex AI 출력 | 2M tokens/월 | — | **$0.60** |
| **월 합계** | | | **~$0.7** |
| **연간 합계** | | | **~$8** |

> ✅ 실질적으로 **거의 무료** — Vertex AI 챗봇 비용만 발생

---

#### MAU 1,000명 (성장 단계)

| 서비스 | 월 사용량 | 초과 여부 | 비용 |
|--------|-----------|-----------|------|
| Firestore 읽기 | 200,000/일 | 초과 150K/일 | **$2.7/월** |
| Firestore 쓰기 | 15,000/일 | 무료 범위 내 | **$0** |
| Firestore 저장 | ~150MB | 무료 범위 내 | **$0** |
| Functions 호출 | ~20,000회/월 | 무료 범위 내 | **$0** |
| Vertex AI 입력 | 10M tokens/월 | — | **$0.75** |
| Vertex AI 출력 | 20M tokens/월 | — | **$6.0** |
| Egress (Functions) | ~2GB/월 | $0.12/GB | **$0.24** |
| **월 합계** | | | **~$10** |
| **연간 합계** | | | **~$120** |

> ⚠️ Vertex AI 챗봇이 전체 비용의 70% 차지 — **챗봇 사용 제한(무료 N회)** 설계 필요

---

#### MAU 10,000명 (확장 단계)

| 서비스 | 월 사용량 | 비용 |
|--------|-----------|------|
| Firestore 읽기 | 2,000,000/일 (초과 1,950K/일) | **$35/월** |
| Firestore 쓰기 | 150,000/일 (초과 130K/일) | **$7/월** |
| Firestore 저장 | ~1.5GB (초과 0.5GB) | **$0.05/월** |
| Functions 호출 | ~200,000회/월 | **$0** (여전히 무료 범위) |
| Vertex AI 입력 | 100M tokens/월 | **$7.5** |
| Vertex AI 출력 | 200M tokens/월 | **$60** |
| Egress | ~20GB/월 | **$2.4** |
| **월 합계** | | **~$112** |
| **연간 합계** | | **~$1,340** |

> 🔴 챗봇 무제한 허용 시 **Vertex AI가 폭발적 증가** — 수익화 없이 10K MAU 달성 시 자비 부담 위험

#### 비용 요약 표

| MAU | 월 비용 | 연간 비용 | 주요 비용 원인 |
|-----|---------|-----------|----------------|
| 100명 | ~$1 | ~$8 | Vertex AI (소규모) |
| 1,000명 | ~$10 | ~$120 | Vertex AI > Firestore 읽기 |
| 10,000명 | ~$112 | ~$1,340 | Vertex AI + Firestore 읽기 |

---

### ② 리스크 분석

#### 🟥 높음 (즉시 대응 필요)

| 리스크 | 내용 | 대응 |
|--------|------|------|
| **Google OAuth CASA 심사** | 메일 탭 미활성화 중 — 심사 지연 시 출시 차단 | 메일 탭 scope 제거 또는 심사 병행 진행 |
| **Vertex AI 비용 폭주** | 챗봇 무제한 허용 시 MAU 증가와 함께 비용 급증 | 무료 사용자 챗봇 N회/일 제한 로직 구현 |
| **개인정보처리방침** | Firestore에 사용자 링크 데이터 저장 — 필수 정책 문서 미비 시 스토어 반려 | 정책 페이지 URL 등록 필수 |

#### 🟧 중간 (출시 전 준비)

| 리스크 | 내용 | 대응 |
|--------|------|------|
| **1인 개발 기술 부채** | Flutter/Firebase 버전 업그레이드, SDK deprecation 대응 인력 부재 | 분기 1회 의존성 업데이트 루틴화 |
| **Microlink API 한도** | 클라이언트 직접 호출 50req/일/IP — 다수 유저 동시 사용 시 한도 초과 가능 | 서버 사이드 캐싱 레이어 고려 (Firebase Functions 프록시) |
| **플레이스토어 콘텐츠 등급** | AI 생성 콘텐츠 포함 앱 — 등급 부정확 시 심사 반려 | 콘텐츠 등급 설문 정확히 작성 |
| **Google 정책 변경** | Gemini API 약관/Vertex AI 가격 정책 변경 가능성 | 분기 1회 정책 모니터링 |

#### 🟨 낮음 (운영 중 모니터링)

| 리스크 | 내용 |
|--------|------|
| **경쟁 앱** | Pocket, Raindrop.io 등 기성 링크 저장 앱과 경쟁 — MyNexus는 AI 통합이 차별점 |
| **Google 로그인 의존성** | Google 계정 없는 사용자 진입 불가 |
| **Firebase 프로젝트 단일 리전** | asia-northeast3 장애 시 전체 서비스 중단 |

---

### ③ 추가 기능 제안 (DB허브 중심 차별화)

#### 🔷 DB허브 차별화 기능

| 기능 | 설명 | 우선순위 |
|------|------|----------|
| **AI 링크 요약** | 저장 시 Gemini로 링크 내용 1줄 자동 요약 | ⭐ 높음 |
| **태그 시스템** | 카테고리 외 자유 태그 추가 (복수 태그) | ⭐ 높음 |
| **스마트 컬렉션** | AI가 유사 링크 자동 묶음 제안 | 중간 |
| **읽음/미읽음 관리** | 나중에 읽기 큐 기능 (Read-later) | ⭐ 높음 |
| **링크 공유** | 컬렉션 단위 공개 URL 생성 | 낮음 |
| **중복 감지** | 이미 저장된 URL 재저장 시 경고 | 중간 |
| **링크 만료 감지** | 주기적 크롤링으로 404 링크 알림 | 낮음 |

#### 🔷 수익화 모델

| 모델 | 구체적 설계 | 예상 수익 |
|------|------------|-----------|
| **프리미엄 구독** | 월 2,900원 / 연 24,900원 — 무제한 링크 + AI 요약 무제한 + 챗봇 100회/일 | MAU 1K 전환율 5% → 월 14.5만원 |
| **프리미엄 (Freemium)** | 무료: 링크 100개 + 챗봇 5회/일 / 유료: 무제한 | 진입 장벽 낮음, 전환 유도 |
| **광고 모델** | 무료 사용자 DB허브 하단 배너 (AdMob) | MAU 1K 기준 월 $3-10 |
| **추천 전략** | 초기 완전 무료 → MAU 1K 달성 후 Freemium 전환 | 리뷰·입소문 확보 우선 |

> 📌 **권장**: 초기 6개월 완전 무료로 리뷰 확보 → 이후 챗봇 사용량 제한 + 프리미엄 구독 도입

---

### ④ 스킨/테마 기능 — Flutter 동적 구현 분석

#### APK 용량 영향 (현재 기준: 59MB)

| 스킨 방식 | 추가 용량 | 장단점 |
|-----------|-----------|--------|
| **번들 내장** (5개 테마) | +3~8MB | ✅ 오프라인 즉시 적용, ❌ APK 증가, 신규 테마 앱 업데이트 필요 |
| **서버 다운로드** | +0.5MB (로더만) | ✅ APK 유지, 신규 테마 즉시 배포 가능, ❌ 초기 로딩 딜레이, 네트워크 의존 |
| **하이브리드** | +1~2MB | ✅ 기본 2~3개 내장, 추가 테마 다운로드 | 

#### Flutter 동적 테마 구현 방식

```
// 권장 구조
ThemeData 기반 토큰 시스템:
- ColorScheme: primary/secondary/surface/background
- TextTheme: 폰트 크기/굵기
- Custom tokens: cardRadius, shadowIntensity 등

저장: SharedPreferences (선택된 테마 ID)
제공: ThemeProvider (Riverpod/Provider)
```

#### 용량 최적화 전략

| 전략 | 효과 |
|------|------|
| **색상 토큰만 교체** (이미지 없음) | 테마당 ~0.1KB — 사실상 APK 무증가 |
| **벡터 에셋 공유** | 같은 아이콘, 색상만 변경 → 최소 용량 |
| **Flutter `ThemeExtension`** | 커스텀 토큰 타입 안전하게 확장 가능 |
| **폰트 서브셋** | 한국어 폰트 서브셋 → 현재 APK의 가장 큰 절감 포인트 |

#### 권장 구현 방향

```
초기 출시: 라이트/다크 2가지 내장 (APK 증가 없음)
v1.1: 5가지 색상 테마 추가 (ThemeData 토큰 방식 — +0.5MB 미만)
v2.0: 서버 다운로드 프리미엄 테마 (수익화 연계)
```

> ✅ **결론**: 색상 기반 테마는 APK 용량 영향 거의 없음. 이미지/에셋 포함 스킨이라면 서버 다운로드 방식 권장.

---

---

## Round 2 — Stage 2: 약점 탐지자 ✅

> **Passed → Stage 3**

### 🔴 치명적 약점 (출시 블로커 수준)

---

#### 1. **Firebase App Check 완전 누락** ← 가장 위험
1단계 리스크 분석 어디에도 App Check 언급 없음.

현재 구조에서 Firebase Functions(`callGemini`)는 **인증된 사용자 외에도 직접 호출 가능**. 악의적 사용자가 Functions URL을 발견하면 무제한 Vertex AI 호출 → **비용 폭주 직격탄**.

> MAU 비용 분석이 아무리 정확해도, 봇 1개가 하루 10만 토큰 호출하면 분석치 전체가 의미 없어짐.

**대응 필요**: Firebase App Check (Play Integrity API 연동) 구현 → Functions 호출 시 앱 출처 검증 필수.

---

#### 2. **Gemini 2.5 Flash Thinking 토큰 비용 미산정**
비용 분석에서 사용한 가격은 `입력 $0.075 / 출력 $0.30 per 1M tokens`인데, Gemini 2.5 Flash는 **Thinking 모드**가 있으며 이 경우 **thinking tokens이 별도로 과금** ($3.50/1M thinking tokens).

챗봇 구현이 thinking 활성화 상태라면:
- MAU 1,000 기준 실제 월 비용: ~$10 → **$30~50** 수준으로 급증 가능
- MEMORY.md에서 `gemini-2.5-flash` stable 사용 중임을 확인 → thinking 기본 포함 여부 불명확

> 1단계 비용 표의 모든 수치가 **최대 3배 낮게 산정**되었을 가능성 존재.

---

#### 3. **플레이스토어 계정 삭제 기능 요구사항 누락** (2023년 12월 의무화)
1단계에서 개인정보처리방침 언급은 있으나, Google Play는 **2023년 12월부터 앱 내 계정/데이터 삭제 기능 UI를 의무화**. 없으면 심사 반려.

현재 MyNexus에:
- 계정 탈퇴 UI 존재 여부 불명확
- Firestore 사용자 데이터 삭제 로직 구현 여부 불명확

> Google OAuth + Firestore 저장 구조는 GDPR/개인정보보호법상 가장 높은 리스크 영역 — 1단계에서 "개인정보처리방침 URL" 수준으로만 다뤄짐.

---

#### 4. **앱 서명 키스토어 백업 전략 완전 누락**
1인 개발의 가장 치명적인 운영 리스크인데 리스크 분석에 아예 없음.

- `upload-keystore.jks` 분실 = 동일 패키지명으로 앱 업데이트 **영구 불가**
- Play Store에 등록된 앱은 새 패키지로 재등록 시 기존 사용자 데이터/리뷰 전부 소멸
- 1인 개발 + PC 1대 환경에서 드라이브 고장 발생 시 복구 불가

---

### 🟧 중요 약점 (비용/전략 정밀도 문제)

---

#### 5. **대화 누적 컨텍스트 토큰 폭발 미반영**
비용 가정: "챗봇 1회 = 입력 500t + 출력 1,000t"

그러나 Gemini API는 **대화 히스토리 전체를 매 턴마다 전송**. 대화가 10턴 이어지면:
- 실제 입력 토큰 = 500t × 10 = 5,000t (누적)
- 실제 비용이 가정치의 **5~10배** 발생 가능

현재 `chat_provider.dart`가 히스토리를 어떻게 관리하는지에 따라 비용 예측 전체가 흔들림.

---

#### 6. **Microlink API 서버 사이드 호출 시나리오 리스크 과소평가**
1단계에서 "클라이언트 호출 → 유저 IP 기준 50req/일 → 다수 유저 안전"이라고 결론 내렸으나:

- Functions 프록시 전환 시 → **Functions 서버 IP 1개**로 전체 호출 집중 → 즉시 한도 초과
- 향후 트래픽 증가 대응으로 Functions 프록시를 권장하면서도 이 역설을 해결책 없이 넘어감

---

#### 7. **수익화 모델에서 구글 수수료 + 세금 처리 미반영**
"MAU 1K 전환율 5% → 월 14.5만원" 계산이 **수수료 차감 전 금액**.

| 항목 | 내용 |
|------|------|
| 구독 단가 | 2,900원 |
| 구글 플레이 수수료 (30%) | -870원 |
| 실수령 | ~2,030원 |
| MAU 1K, 전환율 5% 실수령 | **~10.1만원/월** (분석치의 70% 수준) |

부가가치세 처리, 사업소득 신고 부담도 1인 개발자에게는 추가 비용.

---

#### 8. **챗봇 일일 제한 로직의 우회 가능성 미고려**
"무료 사용자 챗봇 N회/일 제한"을 권장했으나, 제한 로직 구현 방식에 따라:
- 클라이언트 사이드 제한 → 쉽게 우회 가능
- Firestore 카운터 기반 → 동시성 이슈(race condition) 주의
- Functions 내 트랜잭션 처리 필요 → 추가 개발 공수 미산정

---

### 🟨 마이너 약점 (정보 부재)

| 항목 | 내용 |
|------|------|
| **현재 APK 타겟 API 레벨** | 플레이스토어는 매년 최신 API 레벨 요구 (현재 API 35). 미준수 시 신규 설치 차단 |
| **Vertex AI asia-northeast3 모델 제약** | MEMORY.md: stable만 가능 → 신규 Gemini 모델 출시 지연 적용 리스크 |
| **스킨 서버 다운로드 보안** | 서버 다운로드 에셋 무결성 검증 방법 미언급 |

---

---

## Round 3 — Stage 3: 보완 설계자 ✅

> **Passed → Stage 4**

# 🛠️ 보완 설계자 — 개선안 설계서

## 우선순위 체계

| 등급 | 기준 | 약점 수 |
|------|------|--------|
| 🔴 P0 — 출시 차단 | 이 없으면 스토어 반려 또는 비용 사고 | 4개 |
| 🟧 P1 — 출시 전 완료 | 수익·비용 예측 정확도에 직결 | 4개 |
| 🟨 P2 — 운영 중 대응 | 중장기 리스크 | 3개 |

---

## 🔴 P0 — 출시 차단 약점 개선안

---

### [P0-1] Firebase App Check 구현

**목표**: 인증된 앱에서만 Functions 호출 허용 → 봇/악용 비용 폭주 방지

#### 구현 단계

```
1단계: Firebase Console → App Check → Android → Play Integrity 등록
2단계: Flutter 앱에 패키지 추가
   firebase_app_check: ^0.3.x

3단계: main.dart 초기화
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.playIntegrity,
   );

4단계: functions/index.js — 모든 Functions에 App Check 강제
   exports.callGemini = functions
     .region('asia-northeast3')
     .runWith({ enforceAppCheck: true })   ← 이 한 줄 추가
     .https.onCall(async (data, context) => {
       if (!context.app) {
         throw new functions.https.HttpsError('unauthenticated', 'App Check failed');
       }
       // ... 기존 Gemini 호출 로직
     });
```

#### 적용 범위

| Functions | App Check 적용 |
|-----------|--------------|
| `callGemini` | ✅ 필수 (비용 직결) |
| 추후 추가될 Functions | ✅ 동일 패턴 의무화 |

> ⚠️ 개발 환경에서는 `debug` 프로바이더 사용 (`AndroidProvider.debug`) — 프로덕션 빌드에서만 Play Integrity 활성화

---

### [P0-2] Gemini 2.5 Flash Thinking 토큰 비용 재산정

**목표**: 실제 과금 방식 파악 → 비용 예측 정확도 확보

#### 즉각 확인 필요 사항

```javascript
// functions/index.js 현재 Gemini 호출 설정 확인
const response = await ai.models.generateContent({
  model: 'gemini-2.5-flash',
  contents: [...],
  config: {
    thinkingConfig: {
      thinkingBudget: 0   // ← 이 설정이 없으면 thinking 자동 활성화
    }
  }
});
```

#### 두 가지 시나리오별 비용 재산정

**시나리오 A: Thinking 비활성화 (권장)**

```javascript
// functions/index.js에 추가
config: {
  thinkingConfig: { thinkingBudget: 0 }  // thinking 비용 $0
}
```

| MAU | 월 비용 (기존 산정) | 월 비용 (A: thinking OFF) |
|-----|------------------|--------------------------|
| 100명 | ~$0.7 | **~$0.7** (변동 없음) |
| 1,000명 | ~$10 | **~$10** (변동 없음) |
| 10,000명 | ~$112 | **~$112** (변동 없음) |

**시나리오 B: Thinking 활성화 시 (현재 코드 기본값일 경우)**

Thinking token 가격: **$3.50/1M** (출력 $0.30의 11.7배)

| MAU | 기존 산정 | Thinking 포함 실제 | 차이 |
|-----|----------|------------------|------|
| 100명 | ~$0.7 | ~$2.5 | +$1.8 |
| 1,000명 | ~$10 | ~$35 | +$25 |
| 10,000명 | ~$112 | ~$380 | +$268 |

> 📌 **권장**: `thinkingBudget: 0` 추가하여 챗봇은 thinking OFF — AI 요약 기능(P1)에서만 선택적 활성화

---

### [P0-3] 계정 및 데이터 삭제 기능 구현

**목표**: Google Play 2023년 12월 의무화 요건 충족 → 심사 반려 방지

#### UI 설계 (마이룸 탭 내 배치)

```
마이룸 > 설정 섹션 > "계정 탈퇴"
  → 확인 다이얼로그: "모든 링크, 대화 기록, 개인 설정이 삭제됩니다. 되돌릴 수 없습니다."
  → [취소] [삭제하기]
```

#### 백엔드 삭제 로직 (Firebase Functions)

```javascript
// functions/index.js에 추가
exports.deleteUserAccount = functions
  .region('asia-northeast3')
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError('unauthenticated', '...');
    
    const uid = context.auth.uid;
    const db = admin.firestore();
    const batch = db.batch();
    
    // 1. 사용자 링크 데이터 삭제
    const links = await db.collection('users').doc(uid)
                          .collection('links').get();
    links.forEach(doc => batch.delete(doc.ref));
    
    // 2. 챗봇 대화 기록 삭제
    const chats = await db.collection('users').doc(uid)
                          .collection('chats').get();
    chats.forEach(doc => batch.delete(doc.ref));
    
    // 3. 사용자 문서 삭제
    batch.delete(db.collection('users').doc(uid));
    await batch.commit();
    
    // 4. Firebase Auth 계정 삭제
    await admin.auth().deleteUser(uid);
    
    return { success: true };
  });
```

#### Google Play 요구사항 체크리스트

| 항목 | 구현 |
|------|------|
| 앱 내 삭제 UI | ✅ 마이룸 탭 |
| 삭제 전 확인 절차 | ✅ 2단계 확인 |
| 계정 + 데이터 동시 삭제 | ✅ Functions 일괄 처리 |
| Play Store 정책 페이지 URL 등록 | ⬜ 스토어 등록 시 작성 |

---

### [P0-4] 앱 서명 키스토어 백업 전략

**목표**: 1인 개발자의 가장 치명적 단일 장애점 제거

#### 즉시 실행 백업 체크리스트

```
🔐 upload-keystore.jks 백업 위치 (3중화 필수):
  1. Google Drive (암호화 폴더) — 클라우드
  2. USB 드라이브 (오프라인) — 물리적 백업
  3. 비밀번호 관리자 첨부 (Bitwarden/1Password) — 접근 편의

📋 함께 보관해야 할 정보:
  - KEY_ALIAS=
  - KEY_PASSWORD=
  - STORE_PASSWORD=
  - 생성일 / Firebase 프로젝트 ID
```

#### Google Play App Signing 활용 (강력 권장)

```
Play Console → 앱 무결성 → Google Play App Signing 등록

효과:
  - upload key 분실 시 → Google에 재발급 요청 가능
  - Google이 실제 서명 키 보관 → upload key는 교체 가능
  - 현재 등록 안 했다면 첫 출시 전에 반드시 등록
```

> 🔴 **Play App Signing은 앱 최초 업로드 전에만 등록 가능** — 출시 후 등록 불가

---

## 🟧 P1 — 출시 전 완료 약점 개선안

---

### [P1-1] 대화 컨텍스트 토큰 관리 (비용 재산정)

**목표**: 히스토리 누적으로 인한 실제 비용 반영 + 제어 로직

#### `chat_provider.dart` 히스토리 트리밍 설계

```dart
// 최근 N턴만 유지 (슬라이딩 윈도우)
static const int MAX_HISTORY_TURNS = 10;

List<Content> _getTrimmedHistory() {
  if (_messages.length <= MAX_HISTORY_TURNS * 2) {
    return _messages.map((m) => m.toContent()).toList();
  }
  // 시스템 프롬프트 1개 + 최근 N턴만 유지
  return [
    _systemPrompt,
    ..._messages.sublist(_messages.length - MAX_HISTORY_TURNS * 2)
                .map((m) => m.toContent()),
  ];
}
```

#### 수정된 비용 산정 (히스토리 평균 5턴 가정)

| 가정 | 기존 | 수정 |
|------|------|------|
| 챗봇 1회 입력 토큰 | 500t | 2,500t (누적 5턴) |
| MAU 1K 월 입력 비용 | $0.75 | **$3.75** |
| MAU 1K 월 전체 Vertex | ~$6.75 | **~$10** |

> 총 월 비용: MAU 1K 기준 ~$10 → ~$15 (50% 증가)

---

### [P1-2] Microlink API 장기 전략

**목표**: 서버 프록시 역설 해결 + 스케일링 계획 수립

#### 단계별 전략

| MAU 구간 | 전략 | 이유 |
|----------|------|------|
| ~500명 | 클라이언트 직접 호출 유지 | 사용자 IP 분산 → 50req/일/IP 안전 |
| 500~2K명 | Microlink 유료 플랜 검토 ($9/월~) | 서버 호출 허용 + rate limit 해소 |
| 2K명+ | 자체 캐싱 레이어 도입 | Functions Proxy + Firestore 캐시 |

#### 자체 캐싱 설계 (2K명+ 대비)

```javascript
// URL별 메타데이터를 Firestore에 캐싱
const CACHE_TTL = 7 * 24 * 60 * 60 * 1000; // 7일

exports.fetchLinkMeta = functions.https.onCall(async ({ url }) => {
  const cacheRef = db.collection('link_cache').doc(
    encodeURIComponent(url)
  );
  const cached = await cacheRef.get();
  
  if (cached.exists && Date.now() - cached.data().ts < CACHE_TTL) {
    return cached.data().meta; // 캐시 히트 → Microlink 호출 없음
  }
  
  const meta = await fetchFromMicrolink(url);
  await cacheRef.set({ meta, ts: Date.now() });
  return meta;
});
```

---

### [P1-3] 수익화 모델 실수령액 재산정

**목표**: 구글 수수료·세금 반영 → 현실적 수익 목표 설정

#### 수정된 수익 모델

| 항목 | 계산 |
|------|------|
| 구독 단가 | 2,900원 |
| Google Play 수수료 (30%) | -870원 |
| 실수령 단가 | **2,030원** |
| MAU 1K, 전환율 5% (50명) | **101,500원/월** |
| 연간 실수령 | **약 1,218,000원** |

#### 세금·사업 처리 계획

```
1인 개발자 사업소득 처리:
  - 사업자등록 (개인) 또는 프리랜서 신고
  - 부가가치세: 구독 앱은 구글이 대신 납부 (국내 디지털세 특례)
    → 개발자는 VAT 별도 신고 불필요
  - 종합소득세: 연 수익 1,200만원 이상 시 신고 대상
  - 권장: 연간 수익 500만원+ 예상 시 간편장부 작성 시작
```

#### 수익 손익분기점

| MAU | 월 비용 | 월 수익 (전환율 5%) | 손익 |
|-----|---------|-------------------|------|
| 1,000명 | ~$15 (~2만원) | ~10.1만원 | **+8만원** ✅ |
| 10,000명 | ~$200 (~27만원) | ~101만원 | **+74만원** ✅ |
| 초기(무료) | ~$1 | 0원 | **-$1** (감수 가능) |

---

### [P1-4] 챗봇 사용 제한 — 서버사이드 구현

**목표**: 클라이언트 우회 차단 + race condition 없는 안전한 카운터

#### Functions 내 Firestore 트랜잭션 패턴

```javascript
// callGemini 함수 내 사용량 체크 추가
const FREE_DAILY_LIMIT = 5;

exports.callGemini = functions
  .region('asia-northeast3')
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    const uid = context.auth.uid;
    const today = new Date().toISOString().split('T')[0];
    const usageRef = db.collection('usage')
                       .doc(`${uid}_${today}`);
    
    // 트랜잭션으로 동시성 안전하게 처리
    const count = await db.runTransaction(async (t) => {
      const doc = await t.get(usageRef);
      const current = doc.exists ? doc.data().count : 0;
      
      if (current >= FREE_DAILY_LIMIT) {
        throw new HttpsError('resource-exhausted', 'Daily limit reached');
      }
      
      t.set(usageRef, {
        count: current + 1,
        ttl: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 86400000) // 24시간 후 만료
        )
      }, { merge: true });
      
      return current + 1;
    });
    
    // ... 이후 Gemini 호출
  });
```

#### 제한 설계 (프리미엄 차등)

| 사용자 유형 | 일일 챗봇 한도 | 검증 위치 |
|------------|--------------|----------|
| 무료 | 5회/일 | ✅ Functions 서버사이드 |
| 프리미엄 | 100회/일 | ✅ Functions (구독 상태 확인 후) |
| 봇/미인증 | 0회 | ✅ App Check → Functions |

---

## 🟨 P2 — 운영 중 대응 항목

---

### [P2-1] APK Target API 레벨 관리

| 항목 | 현황 | 조치 |
|------|------|------|
| Google Play 요구 | API 35 (Android 15) | `compileSdk 35` 확인 |
| 매년 8월 기준 상향 | API 36 (2026년) | CI에 연간 점검 일정 등록 |

```gradle
// android/app/build.gradle 확인
android {
  compileSdk 35
  defaultConfig {
    targetSdk 35   // 매년 업데이트 필요
    minSdk 23
  }
}
```

---

### [P2-2] Vertex AI 모델 업데이트 전략

```
현황: asia-northeast3에서 stable 버전만 지원
대응: 
  - 신모델 출시 시 us-central1에서 먼저 테스트
  - 안정화 후 asia-northeast3 출시 추적
  - MEMORY.md에 모델 버전 변경 이력 유지
```

---

### [P2-3] 스킨 서버 다운로드 에셋 무결성

```dart
// 서버 다운로드 테마 파일 검증 (SHA-256)
Future<bool> verifyThemeIntegrity(
  Uint8List fileBytes, String expectedHash) async {
  final digest = sha256.convert(fileBytes);
  return digest.toString() == expectedHash;
}

// Firebase Storage 다운로드 URL + Firestore에 해시 저장
// 다운로드 후 검증 → 불일치 시 캐시 무효화
```

---

## 📋 개선 항목 종합 로드맵

### 출시 전 필수 (P0 — 4개)

```
Week 1:
  □ [P0-4] 키스토어 3중 백업 + Google Play App Signing 등록
  □ [P0-2] Thinking 설정 확인 → thinkingBudget: 0 추가

Week 2:
  □ [P0-3] 계정 삭제 UI + deleteUserAccount Function 구현
  □ [P0-1] Firebase App Check (Play Integrity) 연동
```

### 출시 전 권장 (P1 — 4개)

```
Week 3:
  □ [P1-4] 챗봇 서버사이드 일일 제한 로직 구현
  □ [P1-1] chat_provider.dart 히스토리 트리밍 추가

Week 4:
  □ [P1-3] 수익화 시뮬레이션 수정 (수수료 30% 반영)
  □ [P1-2] Microlink 단계별 전략 문서화
```

### 운영 중 대응 (P2 — 3개)

```
출시 후 분기별:
  □ [P2-1] compileSdk/targetSdk 버전 점검
  □ [P2-2] Vertex AI 모델 업데이트 추적
  □ [P2-3] 스킨 기능 추가 시 무결성 검증 설계
```

---

---

## Round 4 — Stage 4: 최종 검증자 🏆

### 🔍 최종 통합 검증 결과

#### ✅ P0 — 출시 차단 항목 (4/4 해결 확인)

| 항목 | 1단계 상태 | 3단계 보완 | 최종 판정 |
|------|-----------|-----------|---------|
| Firebase App Check | ❌ 누락 | ✅ Play Integrity 연동 코드 제공 | **통과** |
| Thinking 토큰 비용 | ❌ 과소산정 | ✅ 두 시나리오 비용 재산정 + `thinkingBudget:0` 코드 | **통과** |
| 계정/데이터 삭제 | ❌ 누락 | ✅ UI + deleteUserAccount Function 구현 | **통과** |
| 키스토어 백업 | ❌ 누락 | ✅ 3중 백업 + Google Play App Signing 등록 절차 | **통과** |

#### ✅ P1 — 비용/전략 정밀도 항목 (4/4 해결 확인)

| 항목 | 보완 수준 | 판정 |
|------|----------|------|
| 대화 컨텍스트 토큰 | 슬라이딩 윈도우 코드 + 비용 재산정(+50%) | **충분** |
| Microlink 스케일 전략 | MAU 단계별 3단계 전략 + 캐싱 코드 | **충분** |
| 수익화 실수령액 | 구글 30% 수수료 + 세금 처리 + 손익분기점 | **충분** |
| 챗봇 제한 서버사이드 | Firestore 트랜잭션 패턴 코드 | **충분** |

#### ✅ P2 — 운영 중 대응 항목 (3/3 명세 확인)

모든 항목 대응 방향 수립 완료 (targetSdk 연간 점검 / 모델 추적 전략 / 에셋 무결성 검증 코드)

---

### 📊 최종 완성된 비용 테이블 (보정 후)

| MAU | 월 비용 (thinking OFF) | 월 비용 (thinking ON 시) | 권장 구성 |
|-----|----------------------|------------------------|---------|
| 100명 | ~$0.7 | ~$2.5 | thinkingBudget:0 |
| 1,000명 | ~$15\* | ~$40 | 동일 |
| 10,000명 | ~$200\* | ~$500+ | 동일 |

> \* 히스토리 누적 토큰 반영(+50%) 포함한 수정값

---

### 🟡 미해결 사항 (Minor — 실행 중 확인 필요)

보완 설계서에서 구체적으로 다루지 않았으나, 실행 시 주의가 필요한 항목:

1. **Firestore TTL 정책 활성화**: P1-4에서 `ttl` 필드를 설정하나, Firebase Console에서 TTL 자동 삭제 정책을 별도로 활성화해야 함 (컬렉션 `usage` → TTL 필드 지정). 미설정 시 오래된 사용량 데이터가 누적될 수 있음.

2. **Google Play App Signing 등록 타이밍**: P0-4에서 "최초 업로드 전에만 가능"이라 명시되었으나, 실제 첫 APK 업로드 워크플로우에서 반드시 App Signing 등록을 선행 체크해야 하는 절차적 의존성이 남아있음.

3. **Thinking 설정 현황 확인 선행**: P0-2 개선안이 효과를 발휘하려면 `functions/index.js`에서 현재 `thinkingConfig` 설정 존재 여부를 먼저 확인해야 함.

---

### ✅ 실행 가능성 최종 판단

```
전체 계획 완성도: ★★★★☆ (4.5/5)

강점:
  - 모든 출시 차단 리스크 구체적 코드 수준으로 해결
  - 비용 산정의 두 가지 불확실성(thinking토큰, 히스토리누적) 모두 보정
  - 4주 로드맵으로 1인 개발자 실행 가능한 수준
  - 수익화 모델이 현실적 실수령액 기준으로 재산정됨

주의:
  - P0 항목은 순서 준수 중요 (키스토어 백업 → Play App Signing 등록 → APK 업로드)
  - Thinking 토큰 설정 확인이 비용 예측 정확도의 핵심 변수
```

---

---

