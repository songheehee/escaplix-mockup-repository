# Escaplix API 명세 (v3)

목업(`escaplix-mockup-repository/visualization`)에서 구현하기로 확정한 화면 기준 API 정리.

- 기준 자료: 기존 README의 API 49개(v1), `노션_회의록_v2.md`, PM 미팅(11/17), 목업 v3 피드백
- 데이터 구조: [`docs/ERD.md`](ERD.md)

API 총 **72개**. 11/18 팀 결정([ERD 8번](ERD.md#8-확정된-결정-1118)), 11/26 기준 백엔드 main 반영(이메일 인증·아이디/비밀번호 찾기·회원 탈퇴 A-23~A-31, 매장 폐업 C-20).

| 담당 | 영역 | 개수 |
| --- | --- | --- |
| A 회수 | 회원 · 파티 | 31 |
| B 송희 | 테마 · 매장 탐색 | 11 |
| C 승현 | 사장 · 관리자 | 20 |
| D 하나 | 기록 · 추천 | 10 |

- 번호는 v1과 다름. 옛 번호 대응은 [8. v1 → v3 번호 대응표](#8-v1--v3-번호-대응표) 참고.

## 목차

1. [공통 규칙](#1-공통-규칙)
2. [전체 목록](#2-전체-목록)
3. [역할군별 보기 (비회원 · 손님 · 사장 · 관리자)](#3-역할군별-보기)
4. [서버 구성](#4-서버-구성)
5. [상세 명세](#5-상세-명세)
   - [A · 회원](#a--회원-22), [A · 파티](#a--파티-11)
   - [B · 테마·매장 탐색](#b--테마매장-탐색-11)
   - [C · 사장](#c--사장-12), [C · 관리자](#c--관리자-8)
   - [D · 기록·추천](#d--기록추천-10)
6. [자동 작업 (스케줄러)](#6-자동-작업)
7. [화면별 호출 API](#7-화면별-호출-api)
8. [v1 → v3 번호 대응표](#8-v1--v3-번호-대응표)
9. [이번 범위에서 뺀 것](#9-이번-범위에서-뺀-것)

---

## 1. 공통 규칙

### 1-1. 주소와 요청 방식

- **서버 1개(모놀리식)**: `http://localhost:8081` (결정 D1). 프런트는 `js/common/api.js`의 주소로만 요청.
- **CORS**: `http://127.0.0.1:5500`, `http://localhost:5500` 기본 허용. 같은 와이파이의 다른 기기(IP 접속)는 각자 `application-local.properties`의 `app.cors.allowed-origins`에 추가.
- 프런트 `API_BASE`는 화면을 연 호스트의 8081 (`localhost`로 열면 내 PC, IP로 열면 그 PC).
- **주소 규칙**: `/api/` 뒤 소문자 복수 명사, 동작은 HTTP 메서드로 표현.
  - 사장 전용 `/api/owner/**`, 관리자 전용 `/api/admin/**`, 내 것 `/api/my/**`.
- **JSON 키**: camelCase.
- **닉네임**: 모든 API에서 MEMBER JOIN으로 내려 줌. 복사본 없음 → 닉네임 변경 시 모든 화면에 즉시 반영(결정 D2).

### 1-2. 날짜 형식

| 종류 | 형식 | 예 |
| --- | --- | --- |
| 날짜 | `yyyy-MM-dd` | `2026-11-20` |
| 일시 | `yyyy-MM-ddTHH:mm:ss` | `2026-11-20T19:00:00` |
| 시각 | `HH:mm` | `19:00` |

- 모두 한국 시간.

### 1-3. 로그인 토큰 (Access Token + Refresh Token)

**Access Token (JWT)**
- 로그인(A-6) 응답의 `token`을 `sessionStorage`에 저장.
- 이후 모든 요청 헤더에 `Authorization: Bearer {token}` 첨부.
- 토큰 내용: `memberId`, `nickname`, `role`. 유효 **30분**(`jwt.expiration-minutes=30`, 11/27 변경). 비밀번호 미포함.
  - v1의 `ownerType`은 사장 구분 폐지로 삭제.
- 회원번호는 **항상 토큰에서 추출.** 요청 본문·주소의 회원번호를 "나"로 신뢰 금지.

**Refresh Token (11/27 추가)**
- 로그인(A-6)·비밀번호 변경(A-9) 응답이 `Set-Cookie: refresh_token=…`으로 발급.
  - 쿠키 속성: `HttpOnly`(JS가 못 읽음), `SameSite=Strict`, `Path=/api/auth`, 만료 시각 없음(브라우저를 닫으면 사라짐). https일 때만 `Secure`.
  - 서버 유효 기간 **7일**(`jwt.refresh-days=7`). 원문은 쿠키에만, DB(REFRESH_TOKEN)에는 SHA-256 해시만 저장.
- Access Token이 끝나면 프런트가 A-32로 새 Access Token을 받음.
  - 요청 전에 만료(30초 여유)가 보이면 먼저 재발급, 401을 받으면 재발급 후 원래 요청을 한 번 더 보냄(`js/common/api.js`).
  - 동시에 여러 요청이 와도 재발급은 한 번만.
  - 재발급도 실패하면 토큰을 지우고 로그인 화면으로.
- **회전**: 재발급할 때마다 쓴 Refresh Token은 지우고 새로 발급. 한 번 쓴 토큰은 다시 401.
- **무효화**: 로그아웃(A-33)은 그 토큰만, 비밀번호 변경(A-9)·재설정(A-28)·탈퇴(A-31)는 그 회원의 토큰 전부.
- 쿠키를 주고받으려고 모든 요청을 `credentials: "include"`로 보내고, 서버 CORS는 `allowCredentials(true)` + 허용 주소 목록(`*` 불가).
- 인증 검사는 그대로 `AuthInterceptor`(Access Token)가 하고, A-32·A-33은 `@Auth` 없는 공개 API로 쿠키를 서비스에서 직접 확인. Spring Security는 쓰지 않음(BCrypt용 `spring-security-crypto`만).
- 탈퇴한 회원(A-31)의 토큰: 로그인 필요 API는 401 `다시 로그인해 주세요.`, 공개 API는 비회원으로 처리. 인터셉터가 요청마다 `withdrawn_at` 확인.

### 1-4. 권한 표기

| 표기 | 누구 | 서버가 하는 검사 |
| --- | --- | --- |
| 공개 | 누구나 | 토큰이 있으면 읽어서 `wished`, `mine` 같은 개인 값만 채움 |
| 로그인 | 로그인한 누구나 | 토큰 존재·유효 여부 |
| USER | 손님 | `role = USER` |
| OWNER | 사장 | `role = OWNER` |
| OWNER\* | 사장, 그리고 관리자(매장 관리) | `role IN (OWNER, ADMIN)`. 사장이면 **자기 매장·테마인지** 매번 확인. 관리자는 모든 매장 |
| ADMIN | 관리자 | `role = ADMIN` |
| 방장 / 참여자 / 작성자 | 그 데이터의 주인 | DB에서 확인. 화면에서 버튼을 숨겨도 서버가 재확인 |

**관리자 매장 관리 (OWNER\*)**

- 회의 v2-3 결정: 사장 미입점 매장이라도 손님 수요가 있으면 관리자가 매장·테마·시간표 등록 가능. 관리자도 사장 API를 그대로 사용.
- 관리자 호출 시 처리(ERD 결정 S3):
  - 소유 검사 생략. **사장이 등록한 매장도 조회·수정 가능**(관리자 개편 11/23, "매장 관리" 화면).
  - 관리자가 새로 등록한 매장: `owner_id = NULL`, `status = APPROVED`로 즉시 공개.
  - 관리자가 새로 등록한 테마: `source = ADMIN`, `status = OPEN`으로 즉시 공개.
  - 관리자가 수정한 매장·테마: **상태 유지**(사장 매장이어도 승인 대기로 되돌리지 않음. 이유: 승인 주체가 관리자).

### 1-5. 응답 형식

- **성공**: 데이터를 JSON으로 그대로 반환. 감싸는 껍데기 없음.
- **실패**: 상태 코드 + `{"message": "화면에 그대로 보여 줄 한국어 문장"}`.
- 응답에는 **DTO만** 사용. 엔티티 직접 반환 금지(비밀번호·파일 경로 노출 방지).

| 코드 | 언제 |
| --- | --- |
| 200 | 조회·수정 성공 |
| 201 | 등록 성공 |
| 204 | 삭제 성공 (본문 없음) |
| 400 | 보낸 값이 잘못됨 (형식, 길이, 범위, 규칙 위반) |
| 401 | 토큰이 없거나 틀리거나 만료됨, 로그인 실패 → 프런트는 A-32로 재발급 후 한 번 더 시도, 그래도 안 되면 로그인 화면으로 |
| 403 | 권한 없음 (역할 불일치, 남의 매장·파티·후기) |
| 404 | 없는 번호, 또는 손님에게 보이면 안 되는 상태(승인 전 테마 등) |
| 409 | 중복, 상태 충돌 (아이디 중복, 이미 찜함, 정원 다 참, 이미 처리됨) |
| 429 | 인증번호·아이디 찾기 메일을 60초 안에 다시 요청 (A-23, A-25, A-26, A-29) |
| 503 | 인증 메일 발송 실패 (SMTP 오류) |

### 1-6. 파일 올리기 (multipart)

- 파일 수신 API 5개: A-2, C-3, C-4, C-7, C-8.
- `multipart/form-data`로 수신. 프런트는 `api.upload(path, form, method)` 사용(`js/common/api.js`). `method` 생략 시 POST, 수정(C-4·C-8)은 `"PUT"`.
  - `Content-Type` 직접 지정 금지. 브라우저가 boundary 포함해 자동 지정(`api.upload`가 처리).
  - `api.upload`는 비어 있는 파일 칸을 빼고 전송(선택 파일 미선택 시 400 방지).
- 허용 이미지: jpg, png, webp, **5MB 이하**(한 요청 합계 12MB, `spring.servlet.multipart.max-request-size`). 확장자가 아니라 실제 파일 형식(시그니처)도 확인. 저장 이름은 UUID로 새로 생성([ERD 6](ERD.md#6-파일이미지-저장-규칙)).
- 사진은 공개 주소로 제공(결정 S5).
  - 테마 사진: `/uploads/posters/{파일}` (C-7, C-8에서 업로드)
  - 매장 사진: `/uploads/stores/{파일}` (C-3, C-4에서 업로드)
  - 응답의 `posterUrl`·`photoUrl`은 이 주소 그대로. 프런트가 서버 주소(`API_BASE`)를 앞에 붙여 사용.
  - 더미 데이터 사진 위치: 백엔드 `src/main/resources/uploads/posters/`, `…/uploads/stores/`. 같은 주소로 제공([ERD 6](ERD.md#6-파일이미지-저장-규칙)).
  - 사진이 없으면 `null`. 프런트가 장르 색 그라데이션으로 대체.
- 사업자등록증·사업장등록증은 **관리자 API(A-11, C-15)로만** 제공. 프런트는 `api.blob(path)`로 수신.

### 1-7. 보안 규칙 (모든 API 공통)

- SQL 값은 반드시 JPA 파라미터 바인딩(JPQL `:param`, Spring Data 메서드)으로 전달. 문자열 이어 붙이기로 SQL 생성 금지. 동적 검색(`ThemeBrowseRepository`, `PartyBrowseRepository`)도 `EntityManager` + 파라미터 바인딩.
- 사용자 입력 글(닉네임, 제목, 한마디, 채팅, 후기)은 프런트에서 **`textContent`로만** 출력.
- 링크 값(`bookingUrl`, `websiteUrl`)은 `http://`·`https://`로 시작하는지 서버가 확인(`javascript:` 링크 차단).
- 목록 API는 페이지 나누기 없이 전체 반환(이유: 데이터 소량). 채팅만 `after`로 분할 수신.

---

## 2. 전체 목록

| 번호 | 메서드 | 주소 | 기능 | 권한 | 성공 |
| --- | --- | --- | --- | --- | --- |
| **A-1** | POST | `/api/members/user` | 손님 회원가입 (+선호 장르) | 공개 | 201 |
| **A-2** | POST | `/api/members/owner` | 사장 회원가입 (+사업자등록증) (파일) | 공개 | 201 |
| **A-3** | GET | `/api/members/check-login-id?loginId=` | 아이디 중복 확인 | 공개 | 200 |
| **A-4** | GET | `/api/members/check-nickname?nickname=` | 닉네임 중복 확인 | 공개 | 200 |
| **A-5** | GET | `/api/members/check-biz-no?bizNo=` | 사업자등록번호 중복 확인 | 공개 | 200 |
| **A-6** | POST | `/api/auth/login` | 로그인 | 공개 | 200 |
| **A-7** | GET | `/api/members/me` | 내 정보 | 로그인 | 200 |
| **A-8** | PUT | `/api/members/me` | 닉네임 바꾸기 (새 토큰) | 로그인 | 200 |
| **A-9** | PUT | `/api/members/me/password` | 비밀번호 바꾸기 | 로그인 | 204 |
| **A-10** | GET | `/api/admin/members?keyword=&role=` | 회원 목록 | ADMIN | 200 |
| **A-11** | GET | `/api/admin/members/{memberId}/biz-file` | 사업자등록증 이미지 | ADMIN | 200 |
| **A-12** | GET | `/api/parties?genreIds=&keyword=&area=&region=&themeId=` | 파티 목록 (모집 중·정원 마감) | 공개 | 200 |
| **A-13** | GET | `/api/parties/{partyId}` | 파티 방 정보 | 방장·참여자 | 200 |
| **A-14** | POST | `/api/parties` | 파티 만들기 | USER | 201 |
| **A-15** | DELETE | `/api/parties/{partyId}` | 파티 삭제 | 방장 | 204 |
| **A-16** | POST | `/api/parties/{partyId}/join` | 참여 | USER | 201 |
| **A-17** | DELETE | `/api/parties/{partyId}/join` | 나가기 | 참여자(방장 제외) | 204 |
| **A-18** | DELETE | `/api/parties/{partyId}/members/{memberId}` | 강퇴 | 방장 | 204 |
| **A-19** | PUT | `/api/parties/{partyId}/close` | 모집 마감 | 방장 | 200 |
| **A-20** | GET | `/api/parties/{partyId}/messages?after=` | 새 채팅 받기 | 방장·참여자 | 200 |
| **A-21** | POST | `/api/parties/{partyId}/messages` | 채팅 보내기 | 방장·참여자 | 201 |
| **A-22** | GET | `/api/my/parties` | 내 채팅(내 파티) 목록 | USER | 200 |
| **A-23** | POST | `/api/members/email-code` | 가입 이메일 인증번호 받기 | 공개 | 204 |
| **A-24** | POST | `/api/members/email-code/verify` | 가입 이메일 인증번호 확인 | 공개 | 204 |
| **A-25** | POST | `/api/auth/find-id` | 아이디 찾기 (메일로 발송) | 공개 | 204 |
| **A-26** | POST | `/api/auth/password-reset/code` | 비밀번호 재설정 인증번호 받기 | 공개 | 204 |
| **A-27** | POST | `/api/auth/password-reset/verify` | 비밀번호 재설정 인증번호 확인 | 공개 | 204 |
| **A-28** | POST | `/api/auth/password-reset` | 새 비밀번호 저장 | 공개 | 204 |
| **A-29** | POST | `/api/members/me/email-code` | 내 이메일 등록·변경 인증번호 받기 | 로그인 | 204 |
| **A-30** | POST | `/api/members/me/email` | 내 이메일 등록·변경 | 로그인 | 204 |
| **A-31** | POST | `/api/members/me/withdraw` | 회원 탈퇴 | 로그인 (관리자 제외) | 204 |
| **A-32** | POST | `/api/auth/refresh` | Access Token 재발급 (Refresh Token 쿠키) | 공개(쿠키) | 200 |
| **A-33** | POST | `/api/auth/logout` | 로그아웃 (Refresh Token 삭제) | 공개(쿠키) | 204 |
| **B-1** | GET | `/api/themes?keyword=&area=&region=&date=&people=&genreId=&sort=` | 테마 목록·검색·필터 | 공개 | 200 |
| **B-2** | GET | `/api/themes/{themeId}` | 테마 상세 | 공개 | 200 |
| **B-3** | GET | `/api/themes/{themeId}/slots?date=` | 그날 시간표 | 공개 | 200 |
| **B-4** | POST | `/api/themes/{themeId}/wish` | 찜 | USER | 201 |
| **B-5** | DELETE | `/api/themes/{themeId}/wish` | 찜 취소 | USER | 204 |
| **B-6** | GET | `/api/my/wishes` | 찜 목록 | USER | 200 |
| **B-7** | GET | `/api/genres` | 장르 목록 | 공개 | 200 |
| **B-8** | GET | `/api/areas` | 지역 목록 | 공개 | 200 |
| **B-9** | GET | `/api/stores?area=&region=&keyword=&sort=` | 매장 목록 | 공개 | 200 |
| **B-10** | GET | `/api/stores/{storeId}` | 매장 상세 (+테마) | 공개 | 200 |
| ~~B-11~~ | | | 삭제 (지도는 매장 상세 B-10 좌표로 그림) | | |
| **B-12** | GET | `/api/regions` | 지역 전체 (큰 지역별 묶음, 매장 등록용) | 공개 | 200 |
| **C-1** | GET | `/api/owner/stores` | 내 매장 목록 | OWNER\* | 200 |
| **C-2** | GET | `/api/owner/stores/check-biz-place-no?bizPlaceNo=` | 사업장 관리번호 중복 확인 | OWNER\* | 200 |
| **C-3** | POST | `/api/owner/stores` | 매장 등록 (파일) | OWNER\* | 201 |
| **C-4** | PUT | `/api/owner/stores/{storeId}` | 매장 수정 (파일) | OWNER\*(내 매장) | 200 |
| **C-5** | GET | `/api/owner/stores/{storeId}/themes` | 매장의 테마 목록 | OWNER\*(내 매장) | 200 |
| **C-6** | GET | `/api/owner/themes/{themeId}` | 테마 수정용 상세 | OWNER\*(내 테마) | 200 |
| **C-7** | POST | `/api/owner/themes` | 테마 등록 (파일) | OWNER\*(내 매장) | 201 |
| **C-8** | PUT | `/api/owner/themes/{themeId}` | 테마 수정 (파일) | OWNER\*(내 테마) | 200 |
| **C-9** | PUT | `/api/owner/themes/{themeId}/status` | 운영 종료·재개 | OWNER\*(내 테마) | 200 |
| **C-10** | GET | `/api/owner/themes/{themeId}/slots` | 주중/주말 시간표 보기 | OWNER\*(내 테마) | 200 |
| **C-11** | PUT | `/api/owner/themes/{themeId}/slots` | 주중/주말 시간표 저장 (통째 교체) | OWNER\*(내 테마) | 200 |
| **C-20** | PUT | `/api/owner/stores/{storeId}/close` | 매장 폐업 | OWNER\*(내 매장) | 200 |
| **C-12** | GET | `/api/admin/summary` | 관리자 홈 숫자 요약 | ADMIN | 200 |
| **C-13** | GET | `/api/admin/stores?status=` | 매장 승인 목록 | ADMIN | 200 |
| **C-14** | GET | `/api/admin/stores/{storeId}` | 매장 승인 상세 | ADMIN | 200 |
| **C-15** | GET | `/api/admin/stores/{storeId}/biz-place-file` | 사업장등록증 이미지 | ADMIN | 200 |
| **C-16** | PUT | `/api/admin/stores/{storeId}/approval` | 매장 승인·반려 | ADMIN | 200 |
| **C-17** | GET | `/api/admin/themes?status=` | 테마 승인 목록 | ADMIN | 200 |
| **C-18** | GET | `/api/admin/themes/{themeId}` | 테마 승인 상세 | ADMIN | 200 |
| **C-19** | PUT | `/api/admin/themes/{themeId}/approval` | 테마 승인·반려 | ADMIN | 200 |
| **D-1** | POST | `/api/reviews` | 후기 쓰기 | USER | 201 |
| **D-2** | PUT | `/api/reviews/{reviewId}` | 후기 수정 | 작성자 | 200 |
| **D-3** | DELETE | `/api/reviews/{reviewId}` | 후기 삭제 | 작성자 | 204 |
| **D-4** | GET | `/api/themes/{themeId}/reviews` | 테마 후기 + 평균 | 공개 | 200 |
| **D-5** | GET | `/api/my/reviews` | 내 기록 | USER | 200 |
| **D-6** | GET | `/api/my/review-candidates` | 후기 쓸 수 있는 테마 | USER | 200 |
| **D-7** | GET | `/api/my/genres` | 내 선호 장르 | USER | 200 |
| **D-8** | PUT | `/api/my/genres` | 선호 장르 저장 (통째 교체) | USER | 200 |
| **D-9** | GET | `/api/my/recommendations` | 맞춤 추천 (메인 배너) | USER | 200 |
| **D-10** | GET | `/api/my/stats` | 내 통계 (선택 기능) | USER | 200 |

(파일) = `multipart/form-data` (파일 포함). [1-6](#1-6-파일-올리기-multipart) 참고.

---

## 3. 역할군별 보기

- 같은 API가 여러 역할에 중복 표기될 수 있음. 권한 기준은 [2. 전체 목록](#2-전체-목록).

### 비회원 (로그인 전)

| 하는 일 | API |
| --- | --- |
| 가입 | A-1 손님 가입, A-2 사장 가입, A-3·A-4·A-5 중복 확인, A-23·A-24 이메일 인증 |
| 로그인 | A-6 로그인, A-32 로그인 유지(재발급) |
| 계정 찾기 | A-25 아이디 찾기, A-26·A-27·A-28 비밀번호 재설정 |
| 테마 구경 | B-1 목록·검색·필터, B-2 상세, B-3 시간표, B-7 장르, B-8 지역, D-4 후기 |
| 매장 구경 | B-9 매장 목록, B-10 매장 상세 (지도 포함) |
| 파티 구경 | A-12 파티 목록 (참여는 로그인 필요) |

### 손님 (USER)

- 비회원 기능 전체 + 아래 기능.

| 하는 일 | API |
| --- | --- |
| 내 정보 | A-7 보기, A-8 닉네임, A-9 비밀번호, A-29·A-30 이메일, A-31 탈퇴, A-33 로그아웃, D-7·D-8 선호 장르 |
| 파티 | A-12 목록, A-14 만들기, A-16 참여, A-13 방 정보, A-20·A-21 채팅, A-17 나가기, A-22 내 채팅 목록 |
| 파티 방장 | A-15 삭제, A-18 강퇴, A-19 모집 마감 |
| 찜 | B-4 찜, B-5 취소, B-6 찜 목록 |
| 후기 | D-1 쓰기, D-2 수정, D-3 삭제, D-5 내 기록, D-6 쓸 수 있는 테마 |
| 추천·통계 | D-9 맞춤 추천, D-10 통계 |

### 사장 (OWNER)

| 하는 일 | API |
| --- | --- |
| 내 정보 | A-7, A-8, A-9, A-29·A-30 이메일, A-31 탈퇴 (운영 중인 매장이 없을 때만), A-33 로그아웃 |
| 매장 | C-1 내 매장, C-2 번호 중복 확인, B-12 지역 목록, C-3 등록, C-4 수정, C-20 폐업 |
| 테마 | C-5 매장의 테마, C-6 수정용 상세, C-7 등록, C-8 수정, C-9 운영 종료·재개, B-7 장르 |
| 시간표 | C-10 보기, C-11 저장 |

### 관리자 (ADMIN)

| 하는 일 | API |
| --- | --- |
| 관리자 홈 | C-12 숫자 요약(회원 수 `memberCountByRole` 포함), C-13·C-17 처리할 목록 |
| 매장 승인 | C-13 목록, C-14 상세, C-15 사업장등록증, A-11 사장 사업자등록증, C-16 승인·반려 |
| 테마 승인 | C-17 목록, C-18 상세, C-19 승인·반려 |
| 회원 관리 | A-10 목록·검색·역할 필터 |
| 매장 관리 | C-1 ~ C-11, C-20을 관리자 권한으로 사용 ([1-4](#1-4-권한-표기)). 승인 매장 + 폐업 매장 |

---

## 4. 서버 구성

- **서버 1개(모놀리식)** 확정(결정 D1).
- 모든 API를 `:8081` 하나에서 수신. (8080은 Oracle XE 자체 웹서버 사용 중이라 회피)
- 모든 테이블이 한 DB에 존재. 회원번호 컬럼도 모두 실제 FK.
  - 닉네임은 MEMBER JOIN.
  - 가입 시 선호 장르도 같은 트랜잭션으로 저장.
  - 관리자 화면의 사장 정보도 JOIN으로 한 번에 제공.

## 5. 상세 명세

API별 정리 순서:

- **요청**: 보내는 값과 규칙
- **응답**: 예시
- **처리 순서와 규칙**: 서버 검사 항목과 트랜잭션
- **오류**: 실패 시 상태 코드와 메시지

- 본문 표의 "필수" 칸: `Y` = 필수.

---

### A · 회원 (22)

#### A-1. 손님 회원가입

`POST /api/members/user` · 공개 · 201 · 화면 S03-1 `signup-user.html`

| 본문 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| loginId | string | Y | 영문 소문자·숫자 4~20자 |
| password | string | Y | 4~20자 (더미 계정 `1234`에 맞춤. 길이 규칙은 팀이 정하기) |
| nickname | string | Y | 2~20자. `탈퇴한 회원` 사용 불가 |
| email | string | Y | A-23·A-24로 인증 완료한 이메일. 앞뒤 공백 제거 후 형식 검사, 100자 이내, 소문자로 저장 |
| genreIds | number[] | | 좋아하는 장르. 없으면 빈 배열 |

- 인증 완료 후 30분 안에 가입해야 함. 가입 완료 시 인증 기록 삭제.
- **비밀번호 확인 칸**은 화면(JS)에서만 비교. 서버로 전송하지 않음.
- 아이디·닉네임 중복 확인(A-3, A-4)을 거쳤어도 가입 시 서버가 **재확인**.

```json
// 요청
{ "loginId": "user9", "password": "1234", "nickname": "새회원", "email": "user9@example.com", "genreIds": [1, 2] }
// 응답 201
{ "memberId": 12 }
```

**처리 순서와 규칙**
1. 값 검사, 비밀번호 BCrypt 변환.
2. **한 트랜잭션**에서 MEMBER(`role = USER`)와 MEMBER_GENRE(고른 장르 수만큼) 저장.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `아이디는 영문 소문자와 숫자 4~20자로 입력해 주세요.` / `없는 장르입니다.` / `이메일 인증을 먼저 해 주세요.` |
| 409 | `이미 사용 중인 아이디입니다.` / `이미 사용 중인 닉네임입니다.` / `이미 가입된 이메일입니다.` |

#### A-2. 사장 회원가입 (multipart)

`POST /api/members/owner` · 공개 · 201 · 화면 S03-2 `signup-owner.html`

| 폼 칸 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| loginId | text | Y | A-1과 같음 |
| password | text | Y | A-1과 같음 |
| nickname | text | Y | 손님에게 보이는 이름. 2~20자 |
| email | text | Y | A-1과 같음 (인증 완료 이메일) |
| bizNo | text | Y | 사업자 등록번호 `^\d{3}-\d{2}-\d{5}$` |
| bizFile | file | Y | 사업자등록증 이미지 jpg/png/webp, 5MB 이하 |

```json
// 응답 201
{ "memberId": 13 }
```

**처리 순서와 규칙**
1. 값과 파일 검사.
2. 파일을 `private/biz/UUID.ext`에 저장.
3. MEMBER에 `role = OWNER`, `biz_no`, `biz_file_path` 저장.
4. DB 저장 실패 시 **저장한 파일 삭제.**

- 가입 즉시 로그인 가능. 승인은 매장 단위(ERD 결정 M1).

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `사업자 등록번호 형식이 올바르지 않습니다.` / `이미지 파일(jpg, png, webp)만 올릴 수 있습니다.` / `파일은 5MB까지 올릴 수 있습니다.` |
| 409 | 아이디·닉네임·이메일 중복 / `이미 등록된 사업자 등록번호입니다.` |

#### A-3 / A-4 / A-5. 중복 확인

| 번호 | 주소 | 쿼리 | 화면 |
| --- | --- | --- | --- |
| A-3 | `GET /api/members/check-login-id` | `loginId` | 손님·사장 가입 |
| A-4 | `GET /api/members/check-nickname` | `nickname` | 가입, 내 정보(닉네임 변경) |
| A-5 | `GET /api/members/check-biz-no` | `bizNo` | 사장 가입 |

```json
// 응답 200
{ "available": true }
```

- 형식 오류: 400. 이미 존재: 400이 아닌 `available: false`.

#### A-6. 로그인

`POST /api/auth/login` · 공개 · 200 · 화면 S02 `login.html`

```json
// 요청
{ "loginId": "user1", "password": "1234" }
// 응답 200
{ "token": "eyJhbGciOi...", "memberId": 4, "nickname": "탈출왕", "role": "USER" }
```

- 로그인 화면 1개. 프런트가 응답 `role`로 이동 화면 결정.
- 응답 헤더로 Refresh Token 쿠키도 발급(`Set-Cookie: refresh_token=…; HttpOnly; SameSite=Strict; Path=/api/auth`). [1-3](#1-3-로그인-토큰-access-token--refresh-token) 참고.

| role | 이동할 화면 |
| --- | --- |
| USER | 메인 `index.html` |
| OWNER | 사장 홈 `owner.html` |
| ADMIN | 관리자 홈 `admin.html` |

- v1의 "정지 회원 403" 삭제(회의 v2-9).

| 오류 | 메시지 |
| --- | --- |
| 401 | `아이디 또는 비밀번호가 틀렸습니다.` (아이디 없음·비밀번호 틀림을 같은 문장으로) |

#### A-7. 내 정보

`GET /api/members/me` · 로그인 · 200 · 화면 S26 `profile.html`

```json
// 응답 200 (손님)
{ "memberId": 4, "loginId": "user1", "nickname": "탈출왕", "email": "user1@example.com", "role": "USER", "createdAt": "2026-11-16T10:00:00" }
// 응답 200 (사장)
{ "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대", "email": null, "role": "OWNER", "bizNo": "111-22-33333", "createdAt": "2026-11-16T10:00:00" }
```

- 선호 장르는 D-7로 별도 조회.
- `email`: 이메일 칸 추가(11/24) 전 가입 회원은 `null`. A-29·A-30으로 등록 가능.

#### A-8. 닉네임 바꾸기

`PUT /api/members/me` · 로그인 · 200 · 화면 S26 기본 정보 칸

```json
// 요청
{ "nickname": "탈출의신" }
// 응답 200
{ "nickname": "탈출의신", "token": "eyJ...새 토큰" }
```

- 토큰에 닉네임 포함 → 변경 시 **새 토큰** 발급. 프런트는 `sessionStorage`의 토큰 교체.
- 후기·파티·채팅은 닉네임을 MEMBER JOIN으로 표시 → **과거 기록도 모두 새 닉네임으로** 표시(결정 D2).

| 오류 | 메시지 |
| --- | --- |
| 400 | 길이 위반 |
| 409 | `이미 사용 중인 닉네임입니다.` |

#### A-9. 비밀번호 바꾸기

`PUT /api/members/me/password` · 로그인 · 204 · 화면 S26 비밀번호 변경 칸

```json
{ "currentPassword": "1234", "newPassword": "5678" }
```

- 현재 비밀번호를 BCrypt로 비교.
- 틀려도 **400** 응답(401이면 프런트가 로그아웃 처리하므로).
- 새 비밀번호가 현재 비밀번호와 같으면 400.
- "새 비밀번호 확인" 칸은 화면에서만 비교.
- 바꾸면 이 회원의 Refresh Token을 모두 지움(다른 기기 로그아웃). 지금 브라우저에는 새 Refresh Token 쿠키를 발급해 로그인 유지(11/27).

| 오류 | 메시지 |
| --- | --- |
| 400 | `현재 비밀번호가 맞지 않습니다.` / `지금 비밀번호와 다른 비밀번호를 입력해 주세요.` |

#### A-10. 회원 목록 (관리자)

`GET /api/admin/members?keyword=&role=` · ADMIN · 200 · 화면 S07 `admin-members.html`

| 쿼리 | 설명 |
| --- | --- |
| keyword | 아이디·닉네임 일부 (없으면 전체) |
| role | `USER` / `OWNER` (없으면 전체). 화면의 역할 탭 |

```json
{
  "total": 8,
  "countByRole": { "USER": 5, "OWNER": 3, "ADMIN": 1 },
  "members": [
    { "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대", "role": "OWNER",
      "bizNo": "111-22-33333", "managedStoreCount": 2, "createdAt": "2026-11-16T10:00:00",
      "stores": [ { "storeId": 1, "name": "미스터리룸 홍대점", "status": "APPROVED" },
                  { "storeId": 9, "name": "미스터리룸 합정점", "status": "PENDING" } ] },
    { "memberId": 4, "loginId": "user1", "nickname": "탈출왕", "role": "USER",
      "bizNo": null, "managedStoreCount": null, "createdAt": "2026-11-16T10:00:00", "stores": null }
  ]
}
```

- `countByRole`: keyword·role 조건과 무관한 전체 수. 역할 탭 숫자용.
- 탈퇴 회원(`withdrawn_at` 있음)은 목록·`countByRole`에서 제외.
- `managedStoreCount`: 사장의 매장 수(STORE JOIN). 상태 무관.
- `stores`: 사장의 매장 목록(등록 순). 회원 관리에서 "매장 N곳 ▾" 클릭 시 해당 줄 아래에 표시. 사장이 아니면 `null`.
- 회원 정지·해제 API(v1 A-6) **없음**.

#### A-11. 사업자등록증 이미지 (관리자)

`GET /api/admin/members/{memberId}/biz-file` · ADMIN · 200 · 화면 S23 매장 승인 상세

- 응답은 JSON이 아닌 **이미지 자체**. `Content-Type: image/png` 등.
- 토큰 첨부가 필요해 `<img src>`에 주소 직접 지정 불가. 프런트는 `api.blob(path)`로 받아 `URL.createObjectURL(blob)`로 표시.

| 오류 | 언제 |
| --- | --- |
| 404 | 사장이 아니거나 파일이 없음 |

#### 이메일 인증 공통 규칙 (A-23 ~ A-30)

- 인증번호: 숫자 6자리, 발급 후 5분 유효, 5회 오답 시 무효(재발급 필요).
- 같은 대상에 60초 안에 재요청 시 429 `인증번호는 N초 뒤에 다시 받을 수 있어요.`
- 인증 기록은 서버 메모리(`EmailCodeStore`)에 보관. DB 테이블 없음. 서버 재시작 시 초기화.
- 메일: Gmail SMTP(`spring-boot-starter-mail`). 계정은 `application-local.properties`의 `spring.mail.username`·`spring.mail.password`. 계정이 없으면 메일 대신 서버 콘솔에 인증번호 출력(개발 모드).
- 이메일은 앞뒤 공백 제거 후 형식·길이(100자) 검사, 소문자로 저장·비교.

| 공통 오류 | 메시지 |
| --- | --- |
| 400 | `이메일 형식이 올바르지 않습니다.` / `이메일은 100자 이내로 입력해 주세요.` / `인증번호가 맞지 않아요. (n/5)` / `인증번호를 5번 틀렸어요. 인증번호를 다시 받아 주세요.` / `인증번호가 만료됐어요. 인증번호를 다시 받아 주세요.` |
| 429 | `인증번호는 N초 뒤에 다시 받을 수 있어요.` |
| 503 | `메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요.` |

#### A-23. 가입 이메일 인증번호 받기

`POST /api/members/email-code` · 공개 · 204 · 화면 `signup-user.html`, `signup-owner.html`

```json
{ "email": "user9@example.com" }
```

- 이미 가입된 이메일이면 409 `이미 가입된 이메일입니다.`

#### A-24. 가입 이메일 인증번호 확인

`POST /api/members/email-code/verify` · 공개 · 204

```json
{ "email": "user9@example.com", "code": "482913" }
```

- 성공 시 해당 이메일을 30분간 인증 완료 상태로 보관. 이 시간 안에 A-1·A-2 호출 필요.

#### A-25. 아이디 찾기

`POST /api/auth/find-id` · 공개 · 204 · 화면 `find-id.html`

```json
{ "email": "user1@example.com" }
```

- 해당 이메일로 가입한 회원의 아이디를 메일로 발송. 화면에는 아이디 미표시.
- 메일은 응답을 기다리지 않고 비동기 발송.

| 오류 | 메시지 |
| --- | --- |
| 404 | `입력한 이메일로 가입한 계정이 없습니다.` (11/25 변경. 이전에는 계정 유무와 무관하게 204) |
| 429 | 60초 안에 재요청 |

#### A-26 / A-27 / A-28. 비밀번호 재설정

- 화면 `find-password.html`. 아이디 + 가입 이메일 인증 → 새 비밀번호 순서.

| 번호 | 주소 | 본문 | 규칙 |
| --- | --- | --- | --- |
| A-26 | `POST /api/auth/password-reset/code` | `{ "loginId", "email" }` | 아이디·이메일 조합이 맞을 때만 인증번호 메일 발송. 틀리면 400 `아이디 또는 이메일이 올바르지 않습니다.` (11/25 변경) |
| A-27 | `POST /api/auth/password-reset/verify` | `{ "loginId", "email", "code" }` | 인증번호 확인. 공통 규칙과 같음 |
| A-28 | `POST /api/auth/password-reset` | `{ "loginId", "email", "newPassword" }` | A-27 완료 건만 처리. 새 비밀번호 4~20자. 완료 시 인증 기록 삭제, 이 회원의 Refresh Token 모두 삭제(11/27). 미인증이면 400 `이메일 인증을 먼저 해 주세요.` |

- 인증 기록은 (아이디, 이메일) 쌍 단위로 관리. 60초·5회·5분 규칙은 A-23과 같음.
- 이메일이 없는 기존 회원은 A-30으로 이메일 등록 후 사용 가능.

#### A-29 / A-30. 내 이메일 등록·변경

- 화면 S26 `profile.html` 이메일 팝업.

| 번호 | 주소 | 본문 | 규칙 |
| --- | --- | --- | --- |
| A-29 | `POST /api/members/me/email-code` | `{ "email" }` | 새 이메일로 인증번호 발송. 현재 이메일과 같으면 400 `지금 쓰고 있는 이메일이에요.`, 다른 회원이 사용 중이면 409 `이미 가입된 이메일입니다.` |
| A-30 | `POST /api/members/me/email` | `{ "email", "code" }` | 인증번호가 맞으면 즉시 변경. 같은 인증으로 두 번 변경 불가 |

#### A-31. 회원 탈퇴

`POST /api/members/me/withdraw` · 로그인 · 204 · 화면 S26 `profile.html`

```json
{ "password": "1234" }
```

**처리 순서와 규칙** (한 트랜잭션)
1. 비밀번호 재확인.
2. 안 끝난 파티 정리: 방장이면 삭제(`DELETED`), 참여자면 나가기(안내 줄 `LEAVE`, `FULL`이면 `RECRUITING` 복귀). 끝난 파티 기록은 유지.
3. 찜(WISHLIST), 선호 장르(MEMBER_GENRE) 삭제.
4. MEMBER 행은 삭제하지 않고 익명화: `login_id = 'withdrawn#{memberId}'`, `nickname = '탈퇴한 회원'`, `email`·`biz_no`·`biz_file_path` NULL, 비밀번호는 임의 값, `withdrawn_at = 현재`.
5. Refresh Token 모두 삭제(11/27).
6. 사업자등록증 파일은 커밋 후 삭제.

**사장 탈퇴 (11/26 변경)**
- 운영 중(`APPROVED`) 매장이 있으면 409. 먼저 C-20으로 폐업해야 함.
- 승인 대기(`PENDING`)·반려(`REJECTED`) 매장은 탈퇴하면서 함께 폐업(`CLOSED`), 그 매장의 테마도 모두 `CLOSED`.
  - 이유: 폐업(C-20)은 승인된 매장만 가능해서, 이렇게 하지 않으면 대기·반려 매장만 있는 사장은 탈퇴할 방법이 없음.
- 이미 폐업한 매장은 막지 않음.

- 후기·지난 채팅은 "탈퇴한 회원"으로 남음.
- 같은 아이디·이메일·닉네임으로 재가입 가능.
- 탈퇴 직후 기존 토큰은 무효 처리([1-3](#1-3-로그인-토큰-access-token--refresh-token)).

| 오류 | 메시지 |
| --- | --- |
| 400 | `비밀번호가 맞지 않아요.` |
| 403 | `관리자 계정은 탈퇴할 수 없어요.` |
| 409 | `운영 중인 매장이 있어서 탈퇴할 수 없어요. 매장을 먼저 폐업해 주세요.` (사장: `APPROVED` 매장 1개 이상) |

#### A-32. Access Token 재발급

`POST /api/auth/refresh` · 공개(쿠키) · 200 · 화면 없음 (`js/common/api.js`가 자동 호출)

- 본문 없음. `refresh_token` 쿠키로만 받음.
- 쿠키의 토큰을 해시로 찾아 확인 → **지우고 새로 발급**(회전) → 새 쿠키 + 새 Access Token.
- 새 Access Token은 DB의 지금 닉네임·역할로 다시 만듦.

```json
// 응답 200 (A-6 로그인과 같은 모양) + Set-Cookie: refresh_token=새 값
{ "token": "eyJhbGciOi...", "memberId": 4, "nickname": "탈출왕", "role": "USER" }
```

| 오류 | 메시지 |
| --- | --- |
| 401 | `로그인이 만료되었습니다. 다시 로그인해 주세요.` (쿠키 없음, DB에 없음(이미 씀·로그아웃·비밀번호 변경), 7일 지남, 탈퇴 회원). 실패하면 쿠키도 지움 |

#### A-33. 로그아웃

`POST /api/auth/logout` · 공개(쿠키) · 204 · 헤더 프로필 메뉴 [로그아웃]

- 쿠키의 Refresh Token을 DB에서 지우고 쿠키도 지움. 쿠키가 없어도 204.
- Access Token은 프런트가 `sessionStorage`에서 지움(서버는 만료 전 Access Token을 따로 막지 않음. 최대 30분).

---

### A · 파티 (11)

**공통 규칙**
- **현재 인원** = PARTY_MEMBER 중 `status = 'JOINED'` 줄 수(방장 포함). 강퇴(`KICKED`) 줄은 제외.
- **삭제된 파티(`DELETED`)**: 모든 파티 API에서 없는 파티로 취급(404). 실제 삭제 없이 상태만 변경(결정 P1).
- 인원·상태를 바꾸는 API(참여, 나가기, 강퇴, 마감, 삭제)는 PARTY 행을 **잠근 상태로** 처리.
  - 잠금 방법: `SELECT … FOR UPDATE`, JPA는 `@Lock(PESSIMISTIC_WRITE)`
  - 목적: 마지막 자리 동시 점유 방지.
- 파티 만들기·참여·나가기·강퇴 시 채팅 **안내 줄**(PARTY_MESSAGE `msg_type`) 1줄을 같은 트랜잭션에서 저장(결정 P3).

#### A-12. 파티 목록 (모집 중·정원 마감)

`GET /api/parties?genreIds=&keyword=&area=&region=&themeId=` · 공개 · 200 · 화면 S04 `party-list.html`

| 쿼리 | 설명 |
| --- | --- |
| genreIds | 장르 번호 여러 개 `1,2`. **하나라도** 맞는 테마의 파티 |
| keyword | 테마 이름 일부. 띄어쓰기 무시 |
| area | 세부 지역 이름(B-8 값). 매장 `area` 기준 |
| region | 큰 지역 이름(서울·경기 등). 그 안의 모든 세부 지역. `area`가 있으면 `area` 우선 |
| themeId | 메인·테마 상세·매장 상세의 "파티 보기"로 진입할 때 |

- 비회원도 조회 가능(11/20 변경). 로그인 시에만 `joined`·`kicked` 값 채움, 비회원은 둘 다 `false`.
- 목록 조건: `status IN (RECRUITING, FULL)` 이고 `deadline_at > SYSDATE`, 테마 `OPEN`이고 매장 `APPROVED`.
  - 정원 마감(`FULL`) 파티도 기한 전까지 표시(11/23 변경). 화면은 노란 배지, 클릭 시 안내만.
  - 운영 종료 테마·폐업 매장의 파티는 제외(11/25). 요청 시점 상태로 판단하므로 운영 재개 시 즉시 복귀.
- 정렬: **가까운 일정순**(`play_at` 오름차순).
  - 화면은 참여 가능(모집 중) → 참여 중 → 참여 불가(정원 마감·강퇴) 순으로 재정렬(`js/party/party-list.js`).

```json
[
  {
    "partyId": 1, "title": "인형의 집 같이 가실 분 (추리 좋아하는 분)",
    "intro": "추리 위주로 차분하게 푸는 팀 원해요. 공포는 제가 앞장설게요!",
    "themeId": 1, "themeTitle": "저주받은 인형의 집", "posterUrl": "/uploads/posters/horror-01.jpg",
    "storeName": "미스터리룸 홍대점", "genres": ["공포", "추리"],
    "playAt": "2026-11-20T19:00:00", "deadlineAt": "2026-11-19T18:00:00",
    "currentPeople": 2, "maxPeople": 4, "leaderNickname": "추리덕후",
    "status": "RECRUITING", "joined": false, "kicked": false
  }
]
```

| 필드 | 뜻 | 프런트 처리 |
| --- | --- | --- |
| `joined` | 내가 `JOINED`인 파티 | 참여 확인 팝업 없이 바로 파티 방(A-13)으로 이동 |
| `posterUrl` | 테마 포스터 (없으면 `null`) | 카드 왼쪽 작은 포스터. 없으면 장르 색 + 첫 글자 (11/27) |
| `kicked` | 내가 강퇴된 파티 | 배너 흐리게 + `강퇴됨` 배지, 클릭 시 토스트 `강퇴된 파티에는 다시 참여할 수 없어요.` (결정 P2) |

- `leaderNickname`: MEMBER JOIN으로 채움.
- 장르 조건: THEME_GENRE에 `EXISTS`로 필터(장르 여러 개에 걸린 파티의 중복 노출 방지).

#### A-13. 파티 방 정보

`GET /api/parties/{partyId}` · 방장·참여자 · 200 · 화면 S06 `party-room.html`

```json
{
  "partyId": 1, "title": "인형의 집 같이 가실 분 (추리 좋아하는 분)",
  "intro": "추리 위주로 차분하게 푸는 팀 원해요. 공포는 제가 앞장설게요!",
  "status": "RECRUITING",
  "theme": { "themeId": 1, "title": "저주받은 인형의 집", "storeName": "미스터리룸 홍대점", "playMinutes": 70, "open": true },
  "playAt": "2026-11-20T19:00:00", "deadlineAt": "2026-11-19T18:00:00",
  "maxPeople": 4, "currentPeople": 2,
  "members": [
    { "memberId": 4, "nickname": "탈출왕", "leader": true,  "joinedAt": "2026-11-17T09:00:00" },
    { "memberId": 5, "nickname": "힌트없이", "leader": false, "joinedAt": "2026-11-17T09:05:00" }
  ],
  "myRole": "LEADER"
}
```

- `members`: `JOINED`인 사람만. 닉네임은 JOIN으로 채움.
- `myRole`: `LEADER` 또는 `MEMBER`. 프런트가 이 값으로 버튼 전환.
  - 방장: 강퇴, 모집 마감, 파티 삭제
  - 참여자: 나가기
- 미참여자·강퇴자가 주소로 직접 접근 시 403. 프런트는 파티 목록으로 이동.
- `theme.open`: 테마 `OPEN`이고 매장 `APPROVED`이면 `true`. `false`(운영 종료·폐업)이면 방 상단에 안내, 테마 상세 링크 미표시. 이미 참여한 사람의 방·채팅·나가기는 그대로 가능.

| 오류 | 언제 |
| --- | --- |
| 403 | `파티에 참여한 사람만 볼 수 있습니다.` |
| 404 | 없는 파티, 또는 삭제된(`DELETED`) 파티 |

#### A-14. 파티 만들기

`POST /api/parties` · USER · 201 · 화면 S05 `party-form.html`

| 본문 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| themeId | number | Y | OPEN 테마 (매장 APPROVED) |
| title | string | Y | 1~100자 |
| intro | string | Y | **방장 한마디** 1~100자. 목록 배너에 표시 |
| playAt | datetime | Y | 현재 이후. 그날 유형(주중/주말) 시간표에 있는 시각 |
| deadlineAt | datetime | Y | 현재 이후, playAt 이전 또는 같음 |
| maxPeople | number | Y | 2 이상, 테마 `min_people` ~ `max_people` 범위 |

```json
// 요청
{ "themeId": 1, "title": "인형의 집 같이 가실 분", "intro": "추리 위주로 차분하게 푸는 팀 원해요.",
  "playAt": "2026-11-20T19:00:00", "deadlineAt": "2026-11-19T18:00:00", "maxPeople": 4 }
// 응답 201
{ "partyId": 7 }
```

**처리 순서와 규칙**
1. 값 검사.
   - **시간표 검사**: playAt 날짜가 토·일·공휴일(HOLIDAY)이면 `WEEKEND`, 나머지 `WEEKDAY`. 이후 TIME_SLOT에 (theme_id, day_type, `HH:mm`) 존재 여부 확인.
2. **한 트랜잭션**에서 PARTY, PARTY_MEMBER(방장, `JOINED`), PARTY_MESSAGE 안내 줄(`JOIN`) 저장.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `오늘 이후 날짜만 고를 수 있습니다.` / `그 시간에는 이 테마 시간표가 없습니다.` / `모집 기한은 플레이 시간 전이어야 합니다.` / `모집 인원은 2~4명 사이로 정해 주세요.` (숫자는 테마 인원 범위) |
| 404 | 없는 테마, 또는 공개되지 않은 테마 |

#### A-15. 파티 삭제

`DELETE /api/parties/{partyId}` · 방장 · 204 · 화면 S06 방장 버튼

- **실제 삭제 없음.** `status = 'DELETED'`로만 변경(결정 P1). 참여자·채팅 기록은 DB에 유지.
- 삭제된 파티는 파티 목록(A-12), 파티 방(A-13), 채팅(A-20·A-21), 내 채팅 목록(A-22) 어디에도 미표시.
- `RECRUITING`, `FULL`, `CLOSED` 어느 상태든 삭제 가능.
- HTTP 메서드는 화면 동작에 맞춰 `DELETE` 사용.

| 오류 | 언제 |
| --- | --- |
| 403 | 방장이 아님 |
| 404 | 없는 파티, 또는 이미 삭제된 파티 |

#### A-16. 참여

`POST /api/parties/{partyId}/join` · USER · 201 · 화면 S04 참여 확인 팝업의 "예"

```json
// 응답 201
{ "partyId": 2, "currentPeople": 2, "maxPeople": 3, "status": "RECRUITING" }
```

**처리 순서와 규칙** (PARTY 행 잠금 상태)
1. 파티 상태 확인: `status = RECRUITING`이고 `deadline_at > SYSDATE`.
2. 내 PARTY_MEMBER 줄 확인.
   - `JOINED`: 409 (이미 참여)
   - **`KICKED`: 409 (강퇴자 재참여 불가, 결정 P2)**
   - 줄 없음: 계속 진행. 스스로 나간 사람은 줄이 삭제된 상태라 재참여 가능.
3. 현재 인원(`JOINED` 수)이 정원 미만인지 확인.
4. PARTY_MEMBER(`JOINED`)와 안내 줄(`JOIN`) 저장.
5. 저장 후 인원이 정원과 같으면 `status = FULL`.

- 프런트: 성공 시 파티 방(`party-room.html?id=`)으로 이동. 409 시 메시지 표시 후 목록 유지.

| 오류 | 메시지 예 |
| --- | --- |
| 404 | 없는 파티, 또는 삭제된 파티 |
| 409 | `이미 참여한 파티입니다.` / `강퇴된 파티에는 다시 참여할 수 없습니다.` / `정원이 다 찼습니다.` / `모집이 끝난 파티입니다.` / `운영이 종료된 테마라 참여할 수 없습니다.` (테마 운영 종료·매장 폐업) |

#### A-17. 나가기 (참여 취소)

`DELETE /api/parties/{partyId}/join` · 참여자(방장 제외) · 204 · 화면 S06 참여자 버튼

**처리 순서와 규칙** (PARTY 행 잠금 상태)
1. 내 PARTY_MEMBER 줄 **삭제**(이후 재참여 가능).
2. 안내 줄(`LEAVE`) 저장.
3. 파티가 `FULL`이었고 `deadline_at > SYSDATE`면 `RECRUITING`으로 복귀.

- 파티와 채팅방에서 동시에 빠짐.

| 오류 | 메시지 |
| --- | --- |
| 400 | `방장은 나갈 수 없습니다. 파티를 삭제해 주세요.` |
| 404 | 참여하지 않은 파티, 또는 삭제된 파티 |

#### A-18. 강퇴

`DELETE /api/parties/{partyId}/members/{memberId}` · 방장 · 204 · 화면 S06 참여자 옆 "강퇴"

**처리 순서와 규칙** (PARTY 행 잠금 상태)
1. 대상의 PARTY_MEMBER 줄을 **삭제하지 않고** `status = 'KICKED'`로 변경. 이 줄이 남아 재참여 불가(결정 P2).
2. 안내 줄(`KICK`) 저장.
3. 파티가 `FULL`이었고 기한 전이면 `RECRUITING`으로 복귀.

- 강퇴 즉시 대상자는 채팅(A-20·A-21)·방 정보(A-13)에서 403. 내 채팅 목록(A-22)에서도 제외.

| 오류 | 언제 |
| --- | --- |
| 400 | 방장이 자기 자신을 강퇴 |
| 403 | 방장이 아님 |
| 404 | 대상이 `JOINED` 참여자가 아님 |

#### A-19. 모집 마감

`PUT /api/parties/{partyId}/close` · 방장 · 200 · 화면 S06 방장 버튼

```json
// 응답 200
{ "partyId": 1, "status": "CLOSED" }
```

- RECRUITING·FULL 파티를 CLOSED로 변경.
- 마감 파티는 목록에서 제외. 내 채팅에는 계속 표시.

| 오류 | 언제 |
| --- | --- |
| 403 | 방장이 아님 |
| 409 | `이미 마감된 파티입니다.` |

#### A-20. 새 채팅 받기

`GET /api/parties/{partyId}/messages?after=` · 방장·참여자 · 200 · 화면 S06 (3초마다 호출)

| 쿼리 | 설명 |
| --- | --- |
| after | 마지막으로 받은 `messageId`. 없으면 **최근 50개** |

```json
[
  { "messageId": 31, "memberId": 5, "nickname": "힌트없이", "msgType": "JOIN", "content": null, "createdAt": "2026-11-17T09:05:00", "mine": false },
  { "messageId": 32, "memberId": 5, "nickname": "힌트없이", "msgType": "CHAT", "content": "저 갈게요.", "createdAt": "2026-11-17T09:05:30", "mine": false }
]
```

- `messageId` 오름차순, 1회 최대 100개.
- `nickname`: MEMBER JOIN. 닉네임 변경자의 과거 메시지도 새 닉네임으로 표시.
- 프런트는 `msgType`별로 다르게 렌더링. 글자는 모두 `textContent`로 삽입.

| msgType | 화면 |
| --- | --- |
| `CHAT` | 말풍선. `mine`이면 오른쪽 |
| `JOIN` / `LEAVE` / `KICK` | 가운데 안내 줄: `○○님이 들어왔어요` / `나갔어요` / `강퇴됐어요` (화면 문구, `js/party/party-room.js`) |

- 마감(`CLOSED`) 파티도 채팅 가능(일정 조율용).
- `JOINED`가 아니면 403(강퇴 직후 포함). 프런트는 403 수신 시 3초 반복 중지 후 목록으로 이동.

#### A-21. 채팅 보내기

`POST /api/parties/{partyId}/messages` · 방장·참여자 · 201

```json
// 요청
{ "content": "무서운 건 제가 앞장설게요" }
// 응답 201 (A-20 한 줄과 같은 모양)
{ "messageId": 33, "memberId": 4, "nickname": "탈출왕", "msgType": "CHAT", "content": "무서운 건 제가 앞장설게요", "createdAt": "2026-11-17T09:06:00", "mine": true }
```

- 앞뒤 공백 제거 후 1~500자. 위반 시 400. 길이는 공백 제거 후 서비스에서 검사(DTO `@Size` 미사용).
- 끝난 파티(`play_at` 지남)는 읽기 전용. 전송 시 409 `종료된 파티에는 메시지를 보낼 수 없습니다.` 화면은 입력칸 대신 안내와 후기 쓰기 버튼 표시.

#### A-22. 내 채팅 (내 파티) 목록

`GET /api/my/parties` · USER · 200 · 화면 S20 `chats.html` (마이페이지 "내 채팅" 탭)

```json
[
  {
    "partyId": 1, "title": "인형의 집 같이 가실 분", "themeId": 1, "themeTitle": "저주받은 인형의 집", "themeOpen": true,
    "status": "RECRUITING", "myRole": "LEADER", "currentPeople": 2, "maxPeople": 4,
    "playAt": "2026-11-20T19:00:00", "ended": false,
    "lastMessage": { "nickname": "탈출왕", "msgType": "CHAT", "content": "무서운 건 제가 앞장설게요", "createdAt": "2026-11-17T09:06:00" }
  }
]
```

- 내가 **`JOINED`** 인 파티 반환. `RECRUITING`, `FULL`, `CLOSED` 모두 포함.
  - 삭제된 파티(`DELETED`)·강퇴된 파티는 제외.
- 정렬: 마지막 메시지 시각 최신순.
- `ended`: `play_at < SYSDATE` 여부. 끝난 파티에는 "후기 쓰기" 버튼 표시, 클릭 시 `themeId`로 후기 팝업(D-1) 열기.
- `themeOpen`: A-13 `theme.open`과 같은 값. `false`이면 목록에 운영 종료 안내 표시.

### B · 테마·매장 탐색 (11)

**공통 규칙**
- 손님에게 보이는 테마: `THEME.status = OPEN`이면서 `STORE.status = APPROVED`인 것만.
- 평균 별점: `rating_sum / review_count`. 소수 첫째 자리까지, 후기가 없으면 `null`.

#### B-1. 테마 목록·검색·필터

`GET /api/themes?keyword=&area=&region=&date=&people=&genreId=&sort=` · 공개 · 200

- 화면: S08 메인(`index.html`)의 가로 줄들, 사이드 메뉴 통합 검색의 결과 격자.

| 쿼리 | 설명 |
| --- | --- |
| keyword | **테마 이름** 일부. 띄어쓰기 무시 (`REPLACE(title, ' ', '') LIKE ...`). 매장 이름 검색은 B-9 (화면은 검색 결과를 [테마] [매장] 탭으로 표시) |
| area | 세부 지역 (B-8 값, 예: `홍대`) |
| region | 큰 지역 이름(서울·경기 등). 그 안의 모든 세부 지역 매장의 테마. `area`가 있으면 `area` 우선 |
| date | 그날 유형 시간표가 하나라도 있는 테마만. 날 유형: **토·일·공휴일(HOLIDAY) → `WEEKEND`**, 나머지 `WEEKDAY`. 오늘 이전이면 400 |
| people | `min_people ≤ people ≤ max_people` |
| genreId | 장르 하나 |
| sort | `rate`(기본, 평균 별점 높은 순, 후기 없는 테마는 뒤로) / `popular`(**이번 주 인기순**, 아래 설명) / `new`(등록 최신순). 그 밖의 값은 400 |

```json
[
  {
    "themeId": 1, "title": "저주받은 인형의 집", "storeId": 1, "storeName": "미스터리룸 홍대점", "area": "홍대",
    "genres": ["공포", "추리"], "difficulty": 4, "playMinutes": 70, "minPeople": 2, "maxPeople": 4, "price": 25000,
    "posterUrl": "/uploads/posters/3f2a.jpg", "avgRating": 4.0, "reviewCount": 1,
    "recruitingPartyCount": 2, "weeklyScore": 8, "createdAt": "2026-11-01T10:00:00", "wished": false
  }
]
```

- `recruitingPartyCount`: 모집 중(`RECRUITING`)이면서 기한이 남은 파티 수. 메인 "지금 파티 모집 중" 줄과 배너 버튼에 사용.
- `wished`: 로그인한 손님일 때만 의미 있음. 비로그인이면 `false`.
- `weeklyScore`: **이번 주 인기 점수**(결정 C2). `sort=popular`는 이 점수 높은 순, 동점이면 `rate` 순서.
  - 점수 = 최근 7일 동안 새로 생긴 **파티 × 3 + 찜 × 2 + 후기 × 1**
  - 파티는 `DELETED` 제외(마감·정원 찬 파티는 포함). 후기는 `VISIBLE`만.
  - 누적이 아닌 최근 7일(현재 기준 7×24시간)만 집계 → 주마다 순위 변동. (이유: 별점만 보면 오래된 테마가 계속 1위)
- 메인 가로 줄은 이 응답(`sort=popular`)을 **1회 받아 나눠 렌더링**: 이번 주 인기 TOP 5, 파티 모집 중, 새로 문을 연 테마(최근 14일), 장르별 줄, 난이도별 줄.
- **비회원 메인 추천 배너**도 이 API(`sort=popular`) 상위 5개로 렌더링(결정 C1·C2).

#### B-2. 테마 상세

`GET /api/themes/{themeId}` · 공개 · 200 · 화면 S09 `theme.html`

```json
{
  "themeId": 1, "title": "저주받은 인형의 집", "description": "밤마다 자리를 바꾸는 인형들…",
  "genres": [{ "genreId": 1, "name": "공포" }, { "genreId": 2, "name": "추리" }],
  "difficulty": 4, "playMinutes": 70, "minPeople": 2, "maxPeople": 4, "price": 25000,
  "posterUrl": "/uploads/posters/3f2a.jpg", "bookingUrl": "https://example.com/booking/1",
  "store": { "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대", "address": "서울 마포구 …", "phone": "02-000-0001" },
  "avgRating": 4.0, "reviewCount": 1, "recruitingPartyCount": 2, "wished": false
}
```

- 비공개 테마(PENDING, REJECTED, CLOSED) 또는 매장 승인 전이면 **404**. 사장 미리보기는 C-6.
- 후기 목록은 D-4로 별도 조회.

#### B-3. 그날 시간표

`GET /api/themes/{themeId}/slots?date=2026-11-20` · 공개 · 200 · 화면 S09 시간표, S05 파티 만들기 시간 선택

```json
{
  "date": "2026-11-20", "dayType": "WEEKDAY", "holidayName": null,
  "slots": [
    { "slotId": 11, "startTime": "13:00", "endTime": "14:10" },
    { "slotId": 14, "startTime": "19:00", "endTime": "20:10" }
  ]
}
```

- 날 유형 규칙: **토·일, 또는 HOLIDAY에 있는 날짜면 `WEEKEND`**, 나머지 `WEEKDAY`(결정 T1).
  - 공휴일이면 `holidayName`에 이름(예: `"추석"`) 포함. 화면에서 "추석이라 주말 시간표" 등 안내 가능.
- `endTime` = `startTime + play_minutes`.
- 날짜가 오늘이면 **이미 지난 시각 제외.** 오늘 이전 날짜면 400.
- 회차별 마감 상태 없음(결정 T2). 실제 예약은 테마의 `bookingUrl`에서 진행.

#### B-4 / B-5. 찜 / 찜 취소

| 번호 | 주소 | 성공 | 오류 |
| --- | --- | --- | --- |
| B-4 | `POST /api/themes/{themeId}/wish` | 201 `{ "wishId": 9 }` | 404 공개 안 된 테마 / 409 `이미 찜한 테마입니다.` |
| B-5 | `DELETE /api/themes/{themeId}/wish` | 204 | 404 찜하지 않은 테마 |

- 찜하기는 목록에 **추가만** 수행. 화면 이동 없이 하트만 변경(회의 v2-7).

#### B-6. 찜 목록

`GET /api/my/wishes` · USER · 200 · 화면 S10 `wishes.html` (마이페이지 "찜 목록" 탭)

```json
[
  { "wishId": 9, "themeId": 2, "title": "할머니의 다락방", "storeName": "미스터리룸 홍대점",
    "status": "OPEN", "posterUrl": "/uploads/posters/a1.jpg", "createdAt": "2026-11-16T12:00:00" }
]
```

- 정렬: 최근 찜한 순.
- 운영 종료(CLOSED) 테마도 목록에 **유지.** `status` 함께 제공.

#### B-7. 장르 목록 · B-8. 지역 목록

| 번호 | 주소 | 응답 |
| --- | --- | --- |
| B-7 | `GET /api/genres` | `[{ "genreId": 1, "name": "공포" }, …]` (7개) |
| B-8 | `GET /api/areas` | `["홍대", "신촌", "강남", "건대"]` (**검색용**: APPROVED 매장이 하나라도 있는 세부 지역만. 순서는 AREA 표 순서: 서울 → 경기 → … 큰 지역, 그 안에서 세부 지역) |

- B-7 사용처: 가입(손님), 내 정보 선호 장르, 테마 등록, 통합 검색 장르 칸, 파티 장르 필터.
- B-8 사용처: 손님 검색의 지역 칸, 매장 목록의 지역 칩. 매장 없는 지역은 결과가 없으므로 제외. 매장 등록 화면은 전체 목록이 필요해 B-12 사용.

#### B-9. 매장 목록

`GET /api/stores?area=&region=&keyword=&sort=` · 공개 · 200 · 화면 S27 `stores.html`

```json
[
  {
    "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대",
    "address": "서울 마포구 …", "hours": "10:00 ~ 23:00 (연중무휴)", "photoUrl": "/uploads/stores/7b1e.jpg",
    "genres": ["공포", "추리", "감성"], "themeCount": 3, "avgRating": 4.3, "recruitingPartyCount": 3,
    "approvedAt": "2026-11-10T00:00:00"
  }
]
```

- **APPROVED 매장만** 반환.
- `genres`, `themeCount`, `avgRating`, `recruitingPartyCount`: 해당 매장의 OPEN 테마 기준 계산. `avgRating`은 테마 평균 별점들의 평균.
- `keyword`: 매장 이름 일부, 띄어쓰기 무시.
- `region`: 큰 지역 이름(서울·경기 …). 그 안의 모든 세부 지역 매장 반환. `area`가 있으면 `area` 우선.
- `sort`: `rate`(평점순, 기본) / `new`(최신순). 그 밖의 값은 400.
  - 평점순: 평점 높은 순, 후기 없는 매장은 뒤로. 동점이면 최근 승인 매장 우선.
  - 최신순: 최초 승인 시각(`approvedAt`) 최근 순.
- `photoUrl`: 매장 사진. 없으면 `null`(결정 S5).
- `approvedAt`: 매장 **최초 승인 시각**. 화면은 30일 이내면 매장 카드에 NEW 표시(테마 NEW는 `createdAt` 14일). 사장 수정 후 재승인돼도 불변. 관리자 직접 등록 매장은 등록 시각.
- 브랜드 정보 없음(결정 B1).

#### B-10. 매장 상세

`GET /api/stores/{storeId}` · 공개 · 200 · 화면 S28 `store.html`

```json
{
  "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대",
  "address": "서울 마포구 …", "phone": "02-000-0001", "websiteUrl": "https://example.com/mystery-hongdae",
  "hours": "10:00 ~ 23:00 (연중무휴)", "intro": "홍대입구역 9번 출구 3분.", "photoUrl": "/uploads/stores/7b1e.jpg",
  "lat": 37.556, "lng": 126.923, "avgRating": 4.3,
  "themes": [
    { "themeId": 1, "title": "저주받은 인형의 집", "genres": ["공포", "추리"], "difficulty": 4, "playMinutes": 70,
      "minPeople": 2, "maxPeople": 4, "price": 25000, "posterUrl": "/uploads/posters/3f2a.jpg",
      "avgRating": 4.0, "reviewCount": 1, "recruitingPartyCount": 2 }
  ]
}
```

- 미승인 매장(`PENDING`, `REJECTED`)은 404.
  - 승인 매장도 사장 수정 시 `PENDING`으로 변경(결정 S1). 재승인 전까지 404.
- 상단 **"매장 웹사이트 ↗" 버튼**: `websiteUrl`을 새 창으로 열기(결정 B2).
- 테마별 예약은 테마 상세의 "예약하러 가기"(`bookingUrl`).
- `themes`: OPEN 테마만.
- 상단 큰 배경: `photoUrl`(매장 사진). 없으면 평점 최고 테마의 `posterUrl` 사용(화면에서 선택).

#### ~~B-11. 지도용 매장~~ (없앰)

- 전체 매장 지도 화면(S11) 미구현 결정으로 삭제. 지도는 매장 상세(B-10)의 `lat`·`lng`으로 매장 상세 화면 안에만 표시. 번호는 공번 유지, B-12는 그대로.

#### B-12. 지역 전체 (매장 등록용)

`GET /api/regions` · 공개 · 200 · 화면 S21 `store-form.html` 지역 select

```json
[
  { "regionId": 1, "name": "서울",
    "areas": [ { "areaId": 1, "name": "홍대" }, { "areaId": 2, "name": "신촌" }, { "areaId": 3, "name": "강남" } ] },
  { "regionId": 2, "name": "경기",
    "areas": [ { "areaId": 11, "name": "수원" }, { "areaId": 12, "name": "부천" } ] }
]
```

- REGION·AREA 표의 **모든** 지역을 큰 지역별로 묶어 반환(결정 L1). 매장 없는 지역도 포함.
- 정렬: `sort_order` 순(큰 지역 → 그 안의 세부 지역).
- 화면: 큰 지역은 `<optgroup>`, 세부 지역은 `<option>`. 매장 등록·수정(C-3·C-4)에는 세부 지역 **이름**(`name`) 전송.
- B-8과의 차이: B-8은 손님 검색용(**매장 있는 지역만**), B-12는 등록용(**전체**).
- 손님 화면 지역 선택기(`UI.areaPicker`, `js/common/ui.js`)는 B-8 결과를 B-12로 큰 지역별로 묶어 표시. 매장 없는 큰 지역은 미표시.

---

### C · 사장 (12)

**공통 규칙**
- 권한 OWNER\*: 사장·관리자 모두 호출 가능([1-4](#1-4-권한-표기)).
- 사장 호출 시 매 요청마다 **내 매장·내 테마 여부** 확인. 남의 매장이면 403.
  - 테스트: owner2 계정으로 owner1 매장 수정 시도.
- 폐업(`CLOSED`) 매장과 그 테마는 조회만 가능. 수정 API(C-4, C-8, C-9, C-11, C-20) 호출 시 409 `폐업한 매장은 고칠 수 없습니다.` 테마 등록(C-7)은 APPROVED 매장 조건에 걸려 409.

#### C-1. 내 매장 목록

`GET /api/owner/stores` · OWNER\* · 200 · 화면 S12 `owner.html`, `owner-store.html`·`owner-theme.html`·`store-form.html`의 매장 정보

```json
[
  { "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대", "address": "서울 마포구 …",
    "phone": "02-000-0001", "websiteUrl": "https://example.com/mystery-hongdae",
    "hours": "10:00 ~ 23:00", "intro": "…", "photoUrl": "/uploads/stores/7b1e.jpg", "bizPlaceNo": "123-45-67890",
    "status": "APPROVED", "rejectReason": null, "themeCount": 3, "createdAt": "2026-11-10T10:00:00",
    "approvedAt": "2026-11-11T09:00:00", "ownerLoginId": "owner1", "ownerNickname": "미스터리룸홍대" },
  { "storeId": 10, "name": "미스터리룸 신촌점", "status": "REJECTED",
    "rejectReason": "사업장등록증의 상호와 매장 이름이 다릅니다. 다시 확인해 주세요.", "…": "…" }
]
```

- 사장 호출: `owner_id = 나`인 매장(모든 상태). 관리자 호출: **`APPROVED`·`CLOSED` 매장 전체**(사장 매장 + 관리자 등록 매장). 최신 등록순(관리자 개편 11/23, 폐업 포함 11/25). 승인 대기·반려 매장은 승인 요청 화면(C-13)에서 확인.
- 화면 정렬(`js/owner/owner.js`):
  - 사장: 승인 → 승인 대기 → 반려 → 폐업 순, 같은 상태는 최근 등록 순(`Manage.sortStores`). 매장이 1개여도 항상 목록 표시(11/25: 매장 화면으로 자동 이동 삭제).
  - 관리자("매장 관리"): 이름 검색 + 정렬(최신순·오래된순·이름순), 폐업 매장은 항상 맨 뒤. 한 쪽 10개.
- `ownerLoginId`·`ownerNickname`: 매장 사장. 관리자 등록 매장이면 `null`. `approvedAt`: 최초 승인 시각.
- `rejectReason`: 반려 매장일 때만 값 존재. 사장 홈에서 매장 옆에 표시(결정 S4).
- 매장 하나만 조회하는 API 없음. 매장 수정·테마 화면의 매장 정보도 이 응답에서 추출(`store-form.js`, `Manage.myStore`).

#### C-2. 사업장 관리번호 중복 확인

`GET /api/owner/stores/check-biz-place-no?bizPlaceNo=` · OWNER\* · 200 → `{ "available": true }`

- 폐업 매장의 번호는 중복으로 보지 않음(같은 번호로 재등록 가능).

#### C-3. 매장 등록 (multipart)

`POST /api/owner/stores` · OWNER\* · 201 · 화면 S21 `store-form.html`

| 폼 칸 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| name | text | Y | 1~50자 |
| area | text | Y | **세부 지역 이름** (B-12 목록 중 하나, 예: `홍대`). 목록에 없으면 400 (결정 L1) |
| address | text | Y | 1~100자. 화면은 "도로명 주소, 상세 주소"로 합쳐 전송(다음 우편번호 서비스로 선택) |
| phone | text | Y | `02-123-4567`, `031-123-4567`, `010-1234-5678`, `0507-1234-5678`, `1588-1234` 형식 (11/25 변경. 화면 `store-form.js`와 같은 정규식) |
| websiteUrl | text | Y | **매장 웹사이트**. `http://`나 `https://`로 시작, 500자 이내 (결정 B2) |
| hours | text | Y | **영업시간** 50자 이내 (결정 S2). 시간 표기(`10:00` 또는 `10시`)가 하나 이상 있어야 함 |
| intro | text | | **매장 소개** 200자 이내. 선택(11/25 변경), 비우면 NULL |
| bizPlaceNo | text | Y | **사업장 관리번호** `000-00-00000-0` (숫자 11자리, 11/25 변경). 기존 10자리 값은 수정 시 바꾸지 않을 때만 통과 |
| bizPlaceFile | file | 사장 Y | 사업장 증빙 서류 이미지. 관리자 등록 시 생략 가능 |
| storePhoto | file | | **매장 사진** (공개). `/uploads/stores/`에 저장, STORE.`photo_url`에 경로 저장 (결정 S5) |

```json
// 응답 201
{ "storeId": 9, "status": "PENDING" }
```

| 누가 등록하나 | status | owner_id |
| --- | --- | --- |
| 사장 | `PENDING` | 나 |
| 관리자 | `APPROVED` (바로 공개, 결정 S3) | NULL |

- 브랜드 칸 없음(결정 B1).
- **좌표(`lat`·`lng`) 미수신.** 서버가 주소(쉼표 앞 도로명 주소)로 카카오 로컬 API 호출해 채움. 키는 `application-local.properties`의 `kakao.rest-key`. 키가 없거나 결과가 없으면 둘 다 `null`로 저장, 매장 상세 지도만 미표시.
- 수정(C-4) 시에는 주소가 바뀌었거나 좌표가 비어 있을 때만 재조회.

| 오류 | 언제 |
| --- | --- |
| 400 | 형식 위반, 파일 규칙 위반, 웹사이트 주소가 `http(s)://`로 시작하지 않음, `지역은 목록에서 골라 주세요.` / `사업장 관리번호는 숫자 11자리입니다. (000-00-00000-0)` / `사업장 증빙 서류 이미지를 첨부해 주세요.` |
| 409 | `이미 등록된 사업장 관리번호입니다.` |

#### C-4. 매장 수정 (multipart)

`PUT /api/owner/stores/{storeId}` · OWNER\*(내 매장) · 200

- 칸은 C-3과 같음. `bizPlaceFile`·`storePhoto`를 비우면 기존 파일 유지.
- **사장 수정 시 어떤 칸이든 `status = PENDING`** (결정 S1). 기존 `APPROVED`도 동일.
  - 이때 `reject_reason` 초기화.
  - 주의: 재승인 전까지 **해당 매장의 테마도 손님 화면에서 모두 숨김**(손님 화면은 매장 APPROVED 테마만 표시). 화면은 저장 전 확인 팝업 표시.
- 관리자 수정 시 사장 매장이어도 상태 유지(결정 S3, 관리자 개편 11/23).
- 응답: `{ "storeId": 9, "status": "PENDING" }`.

| 오류 | 언제 |
| --- | --- |
| 403 | 내 매장이 아님 |
| 404 | 없는 매장 |
| 409 | 번호 중복 / `폐업한 매장은 고칠 수 없습니다.` |

#### C-5. 매장의 테마 목록

`GET /api/owner/stores/{storeId}/themes` · OWNER\*(내 매장) · 200 · 화면 S12 테마 표

```json
[
  { "themeId": 1, "title": "저주받은 인형의 집", "genres": ["공포", "추리"], "playMinutes": 70,
    "status": "OPEN", "rejectReason": null, "avgRating": 4.0, "reviewCount": 1, "updatedAt": "2026-11-12T15:00:00" },
  { "themeId": 22, "title": "좀비 연구소 리뉴얼", "genres": ["공포"], "playMinutes": 60,
    "status": "REJECTED", "rejectReason": "예약 링크가 열리지 않습니다.", "avgRating": null, "reviewCount": 0, "updatedAt": "2026-11-15T11:00:00" }
]
```

- 모든 상태의 테마 반환: `PENDING`, `OPEN`, `REJECTED`, `CLOSED`.
- `REJECTED` 테마는 `rejectReason`을 사장 홈 표에 표시(결정 S4).

#### C-6. 테마 수정용 상세

`GET /api/owner/themes/{themeId}` · OWNER\*(내 테마) · 200 · 화면 S13 수정 모드

- 응답: B-2와 같은 모양 + `genreIds`, `status`, `source`, `createdAt`, `updatedAt`.
- 상태 무관 조회 가능(승인 전 포함).

#### C-7. 테마 등록 (multipart)

`POST /api/owner/themes` · OWNER\*(내 매장) · 201 · 화면 S13 `owner-theme.html`

| 폼 칸 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| storeId | number | Y | 내 매장이면서 **APPROVED** |
| title | text | Y | 1~50자 |
| description | text | | 1300자 이내 |
| difficulty | number | Y | 1~5 |
| playMinutes | number | Y | 1~720 (제한 시간, 분. 장시간 테마 때문에 11/23 300 → 720) |
| minPeople, maxPeople | number | Y | 1 ≤ min ≤ max ≤ 20 |
| price | number | Y | 0 이상, 1인 기준 가격 (인원별 가격은 받지 않음) |
| bookingUrl | text | Y | `http://` 또는 `https://`로 시작, 500자 이내 |
| genreIds | number[] | Y | 1개 이상. 폼에서는 `genreIds=1&genreIds=2`처럼 같은 이름 여러 번 |
| poster | file | | 테마 사진 (공개) |

```json
// 응답 201
{ "themeId": 21, "status": "PENDING" }
```

- **한 트랜잭션**에서 THEME·THEME_GENRE 저장.
- 사장 등록: `PENDING`, `source = OWNER`.
- 관리자 등록: `OPEN`, `source = ADMIN`.
- 화면(`js/owner/owner-theme.js`): 매장 선택칸 없음. 매장 화면(`owner-store.html`)에서 `?storeId=`로 진입, 매장 정보는 C-1에서 추출. 매장이 APPROVED가 아니면 화면에서 등록 차단.
  - 회의 v2-4의 "매장 사업장 등록번호·전화번호 함께 표시"는 현재 테마 화면에 없음.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `예약 링크는 http:// 또는 https:// 로 시작해야 합니다.` / `최소 인원이 최대 인원보다 클 수 없습니다.` |
| 403 | 내 매장이 아님 |
| 409 | `승인된 매장에만 테마를 등록할 수 있습니다.` |

#### C-8. 테마 수정 (multipart)

`PUT /api/owner/themes/{themeId}` · OWNER\*(내 테마) · 200

- 칸은 C-7과 같음. 단 `storeId` 변경 불가. `poster`를 비우면 기존 사진 유지.
- 사장 수정 시 **다시 `PENDING`**, `reject_reason` 초기화. 관리자 재승인 후 손님에게 노출.
- 관리자 수정 시 `OPEN` 유지(결정 S3).
- THEME_GENRE는 삭제 후 재저장. 같은 트랜잭션.
- `updated_at`은 트리거가 갱신.
- 응답: `{ "themeId": 21, "status": "PENDING" }`.

#### C-9. 운영 종료·재개

`PUT /api/owner/themes/{themeId}/status` · OWNER\*(내 테마) · 200

```json
// 요청
{ "status": "CLOSED" }
// 응답 200
{ "themeId": 1, "status": "CLOSED" }
```

- `OPEN` → `CLOSED`, `CLOSED` → `OPEN`만 허용. 그 밖의 상태는 409(승인 전·반려 테마는 변경 불가).
- 종료 테마도 찜 목록·내 기록에는 유지.
- 사장 화면의 테마 "삭제" 버튼은 별도 API 없이 이 API로 `CLOSED` 처리(11/24). 실제 삭제 없음.
- 운영 종료 시 해당 테마의 파티는 목록(A-12)에서 제외, 신규 참여 불가(A-16 409).

#### C-10. 주중/주말 시간표 보기

`GET /api/owner/themes/{themeId}/slots` · OWNER\*(내 테마) · 200 · 화면 S13 `owner-theme.html`의 [시간표] 탭 (11/23 `owner-slots.html` 통합), S12 ② 매장 화면의 테마별 회차 수

```json
{
  "themeId": 1, "playMinutes": 70,
  "weekday": [ { "slotId": 11, "startTime": "13:00", "endTime": "14:10" }, { "slotId": 12, "startTime": "15:00", "endTime": "16:10" } ],
  "weekend": [ { "slotId": 20, "startTime": "10:00", "endTime": "11:10" } ]
}
```

#### C-11. 주중/주말 시간표 저장 (통째 교체)

`PUT /api/owner/themes/{themeId}/slots` · OWNER\*(내 테마) · 200

```json
// 요청
{ "weekday": ["13:00", "15:00", "17:30", "19:00", "20:30"], "weekend": ["10:00", "11:30", "13:00"] }
// 응답 200 = C-10 모양
```

**처리 순서와 규칙**
1. 값 검사.
   - 형식 `HH:mm`.
   - 한 유형 안에 같은 시각 중복 불가.
   - 회차 시간 겹침은 **허용**(이유: 밀어내기 테마처럼 의도적으로 겹쳐 운영하는 경우 존재, 시간표는 표시용, 11/23).
   - 한 유형 최대 20개.
2. **한 트랜잭션**에서 해당 테마의 TIME_SLOT 삭제 후 재저장.

- 화면의 "주말에도 똑같이 →" 복사 버튼은 화면에서만 처리. 저장은 이 API 1회 호출.
- 기존 파티는 날짜·시각(`play_at`)을 별도 저장 → 시간표 변경과 무관하게 유지.
  - PM 회의의 "파티원 있으면 시간표 잠금"은 시간표가 반복 구조로 바뀌어 미적용.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `시간은 19:00처럼 입력해 주세요.` / `주중 13:00이 두 번 들어 있습니다.` / `주중 회차는 20개까지 넣을 수 있습니다.` |

#### C-20. 매장 폐업

`PUT /api/owner/stores/{storeId}/close` · OWNER\*(내 매장) · 200 · 화면 `owner-store.html` 매장 요약의 [폐업] 버튼 (11/24 추가)

```json
// 요청 본문 없음
// 응답 200
{ "storeId": 1, "status": "CLOSED" }
```

**처리 순서와 규칙** (한 트랜잭션)
1. 주인 확인(관리자는 생략), 이미 폐업이면 409.
2. `APPROVED` 매장만 가능. 아니면 409 `승인된 매장만 폐업할 수 있습니다.`
3. STORE `status = CLOSED`.
4. 해당 매장의 모든 테마(`PENDING`·`REJECTED` 포함) `status = CLOSED`.

- 되돌릴 수 없음. 재오픈은 같은 사업장 관리번호로 신규 등록(C-3).
- 폐업 매장·테마는 손님 화면에서 제외. 해당 파티는 목록 제외·참여 불가(A-12, A-16), 기존 참여자의 방·채팅은 유지.
- 사장 화면(C-1)과 관리자 매장 관리에는 계속 표시(조회 전용).

| 오류 | 메시지 |
| --- | --- |
| 403 | 내 매장이 아님 |
| 404 | `매장을 찾을 수 없습니다.` |
| 409 | `승인된 매장만 폐업할 수 있습니다.` / `폐업한 매장은 고칠 수 없습니다.` |


### C · 관리자 (8)

#### C-12. 관리자 홈 숫자 요약

`GET /api/admin/summary` · ADMIN · 200 · 화면 S25 `admin.html`

```json
{
  "pendingStores": 2, "pendingThemes": 1,
  "oldestPendingStoreAt": "2026-11-16T10:00:00", "oldestPendingThemeAt": "2026-11-17T09:00:00",
  "approvedStores": 5, "openThemes": 18,
  "memberCountByRole": { "USER": 5, "OWNER": 3, "ADMIN": 1 }
}
```

- 단일 서버 → 회원 수까지 1회 응답에 포함.
- `memberCountByRole`: 탈퇴 회원 제외.
- 화면 숫자 카드: 매장 승인 대기, 테마 승인 대기, 운영 중 매장, 운영 중 테마(`js/admin/admin.js`).
- "지금 처리할 것": C-13·C-17(`status=PENDING`) 결과를 매장 칸·테마 칸으로 나눠 표시(관리자 개편 11/23). 각 칸은 오래된 순, 건수 제한 없이 전체 표시·칸 안 스크롤(11/25).

#### C-13. 매장 승인 목록

`GET /api/admin/stores?status=PENDING` · ADMIN · 200 · 화면 S22 `admin-stores.html`

| 쿼리 | 설명 |
| --- | --- |
| status | 기본값 `PENDING`. `APPROVED`, `REJECTED`, `CLOSED`도 수신 (`StoreStatus` 값) |

```json
[
  { "storeId": 9, "name": "미스터리룸 합정점", "bizPlaceNo": "222-33-44444",
    "owner": { "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대" },
    "createdAt": "2026-11-17T10:00:00" }
]
```

- 정렬: 오래된 순. "신청한 사장" 칸은 MEMBER JOIN. 관리자 직접 등록 매장은 `owner: null`.
- 목록에서 승인 불가. 상세(C-14)에서 처리.

#### C-14. 매장 승인 상세

`GET /api/admin/stores/{storeId}` · ADMIN · 200 · 화면 S23 `admin-store-detail.html`

```json
{
  "storeId": 9, "name": "미스터리룸 합정점", "area": "합정",
  "address": "서울 마포구 …", "phone": "02-000-0009", "websiteUrl": "https://example.com/mystery-hapjeong",
  "hours": "11:00 ~ 23:00", "intro": "합정역 7번 출구 2분.", "photoUrl": "/uploads/stores/9a2c.jpg",
  "bizPlaceNo": "222-33-44444", "hasBizPlaceFile": true,
  "owner": { "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대", "bizNo": "111-22-33333",
             "joinedAt": "2026-11-16T10:00:00" },
  "status": "PENDING", "rejectReason": null, "createdAt": "2026-11-17T10:00:00", "approvedAt": null
}
```

- 화면 구성: 맨 위 한 줄(이름·상태·신청자·신청일 + 승인/반려) → ① 손님에게 보일 정보 → ② 서류 확인(사업장등록증 · 사업자등록증 나란히) (관리자 개편 11/23). 매장 관리의 매장 상세(`owner-store.html`)도 이 응답 사용.
- `owner.joinedAt`: 사장 가입일(서류 칸). `approvedAt`: 최초 승인 시각(승인 전이면 `null`).

| 서류 | 받는 곳 |
| --- | --- |
| 사업장 증빙 서류 | C-15 |
| 사장 사업자등록증 | A-11 (`owner.memberId`) |

- 관리자가 두 번호와 상호·주소 대조.
- 매장 사진(`photoUrl`)도 함께 확인(손님 노출 적합 여부).

#### C-15. 사업장 증빙 서류 이미지

`GET /api/admin/stores/{storeId}/biz-place-file` · ADMIN · 200

- 이미지 자체 반환. A-11과 같은 방식(`api.blob`).
- 파일 없으면 404(관리자 직접 등록 매장).

#### C-16. 매장 승인·반려

`PUT /api/admin/stores/{storeId}/approval` · ADMIN · 200

```json
// 승인
{ "approved": true }
// 반려 (사유 필수)
{ "approved": false, "reason": "사업장등록증의 상호와 매장 이름이 다릅니다. 다시 확인해 주세요." }
// 응답 200
{ "storeId": 9, "status": "REJECTED", "rejectReason": "사업장등록증의 상호와 …" }
```

- **PENDING 매장만** 처리 가능. 아니면 409 `이미 처리된 매장입니다.`
- **반려 시 `reason` 필수**: 1~300자, 없으면 400. 사유는 STORE.`reject_reason`에 저장, 사장 홈(C-1)에 표시(결정 S4).
- 승인 시 `reject_reason` 초기화. 즉시 매장 목록(B-9)에 노출, 사장의 테마 등록 가능.

#### C-17. 테마 승인 목록

`GET /api/admin/themes?status=PENDING` · ADMIN · 200 · 화면 S15 `admin-themes.html`

```json
[
  { "themeId": 21, "title": "거울 속 방", "storeId": 1, "storeName": "미스터리룸 홍대점", "genres": ["공포"],
    "posterUrl": "/uploads/posters/9c.jpg", "createdAt": "2026-11-17T09:00:00", "updatedAt": "2026-11-17T09:00:00" }
]
```

- 매장 승인과 **별도 탭**. 목록 → 상세 → 승인/반려 순서로 처리(회의 v2-10).
- `storeId`(11/26 추가): 관리자 매장 관리 검색창에서 테마 이름으로도 매장을 찾으려고 씀(상태별로 받아 매장별로 묶음).

#### C-18. 테마 승인 상세

`GET /api/admin/themes/{themeId}` · ADMIN · 200 · 화면 S24 `admin-theme-detail.html`

- 응답: C-6 모양 + `store: { storeId, name, bizPlaceNo, phone, websiteUrl, status, area, address, hours, ownerLoginId }`. `ownerLoginId`는 관리자 등록 매장이면 `null`.
- 화면 구성: 맨 위 한 줄(이름·상태 / 매장·신청자·신청일·수정일 + 승인/반려) → ① 손님에게 보일 정보(포스터 + 4칸 숫자 + 예약 링크 + 소개) → ② 매장 (관리자 개편 11/23).
- 상세에서 테마 사진 함께 확인(회의 v2-10).
- 승인 전 주소, 전화번호, 예약 링크를 관리자가 직접 확인.

#### C-19. 테마 승인·반려

`PUT /api/admin/themes/{themeId}/approval` · ADMIN · 200

```json
// 승인
{ "approved": true }
// 반려 (사유 필수)
{ "approved": false, "reason": "예약 링크가 열리지 않습니다." }
// 응답 200
{ "themeId": 21, "status": "OPEN", "rejectReason": null }
```

- **PENDING 테마만** 처리 가능. 아니면 409.
- 반려 시 `reason` 필수(1~300자). 사유는 THEME.`reject_reason`에 저장, 사장 홈(C-5)에 표시(결정 S4).
- 매장이 APPROVED가 아니면 승인 불가. 409 `매장이 승인되지 않았습니다.`
- 승인 즉시 손님 메인(B-1)에 노출.

### D · 기록·추천 (10)

#### D-1. 후기 쓰기

`POST /api/reviews` · USER · 201

- 화면: S17 후기 팝업. 테마 상세, 마이페이지, 내 채팅(끝난 파티) **어디서든 같은 팝업** 사용.

| 본문 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| themeId | number | Y | OPEN 또는 CLOSED 테마 |
| rating | number | Y | 1~5 |
| escaped | boolean | Y | 탈출 성공. DB에는 `Y`/`N`으로 저장 |
| hintCount | number | Y | 0~99 |
| playerCount | number | Y | 1~20. 플레이 인원 |
| remainMinutes | number | Y | 남은 시간의 **분**. 0 이상 |
| remainSeconds | number | Y | 남은 시간의 **초**. 0~59 |
| | | | 성공: `분 × 60 + 초`가 `play_minutes × 60` 이하. **실패(`escaped: false`)면 분·초 둘 다 반드시 0** (결정 R2) |
| playedDate | date | | 오늘 또는 그 이전. **비우면 작성일** (결정 R1) |
| content | string | | 200자 이내 |

```json
// 요청
{ "themeId": 9, "rating": 4, "escaped": true, "hintCount": 1, "playerCount": 3,
  "remainMinutes": 3, "remainSeconds": 47, "playedDate": "2026-11-09", "content": "마지막 반전 대박" }
// 응답 201
{ "reviewId": 15 }
```

- 화면은 분·초 두 칸 입력값을 **두 값 그대로** 전송(3분 47초 → `remainMinutes: 3, remainSeconds: 47`). 실패 선택 시 두 칸 비활성화, 둘 다 0 전송.
- 실패인데 분·초 중 하나라도 0이 아니면 400. DB에도 같은 CHECK(`review_fail_ck`) 존재.
- 닉네임 미저장. 표시할 때 JOIN.
- THEME 별점 집계는 **트리거** 처리.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `남은 시간은 제한 시간(70분)보다 길 수 없습니다.` / `탈출에 실패했다면 남은 시간은 0이어야 합니다.` / `초는 0~59입니다.` / `별점은 1~5점입니다.` |
| 404 | 없는 테마 |
| 409 | `이미 이 테마에 후기를 남겼습니다. 내 기록에서 수정해 주세요.` |

#### D-2. 후기 수정

`PUT /api/reviews/{reviewId}` · 작성자 · 200

- 본문: D-1에서 `themeId` 제외. **테마 변경 불가**(트리거가 이 전제로 작성됨).
- 응답: 수정된 후기. D-5 한 줄과 같은 모양.
- 작성한 후기 수정 기능 유지(회의 v2-6).

| 오류 | 언제 |
| --- | --- |
| 403 | 내 후기가 아님 |
| 404 | 없는 후기 |

#### D-3. 후기 삭제

`DELETE /api/reviews/{reviewId}` · 작성자 · 204

- 해당 후기 삭제. VISIBLE 후기였다면 트리거가 테마 별점 집계에서 차감.

#### D-4. 테마 후기 + 평균

`GET /api/themes/{themeId}/reviews` · 공개 · 200 · 화면 S09 후기 칸

```json
{
  "avgRating": 4.0, "reviewCount": 1, "playMinutes": 70,
  "reviews": [
    { "reviewId": 3, "nickname": "힌트없이", "rating": 4, "escaped": true, "hintCount": 0,
      "playerCount": 3, "remainMinutes": 12, "remainSeconds": 34, "playedDate": "2026-10-19",
      "content": "인형 연출이 소름 돋아요.", "createdAt": "2026-10-19T22:00:00",
      "mine": false }
  ]
}
```

- **VISIBLE 후기만** 최신순.
- 화면은 `remainMinutes`·`remainSeconds`를 `12:34 남기고 (70:00 중)` 형태로 표시.
- `mine`이 true인 후기는 화면 맨 앞 배치 + [수정] 버튼. 이미 쓴 테마에서는 "후기 쓰기" 버튼 숨김.

#### D-5. 내 기록

`GET /api/my/reviews` · USER · 200 · 화면 S18 `mypage.html` 내 기록 탭

```json
[
  { "reviewId": 15, "themeId": 9, "themeTitle": "사라진 기억", "storeName": "어둠상자 홍대점", "area": "홍대",
    "posterUrl": "/uploads/posters/3f2a.jpg", "playMinutes": 70,
    "rating": 4, "escaped": true, "hintCount": 1, "playerCount": 3, "remainMinutes": 3, "remainSeconds": 47,
    "playedDate": "2026-11-09", "content": null, "status": "VISIBLE" }
]
```

- 정렬: 플레이한 날 최신순. 숨김(HIDDEN) 후기도 상태와 함께 반환.
- `posterUrl`: 테마 포스터 공개 주소. 포스터 없으면 `null`.
- `area`: 매장의 세부 지역 이름(B-8 지역 목록의 이름). 후기 상세에 "매장 · 지역"으로 표시.
- 각 줄의 "수정" 버튼은 이 값으로 후기 팝업을 채워 열기.
- 후기 팝업의 테마 선택 화면도 이 응답으로 이미 쓴 테마 표시(`js/mypage/review-modal.js`).

#### D-6. 후기 쓸 수 있는 테마

`GET /api/my/review-candidates` · USER · 200 · 화면 S18 "+ 후기 쓰기" 팝업의 "플레이한 테마" 선택칸

```json
[
  { "themeId": 9, "title": "사라진 기억", "storeName": "어둠상자 홍대점", "playMinutes": 70,
    "partyId": 5, "playAt": "2026-11-09T19:00:00", "memberCount": 3 }
]
```

- 내가 참여한 파티 중 `play_at`이 지난 파티의 테마 반환. 그중 **아직 내 후기가 없는** 테마만.
- 같은 테마는 1회만, 가장 최근 파티 기준.
- 화면은 고른 테마의 `playMinutes`로 남은 시간 상한, `memberCount`로 플레이 인원 초기값 설정.
- 파티 없이 간 테마: 테마 상세의 "후기 쓰기"(테마가 정해진 채로 팝업 열림) 또는 팝업의 테마 이름 검색(B-1 `keyword`)으로 선택.
- v1 "후기 요청 팝업(D-10)" 대체. 자동 팝업 삭제(회의 v2-6).

#### D-7. 내 선호 장르 · D-8. 선호 장르 저장

| 번호 | 주소 | 요청 | 응답 |
| --- | --- | --- | --- |
| D-7 | `GET /api/my/genres` | | `[{ "genreId": 1, "name": "공포" }, …]` |
| D-8 | `PUT /api/my/genres` | `{ "genreIds": [1, 2] }` | 200, 저장 뒤 목록 (D-7 모양) |

- 화면: S26 `profile.html`의 선호 장르 칸(v3에서 내 기록 탭에서 이동).
- D-8은 **통째 교체**. 한 트랜잭션에서 삭제 후 재저장. 빈 배열이면 전체 삭제.
- 최초 장르는 손님 가입(A-1) 시 함께 저장.

#### D-9. 맞춤 추천 (메인 배너)

`GET /api/my/recommendations` · USER · 200 · 화면 S08 메인 맨 위 자동 슬라이드

```json
[
  { "themeId": 1, "title": "저주받은 인형의 집", "storeName": "미스터리룸 홍대점", "genres": ["공포", "추리"],
    "difficulty": 4, "playMinutes": 70, "minPeople": 2, "maxPeople": 4, "price": 25000,
    "description": "밤마다 자리를 바꾸는 인형들…", "posterUrl": "/uploads/posters/3f2a.jpg",
    "avgRating": 4.0, "recruitingPartyCount": 2,
    "reason": "공포 · 추리 둘 다 좋아하는 탈출왕 님께" }
]
```

**추천 기준** (회의 v2-7: 별점이 아니라 선호 장르)
1. 공개 테마(OPEN·APPROVED) 중 내 선호 장르가 하나라도 겹치는 테마 선택.
2. 이미 후기를 쓴 테마 제외.
3. 정렬: **겹치는 장르 수 → 평균 별점 → 후기 수 → 최신순**.
4. 최대 5개.

**`reason` 문장 규칙** (서버 생성, 위에서부터 먼저 맞는 것)

| 경우 | 문장 |
| --- | --- |
| 장르 2개 이상 겹침 | `{장르들} 둘 다 좋아하는 {닉네임} 님께` (3개 이상이면 `둘 다` 대신 `모두`. 장르는 ` · `로 연결) |
| 그 장르 안에서 평점 1위 | `{장르} 장르 평점 1위` |
| 최근 14일 등록 | `새로 문을 연 {장르} 테마` |
| 그 밖 | `{장르} 좋아하시면 꼭` |

- 선호 장르가 없거나 맞는 테마가 없으면 **이번 주 인기** 상위 5개 반환(B-1 `sort=popular`와 같은 기준, 결정 C2). 이때도 **이미 후기를 쓴 테마 제외.** `reason`은 `이번 주 인기 테마`.
- **비회원**은 이 API 미호출. 프런트가 B-1 `sort=popular` 상위 5개로 같은 배너 렌더링(ERD 결정 C1·C2).
- 맞춤 추천은 "나중 기능"에서 **이번 범위**로 변경. 마이페이지에는 미표시.

#### D-10. 내 통계 (선택 기능)

`GET /api/my/stats` · USER · 200 · 화면 S18 내 기록 플레이 통계 (카드 4개 + 지역별 제패율)

```json
{ "playCount": 6, "escapeCount": 5, "escapeRate": 83,
  "noHintCount": 2, "noHintRate": 33,
  "avgRemainSeconds": 365, "avgRemainRate": 15,
  "conquerCount": 6, "themeCount": 48, "conquerRate": 13,
  "byRegion": [
    { "regionId": 1, "name": "서울", "playedCount": 5, "themeCount": 30, "rate": 17 },
    { "regionId": 2, "name": "경기", "playedCount": 1, "themeCount": 8, "rate": 13 },
    { "regionId": 8, "name": "제주", "playedCount": 0, "themeCount": 0, "rate": 0 }
  ] }
```

- 내 후기 기준 계산. 숨김 후기도 포함(본인 기록이므로).
- 비율은 모두 % 정수(반올림). 분모가 0이면 0.

| 값 | 뜻 |
|---|---|
| `escapeRate` | 탈출 성공 ÷ 플레이 |
| `noHintCount`, `noHintRate` | 힌트 0개로 탈출 성공한 수, 그 수 ÷ 플레이 |
| `avgRemainSeconds` | 평균 남은 시간(초, 반올림). **탈출 성공한 판만** 평균 (실패는 남은 시간 0이라 제외). 성공이 없으면 `null` |
| `avgRemainRate` | 탈출 성공한 판별 남은 시간 ÷ 그 테마 제한 시간의 평균 %. 테마마다 제한 시간이 달라 비율도 제공. 성공이 없으면 0 |
| `conquerCount`, `themeCount`, `conquerRate` | 전국 제패: 현재 공개 테마 중 내가 플레이(후기 작성)한 수 ÷ 공개 테마 수 |
| `byRegion` | 큰 지역(B-12 REGION)별 제패. 매장 세부 지역(`store.area`) → 큰 지역으로 묶음. 8개 지역 모두 `sort_order` 순으로 반환, 테마 없는 지역은 0 / 0 |

- 현재 비공개 테마(닫힌 테마, 미승인 매장)는 제패 계산에서 제외 → `conquerCount`가 `playCount`보다 작을 수 있음.
- v1 장르별 통계(`topGenre`, `byGenre`)는 화면에서 제외 결정으로 삭제.


## 6. 자동 작업

| 이름 | 담당 | 주기 | 하는 일 |
| --- | --- | --- | --- |
| 모집 기한 마감 | A | 매일 03:00 (`@Scheduled(cron = "0 0 3 * * *", zone = "Asia/Seoul")`) | `UPDATE party SET status='CLOSED' WHERE status IN ('RECRUITING','FULL') AND deadline_at <= SYSDATE` (정원 마감 파티도 포함, 11/23 변경) |
| 별점 집계 | D (DB) | 후기 등록·수정·삭제 시마다 | 트리거 `trg_review_theme_stats` ([ERD 5-1](ERD.md#5-1-후기--테마-별점-집계-트리거)) |
| 테마 수정일 | C (DB) | 테마 내용 변경 시 | 트리거 `trg_theme_updated_at` |

- 스케줄러 실행 전까지는 목록(A-12)·참여(A-16) API가 `deadline_at > SYSDATE`를 직접 검사. 화면 응답의 상태도 기한이 지났으면 `CLOSED`로 표시(`PartyServiceImpl.shownStatus`).

---

## 7. 화면별 호출 API

- 파일 칸은 목업(`visualization/`) 파일명 기준. "(프런트 레포)" 표시는 프런트 레포에만 있는 화면.

| 화면 | 파일 (목업) | 담당 | 호출 API |
| --- | --- | --- | --- |
| S01 사이드 메뉴 · 통합 검색 | `js/common.js` | A | (토큰으로 그림), B-7, B-8 → 검색하면 메인 B-1 |
| S02 로그인 | `login.html` | A | A-6 |
| 모든 화면 (공통) | `js/common/api.js`, `header.js` | A | A-32 자동 재발급, A-33 로그아웃 |
| 아이디 찾기 | `find-id.html` (프런트 레포) | A | A-25 |
| 비밀번호 찾기 | `find-password.html` (프런트 레포) | A | A-26, A-27, A-28 |
| S03 가입 유형 선택 | `signup.html` | A | 없음 |
| S03-1 손님 가입 | `signup-user.html` | A | A-3, A-4, A-23, A-24, B-7, A-1 |
| S03-2 사장 가입 | `signup-owner.html` | A | A-3, A-4, A-5, A-23, A-24, A-2 |
| S04 파티 목록 | `party-list.html` | A | A-12, B-7, B-12 (지역), A-16 (참여 팝업) |
| S05 파티 만들기 | `party-form.html` | A | B-1 (테마 선택), B-3, A-14 |
| S06 파티 방 | `party-room.html` | A | A-13, A-20, A-21, A-17, A-18, A-19, A-15 |
| S07 회원 관리 | `admin-members.html` | A | A-10 |
| S08 메인 + 추천 배너 | `main.html` (실제 `index.html`) | B·D | B-1, D-9 (로그인 손님) |
| S09 테마 상세 | `theme.html` | B | B-2, B-3, D-4, B-4, B-5, D-1·D-2 (후기 팝업) |
| S10 찜 목록 탭 | `wishes.html` | B | B-6, B-5 |
| ~~S11 매장 지도~~ | — | B | 삭제. 지도는 매장 상세(B-10) 안에만 |
| S12 사장 홈 ① 내 매장 | `owner.html` | C | C-1 |
| S12 사장 홈 ② 매장 | `owner-store.html` (프런트 레포, 11/23) | C | C-1, C-5, C-10 (테마별 회차 수), C-9, C-20 |
| S13 사장 홈 ③ 테마 | `owner-theme.html` [기본 정보]·[시간표] 탭 | C | C-1, B-7, C-6, C-7, C-8, C-9, C-10, C-11 |
| ~~S14 시간표 관리~~ | ~~`owner-slots.html`~~ | C | S13 [시간표] 탭으로 통합 (11/23) |
| S15 테마 승인 목록 | `admin-themes.html` | C | C-17 |
| S17 후기 팝업 (공용) | `js/review-modal.js` | D | D-6 (테마 고르기), B-1 (테마 이름 검색), D-5 (이미 쓴 테마 표시), B-2 (인원 범위), D-1, D-2 |
| S18 마이페이지 내 기록 | `mypage.html` (요약), `?view=reviews` (전체 후기) | D | D-10, D-5, D-3, 후기 팝업 |
| S20 내 채팅 탭 | `chats.html` | A | A-22, 후기 팝업 (끝난 파티) |
| S21 매장 등록 | `store-form.html` | C | B-12, C-2, C-3, C-4 |
| S22 매장 승인 목록 | `admin-stores.html` | C | C-13 |
| S23 매장 승인 상세 | `admin-store-detail.html` | C | C-14, C-15, A-11, C-16 |
| S24 테마 승인 상세 | `admin-theme-detail.html` | C | C-18, C-19 |
| S25 관리자 홈 | `admin.html` | C | C-12, C-13, C-17 |
| S26 내 정보 탭 | `profile.html` | A·D | A-7, A-4, A-8, A-9, A-29, A-30, A-31, B-7, D-7, D-8 |
| S27 매장 목록 | `stores.html` | B | B-8, B-9 |
| S28 매장 상세 | `store.html` | B | B-10 |
| 매장 관리 (관리자) | `owner.html` · `owner-store.html` · `store-form.html` 등 (사장 화면 공용) | C | C-1 ~ C-11, C-20 (관리자 권한), C-14 · C-15 · A-11 (매장 상세의 서류) |

---

## 8. v1 → v3 번호 대응표

| v1 | v1 기능 | v3 | 바뀐 점 |
| --- | --- | --- | --- |
| A-1 | 회원가입 | **A-1 / A-2** | 손님·사장 가입 분리. ownerType 삭제, genreIds·사업자등록증 추가 |
| A-2 | 아이디 중복 | A-3 | 주소 `check-login-id` |
| — | | A-4, A-5 | 추가: 닉네임·사업자번호 중복 확인 |
| A-3 | 로그인 | A-6 | ownerType 삭제, 정지 403 삭제 |
| A-4 | 내 정보 | A-7 | |
| — | | A-8, A-9 | 추가: 닉네임·비밀번호 변경 |
| A-5 | 회원 목록 | A-10 | role 필터, countByRole |
| A-6 | 정지·해제 | 삭제 | 회원 정지 기능 삭제 |
| — | | A-11 | 추가: 사업자등록증 보기 |
| A-7 | 파티 목록 | A-12 | 모집 중만, 장르 여러 개·검색, intro·deadlineAt·joined·kicked |
| A-8 | 파티 상세 | A-13 | 참여자만, myRole |
| A-9 | 파티 만들기 | A-14 | intro, deadlineAt, 시간표·공휴일 검사 |
| — | | A-15 | 추가: 파티 삭제 (status DELETED) |
| A-10 | 참여 | A-16 | 안내 줄, 기한·강퇴 검사 |
| A-11 | 나가기 | A-17 | |
| — | | A-18 | 추가: 강퇴 (status KICKED, 재참여 불가) |
| A-12 | 모집 마감 | A-19 | |
| A-13 | 새 채팅 | A-20 | msgType, mine |
| A-14 | 채팅 보내기 | A-21 | |
| — | | A-22 | 추가: 내 채팅 목록 |
| B-1 | 테마 목록 | B-1 | keyword는 테마 이름만 (매장 이름은 B-9), 공휴일 규칙, recruitingPartyCount |
| B-2 | 상세 | B-2 | recruitingPartyCount |
| B-3 | 시간표 | B-3 | 주중/주말·공휴일 반복, endTime, status 삭제 |
| B-4~B-8 | 찜·취소·찜 목록·장르·지역 | B-4~B-8 | 찜 목록에 status |
| — | | B-9, B-10 | 추가: 매장 목록·상세 (websiteUrl) |
| — | | B-12 | 추가: 지역 전체 (매장 등록 지역 select) |
| B-9 | 지도 | — | 삭제 (매장 상세 안 지도로 충분) |
| C-1 | 관리 매장 | C-1 | 점주·본사 구분 삭제, status·rejectReason·websiteUrl |
| — | | C-2 | 추가: 사업장 번호 중복 확인 |
| C-2 | 매장 등록 | C-3 | multipart, 사업장등록증, 웹사이트·영업시간·소개, 브랜드 삭제 |
| C-3 | 매장 수정 | C-4 | 수정하면 무조건 재승인 |
| C-4 | 매장 테마 목록 | C-5 | rejectReason |
| — | | C-6 | 추가: 테마 수정용 상세 |
| C-5 | 테마 등록 | C-7 | multipart(사진), APPROVED 매장만 |
| C-6 | 테마 수정 | C-8 | |
| C-7 | 운영 종료·재개 | C-9 | |
| C-8 | 시간표 등록 (startAts[]) | C-10 / C-11 | 주중/주말 보기 + 통째 저장 |
| C-9 | 시간표 마감·열기 | 삭제 | 회차별 마감 없음 |
| — | | C-12 | 추가: 관리자 홈 요약 |
| — | | C-13 ~ C-16 | 추가: 매장 승인 목록·상세·서류·처리(반려 사유) |
| C-10 | 테마 승인 대기 | C-17 | |
| — | | C-18 | 추가: 테마 승인 상세 |
| C-11 | 테마 승인·반려 | C-19 | 반려 사유 필수, 매장 승인 확인 |
| C-12, C-13 | 신고 목록·처리 | 삭제 (나중) | 이번 범위 제외 |
| C-14 | 브랜드 목록 | 삭제 | 브랜드 정보 받지 않음 |
| C-15 | 브랜드 등록 (본사) | 삭제 | 본사 계정·브랜드 없음 |
| D-1 | 후기 작성 | D-1 | playerCount, remainMinutes·remainSeconds(분·초 두 칸, 실패면 0), escaped boolean |
| D-2, D-3 | 수정·삭제 | D-2, D-3 | |
| D-4 | 테마 후기 | D-4 | mine, 새 필드 |
| D-5 | 내 기록 | D-5 | |
| — | | D-6 | 추가: 후기 쓸 수 있는 테마 |
| D-6, D-7 | 선호 장르 | D-7, D-8 | 화면이 내 정보 탭으로 이동 |
| D-8 | 맞춤 추천 | D-9 | 메인 배너용, reason·description, 이번 범위로 |
| D-9 | 통계 | D-10 | |
| D-10 | 후기 요청 목록 | 삭제 | 자동 팝업 삭제 → D-6이 대신 |
| D-11 | 후기 신고 | 삭제 | 신고 기능 전체 삭제 (11/23) |
| — | | A-23 ~ A-31 | 추가 (11/24): 이메일 인증, 아이디 찾기, 비밀번호 재설정, 내 이메일 변경, 회원 탈퇴 |
| — | | C-20 | 추가 (11/24): 매장 폐업 |

## 9. 이번 범위에서 뺀 것

| 기능 | 이유 | 나중에 넣을 때 |
| --- | --- | --- |
| 회원 정지·해제 | 회의 v2-9에서 삭제 | MEMBER.status 컬럼 + 관리자 API |
| 후기 신고 (접수·처리 모두) | 11/23 삭제. REPORT 테이블도 없앰 | 신고 테이블 + 접수 API + 관리자 처리 화면. 숨기면 트리거가 별점에서 자동으로 뺌 |
| 후기 요청 자동 팝업 | 회의 v2-6에서 삭제 | — |
| 회차별 마감 | 결정 T2 | 예외 테이블 필요 |
| 브랜드 | 결정 B1 (브랜드 정보 받지 않음) | — |
| 공휴일 관리 화면 | HOLIDAY는 더미 데이터로 해마다 넣음 | 관리자 API |
| 실시간 채팅 (WebSocket) | v1부터 선택 기능 | 지금은 3초마다 A-20 |
| 크롤링 시간표 더블체크 | v1 선택 기능, 목업 없음 | THEME.source = CRAWL 자리만 남겨 둠 |

- 11/18 결정 사항: [ERD 8. 확정된 결정](ERD.md#8-확정된-결정-1118). 목업 HTML(`visualization/`)도 이 결정 기준으로 수정 완료.

