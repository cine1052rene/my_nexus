# MyNexus Build Notes

앱 버전: `pubspec.yaml`의 `version` 필드 기준  
빌드 환경: Flutter (puro stable) / Android debug APK → Galaxy S23 Ultra 실기기 테스트

---

## v1.0.0+1 — 기반 구축 (2026-06-14)

### Build 001
**커밋:** `91fbfd2` ~ `43bb0df`  
**내용:**
- Google Calendar CalDAV 연동 (로컬 device_calendar → CalDAV로 전환)
- Gmail + 외부 메일(IMAP) + AI 분류 기능 추가
- 마이룸 탭 구현 (video_clips, 플랫폼 자동 감지, 그리드 뷰)
- 설정 탭 기능 온오프 (SharedPreferences 영구 저장)
- Gmail 탭 기본 비활성화 (CASA Tier 2 리스크 반영)
- ttapp 캘린더·메일 AI 자동 관리 알람 설정

---

## v1.0.0+1 — DB 허브 개편 (2026-06-15)

### Build 002
**커밋:** `6ef0779` ~ `3214d9a`  
**내용:**
- DB 허브 뷰모드 토글 (카드 / 그리드 / 간략) 추가
- YouTube 키워드 서브필터 (9종) 추가
- 링크 삭제 시 블랙화면 버그 수정 (dialogCtx로 Navigator.pop 교체)
- 그리드 카드 오버플로우 수정 (childAspectRatio 0.78 → 0.70)
- 카테고리 필터 Firestore 복합 인덱스 오류 수정 (client-side 정렬)

### Build 003
**커밋:** `a3fe953` ~ `81abae1`  
**내용:**
- DB 허브 검색 간소화 (AppBar 돋보기 토글, X로 닫기)
- 카드에서 태그 표시 제거 (수정 시트에서만 확인)
- YouTube 키워드 서브필터 제거, 카테고리 행 단순화
- 카테고리 바를 아이콘 전용 바로 교체 (브랜드 컬러, 36px)

### Build 004
**커밋:** `964ef39` ~ `e012e93`  
**내용:**
- DB 허브 카테고리 출처 기반으로 재편 (유튜브/인스타/페북/트위터/네이버/기타)
- 카드 보기 디자인 개편 (수평 레이아웃, 썸네일 contain 안잘림, 출처 아이콘 우측, 96dp)
- 실기기(Galaxy S23 Ultra) 검증 완료

### Build 005
**커밋:** `7d091f3`  
**내용:**
- Android 공유 시트 Direct Share 상단 등록
- 공유 URL 자동 저장 UX (카테고리/제목/썸네일 자동 입력)

---

## v1.0.0+1 — 공유 버그 수정 (2026-06-17)

### Build 006
**커밋:** `72e856f`  
**내용:**
- 공유 시 앱 중복 실행 버그 수정
  - `launchMode`: `singleTop` → `singleTask`
  - `taskAffinity=""` 제거
  - `onNewIntent`에 `setIntent()` 추가 (singleTask best practice)
- 효과: 어느 앱에서 공유해도 기존 인스턴스 재사용, 중복 실행 없음

### Build 007
**커밋:** `1d3e37b`  
**내용:**
- 공유 저장 속도 대폭 개선
  - 기존: HTTP 메타데이터 요청(최대 5초) 후 Firestore 저장
  - 개선: Firestore 즉시 저장 → 저장 완료 표시 → 백그라운드 메타데이터 업데이트
  - YouTube 썸네일은 HTTP 없이 URL에서 즉시 추출
  - 인스타그램·트위터는 HTTP 차단이므로 메타데이터 스킵
- 체감 저장 시간: ~5초 → **~0.5초**

### Build 008
**커밋:** `0113967`  
**내용:**
- 한글 깨짐 수정: `res.body` → `utf8.decode(res.bodyBytes, allowMalformed: true)` 강제 적용
  - 원인: charset 미선언 사이트에서 Latin-1 디코딩으로 한글 깨짐
  - 적용: `hub_screen.dart`, `add_link_sheet.dart` 양쪽 수정
- 저장 스낵바 개선
  - duration: 4초 → **2초** 단축
  - `Listener(onPointerDown)` 추가: 화면 어디 터치해도 즉시 닫힘
- 실기기 재부팅 후 검증 완료

---

## 다음 예정 작업
- PRO 구독 Freemium 과금 설계 (₩4,900 / Google Play Billing)
- Gmail CASA Tier 2 감사 대응 또는 IMAP OAuth 대안
- Outlook MS Graph API 연동 로드맵
