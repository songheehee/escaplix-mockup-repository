# Escaplix API 명세 (v3)

이 문서는 목업(`escaplix-mockup-repository/visualization`)에서 구현하기로 정한 화면을 기준으로 정리한 API입니다.

- 기준 자료: 기존 README의 API 49개(v1), `노션_회의록_v2.md`, PM 미팅(11/17), 목업 v3 피드백
- 데이터 구조: [`docs/ERD.md`](ERD.md)

API는 모두 **63개**예요. 11/18 팀 결정([ERD 8번](ERD.md#8-확정된-결정-1118))까지 반영했어요. 매장 사진(결정 S5)도 들어가 있어요.

| 담당 | 영역 | 개수 |
| --- | --- | --- |
| A 회수 | 회원 · 파티 | 22 |
| B 송희 | 테마 · 매장 탐색 | 11 |
| C 승현 | 사장 · 관리자 | 19 |
| D 하나 | 기록 · 추천 | 11 |

번호는 v1과 달라졌어요. 옛 번호가 어디로 갔는지는 [8. v1 → v3 번호 대응표](#8-v1--v3-번호-대응표)에 있어요.

## 목차

1. [공통 규칙](#1-공통-규칙)
2. [전체 목록](#2-전체-목록)
3. [역할군별 보기 (비회원 · 손님 · 사장 · 관리자)](#3-역할군별-보기)
4. [서버 구성](#4-서버-구성)
5. [상세 명세](#5-상세-명세)
   - [A · 회원](#a--회원-11), [A · 파티](#a--파티-11)
   - [B · 테마·매장 탐색](#b--테마매장-탐색-11)
   - [C · 사장](#c--사장-11), [C · 관리자](#c--관리자-8)
   - [D · 기록·추천](#d--기록추천-11)
6. [자동 작업 (스케줄러)](#6-자동-작업)
7. [화면별 호출 API](#7-화면별-호출-api)
8. [v1 → v3 번호 대응표](#8-v1--v3-번호-대응표)
9. [이번 범위에서 뺀 것](#9-이번-범위에서-뺀-것)

---

## 1. 공통 규칙

### 1-1. 주소와 요청 방식

- **서버는 1개(모놀리식)** 예요: `http://localhost:8081` (결정 D1). 프런트는 `js/common/api.js`에 적은 주소로만 요청해요.
- **CORS**: `http://127.0.0.1:5500`, `http://localhost:5500` 두 주소를 허용해요.
- **주소 짓는 법**: `/api/` 뒤에 소문자 복수 명사를 쓰고, 동작은 HTTP 메서드로 나타내요.
  - 사장 전용은 `/api/owner/**`, 관리자 전용은 `/api/admin/**`, 내 것은 `/api/my/**`예요.
- **JSON 키**는 camelCase로 써요.
- **닉네임**은 어느 API든 MEMBER와 JOIN해서 내려 줘요. 복사본이 없어서 닉네임을 바꾸면 모든 화면에 바로 반영돼요(결정 D2).

### 1-2. 날짜 형식

| 종류 | 형식 | 예 |
| --- | --- | --- |
| 날짜 | `yyyy-MM-dd` | `2026-11-20` |
| 일시 | `yyyy-MM-ddTHH:mm:ss` | `2026-11-20T19:00:00` |
| 시각 | `HH:mm` | `19:00` |

모두 한국 시간이에요.

### 1-3. 로그인 토큰 (JWT)

- 로그인(A-6)하면 받은 `token`을 `sessionStorage`에 저장해요.
- 이후 요청마다 헤더에 `Authorization: Bearer {token}`을 붙여요.
- 토큰 안에는 `memberId`, `nickname`, `role`을 넣고 **1시간** 뒤 만료돼요. 비밀번호는 넣지 않아요.
  - v1에 있던 `ownerType`은 사장 구분이 없어져서 빠졌어요.
- 회원번호는 **언제나 토큰에서 꺼내요.** 요청 본문이나 주소로 받은 회원번호를 "나"로 믿으면 안 돼요.
- 로그아웃은 API가 없어요. 프런트가 `sessionStorage`에서 토큰을 지우면 끝나요.

### 1-4. 권한 표기

| 표기 | 누구 | 서버가 하는 검사 |
| --- | --- | --- |
| 공개 | 누구나 | 토큰이 있으면 읽어서 `wished`, `mine` 같은 개인 값만 채움 |
| 로그인 | 로그인한 누구나 | 토큰이 있고 유효한지 |
| USER | 손님 | `role = USER` |
| OWNER | 사장 | `role = OWNER` |
| OWNER\* | 사장, 그리고 관리자 직접 등록 | `role IN (OWNER, ADMIN)`. 사장이면 **자기 매장·테마인지** 매번 확인 |
| ADMIN | 관리자 | `role = ADMIN` |
| 방장 / 참여자 / 작성자 | 그 데이터의 주인 | DB에서 확인. 화면에서 버튼을 숨겨도 서버가 다시 확인해야 해요 |

**관리자 직접 등록 (OWNER\*)**

회의 v2-3에서 "사장이 오지 않았지만 손님 수요가 있으면 관리자도 매장·테마·시간표를 등록할 수 있다"고 정했어요. 그래서 관리자도 사장 API를 그대로 써요. 관리자가 부르면 이렇게 처리해요(ERD 결정 S3).

- 소유 검사를 건너뛰어요.
- 매장은 `owner_id = NULL`, `status = APPROVED`로 바로 공개돼요.
- 테마는 `source = ADMIN`, `status = OPEN`으로 바로 공개돼요.

### 1-5. 응답 형식

- **성공**하면 데이터를 JSON으로 그대로 보내요. 감싸는 껍데기는 없어요.
- **실패**하면 상태 코드와 `{"message": "화면에 그대로 보여 줄 한국어 문장"}`을 보내요.
- 응답에는 **DTO만** 넣어요. 엔티티를 그대로 보내면 안 돼요(비밀번호, 파일 경로가 새어 나가요).

| 코드 | 언제 |
| --- | --- |
| 200 | 조회·수정 성공 |
| 201 | 등록 성공 |
| 204 | 삭제 성공 (본문 없음) |
| 400 | 보낸 값이 잘못됨 (형식, 길이, 범위, 규칙 위반) |
| 401 | 토큰이 없거나 틀리거나 만료됨, 로그인 실패 → 프런트는 로그인 화면으로 |
| 403 | 권한 없음 (역할 불일치, 남의 매장·파티·후기) |
| 404 | 없는 번호, 또는 손님에게 보이면 안 되는 상태(승인 전 테마 등) |
| 409 | 중복, 상태 충돌 (아이디 중복, 이미 찜함, 정원 다 참, 이미 처리됨) |

### 1-6. 파일 올리기 (multipart)

파일을 받는 API는 다섯 개예요: A-2, C-3, C-4, C-7, C-8.

- 이 API들은 `multipart/form-data`로 받아요. 지금 `api.js`는 JSON만 보내니까 **파일용 요청 함수가 하나 더 필요해요**(A 공용 파일).
  - 이 함수에서는 `Content-Type`을 직접 넣지 말아야 해요. 브라우저가 boundary를 붙여서 자동으로 넣어 줘요.
- 받을 수 있는 이미지는 jpg, png, webp이고 **5MB 이하**만 받아요. 확장자만 보지 말고 실제 파일 형식도 확인해요. 저장할 이름은 UUID로 새로 지어요([ERD 6](ERD.md#6-파일이미지-저장-규칙)).
- 사진은 공개 주소로 보여 줘요(결정 S5).
  - 테마 사진: `/uploads/posters/{파일}` (C-7, C-8에서 올림)
  - 매장 사진: `/uploads/stores/{파일}` (C-3, C-4에서 올림)
  - 응답의 `posterUrl`·`photoUrl`은 이 주소 그대로예요. 프런트는 서버 주소(`API_BASE`)를 앞에 붙여서 써요.
  - 더미 데이터 사진은 백엔드 `src/main/resources/uploads/posters/`, `…/uploads/stores/`에 있어요. 같은 주소로 내려가요([ERD 6](ERD.md#6-파일이미지-저장-규칙)).
  - 사진이 없으면 `null`이에요. 프런트는 장르 색 그라데이션으로 대신 그려요.
- 사업자등록증과 사업장등록증은 **관리자 API(A-11, C-15)로만** 내려 줘요.

### 1-7. 보안 규칙 (모든 API 공통)

- SQL 값은 반드시 `#{}`나 JPA 파라미터로 바인딩해요. 문자열을 이어 붙여 SQL을 만들면 안 돼요.
- 사용자가 쓴 글(닉네임, 제목, 한마디, 채팅, 후기, 신고 사유)은 프런트에서 **`textContent`로만** 출력해요.
- 링크 값(`bookingUrl`)은 `http://`나 `https://`로 시작하는지 서버가 확인해요. `javascript:`로 시작하는 링크가 들어오지 않게 막는 거예요.
- 목록 API는 페이지 나누기 없이 다 보내요. 데이터가 적기 때문이에요. 채팅만 `after`로 잘라서 받아요.

---

## 2. 전체 목록

| 번호 | 메서드 | 주소 | 기능 | 권한 | 성공 |
| --- | --- | --- | --- | --- | --- |
| **A-1** | POST | `/api/members/user` | 손님 회원가입 (+선호 장르) | 공개 | 201 |
| **A-2** | POST | `/api/members/owner` | 사장 회원가입 (+사업자등록증) 📎 | 공개 | 201 |
| **A-3** | GET | `/api/members/check-login-id?loginId=` | 아이디 중복 확인 | 공개 | 200 |
| **A-4** | GET | `/api/members/check-nickname?nickname=` | 닉네임 중복 확인 | 공개 | 200 |
| **A-5** | GET | `/api/members/check-biz-no?bizNo=` | 사업자등록번호 중복 확인 | 공개 | 200 |
| **A-6** | POST | `/api/auth/login` | 로그인 | 공개 | 200 |
| **A-7** | GET | `/api/members/me` | 내 정보 | 로그인 | 200 |
| **A-8** | PUT | `/api/members/me` | 닉네임 바꾸기 (새 토큰) | 로그인 | 200 |
| **A-9** | PUT | `/api/members/me/password` | 비밀번호 바꾸기 | 로그인 | 204 |
| **A-10** | GET | `/api/admin/members?keyword=&role=` | 회원 목록 | ADMIN | 200 |
| **A-11** | GET | `/api/admin/members/{memberId}/biz-file` | 사업자등록증 이미지 | ADMIN | 200 |
| **A-12** | GET | `/api/parties?genreIds=&keyword=&themeId=` | 파티 목록 (모집 중만) | 로그인 | 200 |
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
| **B-1** | GET | `/api/themes?keyword=&area=&date=&people=&genreId=&sort=` | 테마 목록·검색·필터 | 공개 | 200 |
| **B-2** | GET | `/api/themes/{themeId}` | 테마 상세 | 공개 | 200 |
| **B-3** | GET | `/api/themes/{themeId}/slots?date=` | 그날 시간표 | 공개 | 200 |
| **B-4** | POST | `/api/themes/{themeId}/wish` | 찜 | USER | 201 |
| **B-5** | DELETE | `/api/themes/{themeId}/wish` | 찜 취소 | USER | 204 |
| **B-6** | GET | `/api/my/wishes` | 찜 목록 | USER | 200 |
| **B-7** | GET | `/api/genres` | 장르 목록 | 공개 | 200 |
| **B-8** | GET | `/api/areas` | 지역 목록 | 공개 | 200 |
| **B-9** | GET | `/api/stores?area=&keyword=` | 매장 목록 | 공개 | 200 |
| **B-10** | GET | `/api/stores/{storeId}` | 매장 상세 (+테마) | 공개 | 200 |
| **B-11** | GET | `/api/stores/map` | 지도용 매장 (선택 기능) | 공개 | 200 |
| **C-1** | GET | `/api/owner/stores` | 내 매장 목록 | OWNER\* | 200 |
| **C-2** | GET | `/api/owner/stores/check-biz-place-no?bizPlaceNo=` | 사업장 등록번호 중복 확인 | OWNER\* | 200 |
| **C-3** | POST | `/api/owner/stores` | 매장 등록 📎 | OWNER\* | 201 |
| **C-4** | PUT | `/api/owner/stores/{storeId}` | 매장 수정 📎 | OWNER\*(내 매장) | 200 |
| **C-5** | GET | `/api/owner/stores/{storeId}/themes` | 매장의 테마 목록 | OWNER\*(내 매장) | 200 |
| **C-6** | GET | `/api/owner/themes/{themeId}` | 테마 수정용 상세 | OWNER\*(내 테마) | 200 |
| **C-7** | POST | `/api/owner/themes` | 테마 등록 📎 | OWNER\*(내 매장) | 201 |
| **C-8** | PUT | `/api/owner/themes/{themeId}` | 테마 수정 📎 | OWNER\*(내 테마) | 200 |
| **C-9** | PUT | `/api/owner/themes/{themeId}/status` | 운영 종료·재개 | OWNER\*(내 테마) | 200 |
| **C-10** | GET | `/api/owner/themes/{themeId}/slots` | 주중/주말 시간표 보기 | OWNER\*(내 테마) | 200 |
| **C-11** | PUT | `/api/owner/themes/{themeId}/slots` | 주중/주말 시간표 저장 (통째 교체) | OWNER\*(내 테마) | 200 |
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
| **D-11** | POST | `/api/reviews/{reviewId}/report` | 후기 신고 | USER·OWNER | 201 |

📎 = `multipart/form-data` (파일 포함)

---

## 3. 역할군별 보기

같은 API가 여러 역할에 나올 수 있어요. 권한은 [2. 전체 목록](#2-전체-목록)이 기준이에요.

### 비회원 (로그인 전)

| 하는 일 | API |
| --- | --- |
| 가입 | A-1 손님 가입, A-2 사장 가입, A-3·A-4·A-5 중복 확인 |
| 로그인 | A-6 |
| 테마 구경 | B-1 목록·검색·필터, B-2 상세, B-3 시간표, B-7 장르, B-8 지역, D-4 후기 |
| 매장 구경 | B-9 매장 목록, B-10 매장 상세, B-11 지도 |

### 손님 (USER)

비회원이 할 수 있는 것에 더해 아래를 할 수 있어요.

| 하는 일 | API |
| --- | --- |
| 내 정보 | A-7 보기, A-8 닉네임, A-9 비밀번호, D-7·D-8 선호 장르 |
| 파티 | A-12 목록, A-14 만들기, A-16 참여, A-13 방 정보, A-20·A-21 채팅, A-17 나가기, A-22 내 채팅 목록 |
| 파티 방장 | A-15 삭제, A-18 강퇴, A-19 모집 마감 |
| 찜 | B-4 찜, B-5 취소, B-6 찜 목록 |
| 후기 | D-1 쓰기, D-2 수정, D-3 삭제, D-5 내 기록, D-6 쓸 수 있는 테마, D-11 신고 |
| 추천·통계 | D-9 맞춤 추천, D-10 통계 |

### 사장 (OWNER)

| 하는 일 | API |
| --- | --- |
| 내 정보 | A-7, A-8, A-9 |
| 매장 | C-1 내 매장, C-2 번호 중복 확인, C-3 등록, C-4 수정 |
| 테마 | C-5 매장의 테마, C-6 수정용 상세, C-7 등록, C-8 수정, C-9 운영 종료·재개, B-7 장르 |
| 시간표 | C-10 보기, C-11 저장 |
| 후기 신고 | D-4 후기 보기, D-11 신고 (자기 매장 후기를 지울 수는 없어요. 별점 조작 방지) |

### 관리자 (ADMIN)

| 하는 일 | API |
| --- | --- |
| 관리자 홈 | C-12 숫자 요약, A-10 회원 수, C-13·C-17 처리할 목록 |
| 매장 승인 | C-13 목록, C-14 상세, C-15 사업장등록증, A-11 사장 사업자등록증, C-16 승인·반려 |
| 테마 승인 | C-17 목록, C-18 상세, C-19 승인·반려 |
| 회원 관리 | A-10 목록·검색·역할 필터 |
| 직접 등록 | C-1 ~ C-11을 관리자 권한으로 사용 ([1-4](#1-4-권한-표기)) |

---

## 4. 서버 구성

**서버 1개(모놀리식)로 확정**했어요(결정 D1).

- 모든 API를 `:8081` 하나에서 받아요. (8080은 Oracle XE 자체 웹서버가 쓰고 있어서 피함)
- 모든 테이블이 한 DB에 있어서, 회원번호 컬럼도 전부 진짜 FK예요.
- 그래서 v3 초안에 있던 "서버를 넘나드는 곳" 처리가 모두 필요 없어졌어요.
  - 닉네임은 MEMBER와 JOIN해요.
  - 가입할 때 선호 장르도 같은 트랜잭션으로 넣어요.
  - 관리자 화면의 사장 정보도 JOIN해서 한 번에 내려 줘요.

## 5. 상세 명세

각 API는 아래 순서로 정리했어요.

- **요청**: 보내는 값과 규칙
- **응답**: 예시
- **처리 순서와 규칙**: 서버가 해야 할 검사와 트랜잭션
- **오류**: 실패할 때 상태 코드와 메시지

본문 칸의 "필수"는 ✔가 붙은 값이에요.

---

### A · 회원 (11)

#### A-1. 손님 회원가입

`POST /api/members/user` · 공개 · 201 · 화면 S03-1 `signup-user.html`

| 본문 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| loginId | string | ✔ | 영문 소문자·숫자 4~20자 |
| password | string | ✔ | 4~20자 (더미 계정 `1234`에 맞춤. 길이 규칙은 팀이 정하기) |
| nickname | string | ✔ | 2~20자 |
| genreIds | number[] | | 좋아하는 장르. 없으면 빈 배열 |

- **비밀번호 확인 칸**은 화면(JS)에서만 비교하고 서버에는 보내지 않아요.
- 아이디·닉네임 중복 확인 버튼(A-3, A-4)을 눌렀어도, 가입할 때 서버가 **다시** 확인해요.

```json
// 요청
{ "loginId": "user9", "password": "1234", "nickname": "새회원", "genreIds": [1, 2] }
// 응답 201
{ "memberId": 12 }
```

**처리 순서와 규칙**
1. 값을 검사하고, 비밀번호를 BCrypt로 바꿔요.
2. **한 트랜잭션**에서 MEMBER(`role = USER`)와 MEMBER_GENRE(고른 장르 수만큼)를 넣어요.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `아이디는 영문 소문자와 숫자 4~20자로 입력해 주세요.` / `없는 장르입니다.` |
| 409 | `이미 사용 중인 아이디입니다.` / `이미 사용 중인 닉네임입니다.` |

#### A-2. 사장 회원가입 📎

`POST /api/members/owner` · 공개 · 201 · 화면 S03-2 `signup-owner.html`

| 폼 칸 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| loginId | text | ✔ | A-1과 같음 |
| password | text | ✔ | A-1과 같음 |
| nickname | text | ✔ | 손님에게 보이는 이름. 2~20자 |
| bizNo | text | ✔ | 사업자등록번호 `^\d{3}-\d{2}-\d{5}$` |
| bizFile | file | ✔ | 사업자등록증 이미지 jpg/png/webp, 5MB 이하 |

```json
// 응답 201
{ "memberId": 13 }
```

**처리 순서와 규칙**
1. 값과 파일을 검사해요.
2. 파일을 `private/biz/UUID.ext`에 저장해요.
3. MEMBER에 `role = OWNER`, `biz_no`, `biz_file_path`를 넣어요.
4. DB 저장이 실패하면 **이미 저장한 파일을 지워요.**

- 가입하면 바로 로그인할 수 있어요. 승인은 매장 단위로 받아요(ERD 결정 M1).

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `사업자등록번호 형식이 올바르지 않습니다.` / `이미지 파일(jpg, png, webp)만 올릴 수 있습니다.` / `파일은 5MB까지 올릴 수 있습니다.` |
| 409 | 아이디·닉네임 중복 / `이미 등록된 사업자등록번호입니다.` |

#### A-3 / A-4 / A-5. 중복 확인

| 번호 | 주소 | 쿼리 | 화면 |
| --- | --- | --- | --- |
| A-3 | `GET /api/members/check-login-id` | `loginId` | 손님·사장 가입 |
| A-4 | `GET /api/members/check-nickname` | `nickname` | 가입, 내 정보(닉네임 바꿀 때) |
| A-5 | `GET /api/members/check-biz-no` | `bizNo` | 사장 가입 |

```json
// 응답 200
{ "available": true }
```

- 형식이 틀리면 400이에요. 이미 있으면 400이 아니라 `available: false`로 답해요.

#### A-6. 로그인

`POST /api/auth/login` · 공개 · 200 · 화면 S02 `login.html`

```json
// 요청
{ "loginId": "user1", "password": "1234" }
// 응답 200
{ "token": "eyJhbGciOi...", "memberId": 4, "nickname": "탈출왕", "role": "USER" }
```

- 로그인 화면은 하나예요. 프런트는 응답의 `role`을 보고 다음 화면으로 보내요.

| role | 이동할 화면 |
| --- | --- |
| USER | 메인 `index.html` |
| OWNER | 사장 홈 `owner.html` |
| ADMIN | 관리자 홈 `admin.html` |

- v1에 있던 "정지 회원 403"은 없어졌어요(회의 v2-9).

| 오류 | 메시지 |
| --- | --- |
| 401 | `아이디 또는 비밀번호가 틀렸습니다.` (아이디가 없는 경우와 비밀번호가 틀린 경우를 같은 문장으로) |

#### A-7. 내 정보

`GET /api/members/me` · 로그인 · 200 · 화면 S26 `profile.html`

```json
// 응답 200 (손님)
{ "memberId": 4, "loginId": "user1", "nickname": "탈출왕", "role": "USER", "createdAt": "2026-11-16T10:00:00" }
// 응답 200 (사장)
{ "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대", "role": "OWNER", "bizNo": "111-22-33333", "createdAt": "2026-11-16T10:00:00" }
```

- 선호 장르는 D-7로 따로 받아요.

#### A-8. 닉네임 바꾸기

`PUT /api/members/me` · 로그인 · 200 · 화면 S26 기본 정보 칸

```json
// 요청
{ "nickname": "탈출의신" }
// 응답 200
{ "nickname": "탈출의신", "token": "eyJ...새 토큰" }
```

- 토큰 안에 닉네임이 들어 있어요. 그래서 바꾸면 **새 토큰**을 내려 주고, 프런트는 `sessionStorage`의 토큰을 새 것으로 바꿔요.
- 후기·파티·채팅은 닉네임을 MEMBER에서 JOIN해서 보여 줘요. 그래서 **이전에 쓴 기록도 모두 새 닉네임으로** 보여요(결정 D2).

| 오류 | 메시지 |
| --- | --- |
| 400 | 길이 위반 |
| 409 | `이미 사용 중인 닉네임입니다.` |

#### A-9. 비밀번호 바꾸기

`PUT /api/members/me/password` · 로그인 · 204 · 화면 S26 비밀번호 변경 칸

```json
{ "currentPassword": "1234", "newPassword": "5678" }
```

- 지금 비밀번호를 BCrypt로 비교해요.
- 틀려도 **400**으로 답해요. 401로 답하면 프런트가 로그아웃시켜 버려요.
- 새 비밀번호가 지금 비밀번호와 같아도 400이에요.
- "새 비밀번호 확인" 칸은 화면에서만 비교해요.

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
      "bizNo": "111-22-33333", "managedStoreCount": 2, "createdAt": "2026-11-16T10:00:00" },
    { "memberId": 4, "loginId": "user1", "nickname": "탈출왕", "role": "USER",
      "bizNo": null, "managedStoreCount": null, "createdAt": "2026-11-16T10:00:00" }
  ]
}
```

- `countByRole`은 keyword·role 조건과 상관없이 전체 수예요. 역할 탭 숫자에 써요.
- `managedStoreCount`는 사장의 매장 수예요(STORE JOIN). 상태와 상관없이 셉니다.
- 회원 정지·해제 API(v1 A-6)는 **없어요**.

#### A-11. 사업자등록증 이미지 (관리자)

`GET /api/admin/members/{memberId}/biz-file` · ADMIN · 200 · 화면 S23 매장 승인 상세

- 응답은 JSON이 아니라 **이미지 자체**예요. `Content-Type: image/png` 같은 형식으로 보내요.
- 프런트는 토큰을 붙여야 해서 `<img src>`에 주소를 바로 넣을 수 없어요. `fetch`로 받은 다음 `URL.createObjectURL(blob)`로 보여 줘요.

| 오류 | 언제 |
| --- | --- |
| 404 | 사장이 아니거나 파일이 없음 |

---

### A · 파티 (11)

**공통 규칙**
- **현재 인원** = PARTY_MEMBER 가운데 `status = 'JOINED'`인 줄 수예요(방장 포함). 강퇴된(`KICKED`) 줄은 세지 않아요.
- **삭제된 파티(`DELETED`)** 는 모든 파티 API에서 없는 파티로 취급해요(404). 실제로 지우지 않고 상태만 바꿔요(결정 P1).
- 참여, 나가기, 강퇴, 마감, 삭제처럼 인원이나 상태를 바꾸는 API는 PARTY 행을 **잠그고** 처리해요.
  - 잠그는 방법: `SELECT … FOR UPDATE`, JPA에서는 `@Lock(PESSIMISTIC_WRITE)`
  - 동시에 마지막 자리를 두 명이 차지하지 못하게 하려는 거예요.
- 파티 만들기·참여·나가기·강퇴는 채팅 **안내 줄**(PARTY_MESSAGE `msg_type`)을 같은 트랜잭션에서 한 줄 넣어요(결정 P3).

#### A-12. 파티 목록 (모집 중만)

`GET /api/parties?genreIds=&keyword=&themeId=` · 로그인 · 200 · 화면 S04 `party-list.html`

| 쿼리 | 설명 |
| --- | --- |
| genreIds | 장르 번호 여러 개 `1,2`. **하나라도** 맞는 테마의 파티 |
| keyword | 테마 이름 일부. 띄어쓰기 무시 |
| themeId | 메인·테마 상세·매장 상세의 "파티 보기"로 들어올 때 |

- 항상 `status = RECRUITING`이고 `deadline_at > SYSDATE`인 파티만 보내요.
- **가까운 일정순**(`play_at` 오름차순)으로 정렬해요.

```json
[
  {
    "partyId": 1, "title": "인형의 집 같이 가실 분 (추리 좋아하는 분)",
    "intro": "추리 위주로 차분하게 푸는 팀 원해요. 공포는 제가 앞장설게요!",
    "themeId": 1, "themeTitle": "저주받은 인형의 집", "storeName": "미스터리룸 홍대점",
    "genres": ["공포", "추리"],
    "playAt": "2026-11-20T19:00:00", "deadlineAt": "2026-11-19T18:00:00",
    "currentPeople": 2, "maxPeople": 4, "leaderNickname": "추리덕후",
    "status": "RECRUITING", "joined": false, "kicked": false
  }
]
```

| 필드 | 뜻 | 프런트가 하는 일 |
| --- | --- | --- |
| `joined` | 내가 `JOINED`인 파티 | 참여 확인 팝업 없이 바로 파티 방(A-13)으로 보내요 |
| `kicked` | 내가 강퇴된 파티 | 배너를 흐리게 하고 "참여할 수 없는 파티예요"를 보여 줘요(결정 P2) |

- `leaderNickname`은 MEMBER와 JOIN해서 채워요.
- 장르 조건은 THEME_GENRE에 `EXISTS`를 걸어서 걸러요. 한 파티가 장르 여러 개에 걸려 중복으로 나오지 않게 하려는 거예요.

#### A-13. 파티 방 정보

`GET /api/parties/{partyId}` · 방장·참여자 · 200 · 화면 S06 `party-room.html`

```json
{
  "partyId": 1, "title": "인형의 집 같이 가실 분 (추리 좋아하는 분)",
  "intro": "추리 위주로 차분하게 푸는 팀 원해요. 공포는 제가 앞장설게요!",
  "status": "RECRUITING",
  "theme": { "themeId": 1, "title": "저주받은 인형의 집", "storeName": "미스터리룸 홍대점", "playMinutes": 70 },
  "playAt": "2026-11-20T19:00:00", "deadlineAt": "2026-11-19T18:00:00",
  "maxPeople": 4, "currentPeople": 2,
  "members": [
    { "memberId": 4, "nickname": "탈출왕", "leader": true,  "joinedAt": "2026-11-17T09:00:00" },
    { "memberId": 5, "nickname": "힌트없이", "leader": false, "joinedAt": "2026-11-17T09:05:00" }
  ],
  "myRole": "LEADER"
}
```

- `members`에는 `JOINED`인 사람만 들어가요. 닉네임은 JOIN해서 채워요.
- `myRole`은 `LEADER` 또는 `MEMBER`예요. 프런트는 이 값으로 버튼을 바꿔요.
  - 방장: 강퇴, 모집 마감, 파티 삭제
  - 참여자: 나가기
- 참여하지 않았거나 강퇴된 사람이 주소로 바로 들어오면 403이에요. 프런트는 파티 목록으로 돌려보내요.

| 오류 | 언제 |
| --- | --- |
| 403 | `파티에 참여한 사람만 볼 수 있습니다.` |
| 404 | 없는 파티, 또는 삭제된(`DELETED`) 파티 |

#### A-14. 파티 만들기

`POST /api/parties` · USER · 201 · 화면 S05 `party-form.html`

| 본문 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| themeId | number | ✔ | OPEN 테마 (매장 APPROVED) |
| title | string | ✔ | 1~100자 |
| intro | string | ✔ | **방장 한마디** 1~100자. 목록 배너에 보임 |
| playAt | datetime | ✔ | 지금 이후. 그날 유형(주중/주말) 시간표에 있는 시각 |
| deadlineAt | datetime | ✔ | 지금 이후이고 playAt보다 늦지 않음 |
| maxPeople | number | ✔ | 2 이상, 테마 `min_people` ~ `max_people` 범위 |

```json
// 요청
{ "themeId": 1, "title": "인형의 집 같이 가실 분", "intro": "추리 위주로 차분하게 푸는 팀 원해요.",
  "playAt": "2026-11-20T19:00:00", "deadlineAt": "2026-11-19T18:00:00", "maxPeople": 4 }
// 응답 201
{ "partyId": 7 }
```

**처리 순서와 규칙**
1. 값을 검사해요.
   - **시간표 검사**: playAt 날짜가 토·일·공휴일(HOLIDAY)이면 `WEEKEND`, 나머지는 `WEEKDAY`로 봐요. 그다음 TIME_SLOT에 (theme_id, day_type, `HH:mm`)이 있는지 확인해요.
2. **한 트랜잭션**에서 PARTY, PARTY_MEMBER(방장, `JOINED`), PARTY_MESSAGE 안내 줄(`JOIN`)을 넣어요.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `오늘 이후 날짜만 고를 수 있습니다.` / `그 시간에는 이 테마 시간표가 없습니다.` / `모집 기한은 플레이 시간 전이어야 합니다.` / `모집 인원은 2~4명 사이로 정해 주세요.` |
| 404 | 없는 테마, 또는 공개되지 않은 테마 |

#### A-15. 파티 삭제

`DELETE /api/parties/{partyId}` · 방장 · 204 · 화면 S06 방장 버튼

- **실제로 지우지 않아요.** `status = 'DELETED'`로만 바꿔요(결정 P1). 참여자와 채팅 기록은 DB에 그대로 남아요.
- 삭제된 파티는 파티 목록(A-12), 파티 방(A-13), 채팅(A-20·A-21), 내 채팅 목록(A-22) 어디에도 보이지 않아요.
- 상태가 `RECRUITING`, `FULL`, `CLOSED` 중 무엇이든 지울 수 있어요.
- HTTP 메서드는 화면에서 하는 일에 맞춰 `DELETE`를 그대로 써요.

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

**처리 순서와 규칙** (PARTY 행을 잠근 채로)
1. 파티 상태를 확인해요: `status = RECRUITING`이고 `deadline_at > SYSDATE`여야 해요.
2. 내 PARTY_MEMBER 줄을 확인해요.
   - `JOINED`면 409 (이미 참여)
   - **`KICKED`면 409 (강퇴된 사람은 다시 못 들어옴, 결정 P2)**
   - 줄이 없으면 계속해요. 예전에 스스로 나간 사람은 줄이 지워져 있어서 다시 참여할 수 있어요.
3. 현재 인원(`JOINED` 수)이 정원보다 적은지 확인해요.
4. PARTY_MEMBER(`JOINED`)와 안내 줄(`JOIN`)을 넣어요.
5. 넣은 뒤 인원이 정원과 같으면 `status = FULL`로 바꿔요.

- 프런트는 성공하면 파티 방(`party-room.html?id=`)으로 가요. 409를 받으면 메시지를 보여 주고 목록에 남아요.

| 오류 | 메시지 예 |
| --- | --- |
| 404 | 없는 파티, 또는 삭제된 파티 |
| 409 | `이미 참여한 파티입니다.` / `강퇴된 파티에는 다시 참여할 수 없습니다.` / `정원이 다 찼습니다.` / `모집이 끝난 파티입니다.` |

#### A-17. 나가기 (참여 취소)

`DELETE /api/parties/{partyId}/join` · 참여자(방장 제외) · 204 · 화면 S06 참여자 버튼

**처리 순서와 규칙** (PARTY 행을 잠근 채로)
1. 내 PARTY_MEMBER 줄을 **지워요.** 그래서 나중에 다시 참여할 수 있어요.
2. 안내 줄(`LEAVE`)을 넣어요.
3. 파티가 `FULL`이었고 `deadline_at > SYSDATE`면 `RECRUITING`으로 되돌려요.

- 나가면 파티와 채팅방에서 동시에 빠져요.

| 오류 | 메시지 |
| --- | --- |
| 400 | `방장은 나갈 수 없습니다. 파티를 삭제해 주세요.` |
| 404 | 참여하지 않은 파티, 또는 삭제된 파티 |

#### A-18. 강퇴

`DELETE /api/parties/{partyId}/members/{memberId}` · 방장 · 204 · 화면 S06 참여자 옆 "강퇴"

**처리 순서와 규칙** (PARTY 행을 잠근 채로)
1. 대상의 PARTY_MEMBER 줄을 **지우지 않고** `status = 'KICKED'`로 바꿔요. 이 줄이 남아 있어서 다시 참여할 수 없어요(결정 P2).
2. 안내 줄(`KICK`)을 넣어요.
3. 파티가 `FULL`이었고 기한 전이면 `RECRUITING`으로 되돌려요.

- 강퇴된 사람은 그 순간부터 채팅(A-20·A-21)과 방 정보(A-13)에서 403을 받아요. 내 채팅 목록(A-22)에서도 빠져요.

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

- RECRUITING이나 FULL 파티를 CLOSED로 바꿔요.
- 마감한 파티는 목록에서 사라져요. 내 채팅에서는 그대로 보여요.

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

- `messageId` 오름차순으로 한 번에 최대 100개까지 보내요.
- `nickname`은 MEMBER와 JOIN해서 채워요. 그래서 닉네임을 바꾼 사람의 예전 메시지도 새 닉네임으로 보여요.
- 프런트는 `msgType`에 따라 다르게 그려요. 글자는 모두 `textContent`로 넣어요.

| msgType | 화면 |
| --- | --- |
| `CHAT` | 말풍선. `mine`이면 오른쪽 |
| `JOIN` / `LEAVE` / `KICK` | 가운데 안내 줄: "○○님이 들어왔어요 / 나갔어요 / 강퇴됐어요" |

- 마감된(`CLOSED`) 파티도 채팅은 계속 돼요. 일정 조율에 써야 하니까요.
- `JOINED`가 아니면 403이에요(강퇴 직후 포함). 프런트는 403을 받으면 3초 반복을 멈추고 목록으로 보내요.

#### A-21. 채팅 보내기

`POST /api/parties/{partyId}/messages` · 방장·참여자 · 201

```json
// 요청
{ "content": "무서운 건 제가 앞장설게요" }
// 응답 201 (A-20 한 줄과 같은 모양)
{ "messageId": 33, "memberId": 4, "nickname": "탈출왕", "msgType": "CHAT", "content": "무서운 건 제가 앞장설게요", "createdAt": "2026-11-17T09:06:00", "mine": true }
```

- 앞뒤 공백을 지운 뒤 1~500자여야 해요. 아니면 400이에요.

#### A-22. 내 채팅 (내 파티) 목록

`GET /api/my/parties` · USER · 200 · 화면 S20 `chats.html` (마이페이지 "내 채팅" 탭)

```json
[
  {
    "partyId": 1, "title": "인형의 집 같이 가실 분", "themeId": 1, "themeTitle": "저주받은 인형의 집",
    "status": "RECRUITING", "myRole": "LEADER", "currentPeople": 2, "maxPeople": 4,
    "playAt": "2026-11-20T19:00:00", "ended": false,
    "lastMessage": { "nickname": "탈출왕", "msgType": "CHAT", "content": "무서운 건 제가 앞장설게요", "createdAt": "2026-11-17T09:06:00" }
  }
]
```

- 내가 **`JOINED`** 인 파티를 보내요. `RECRUITING`, `FULL`, `CLOSED` 모두 포함이에요.
  - 삭제된 파티(`DELETED`)와 강퇴된 파티는 빼요.
- 정렬은 마지막 메시지 시각의 최신순이에요.
- `ended`는 `play_at < SYSDATE`인지 알려 줘요. 끝난 파티에는 "후기 쓰기" 버튼을 보여 주고, 누르면 `themeId`로 후기 팝업(D-1)을 열어요.

### B · 테마·매장 탐색 (11)

**공통 규칙**
- 손님에게 보이는 테마는 `THEME.status = OPEN`이면서 `STORE.status = APPROVED`인 것만이에요.
- 평균 별점은 `rating_sum / review_count`로 계산해요. 소수 첫째 자리까지 쓰고, 후기가 없으면 `null`이에요.

#### B-1. 테마 목록·검색·필터

`GET /api/themes?keyword=&area=&date=&people=&genreId=&sort=` · 공개 · 200

화면은 S08 메인(`index.html`)의 가로 줄들과, 사이드 메뉴 통합 검색의 결과 격자예요.

| 쿼리 | 설명 |
| --- | --- |
| keyword | **테마 이름 또는 매장 이름** 일부. 띄어쓰기 무시 (`REPLACE(col, ' ', '') LIKE '%' \|\| #{kw} \|\| '%'`) |
| area | 매장 지역 (B-8 값) |
| date | 그날 유형 시간표가 하나라도 있는 테마만. 날 유형: **토·일·공휴일(HOLIDAY) → `WEEKEND`**, 나머지 `WEEKDAY`. 오늘 이전이면 400 |
| people | `min_people ≤ people ≤ max_people` |
| genreId | 장르 하나 |
| sort | `rate`(기본, 평균 별점 높은 순, 후기 없는 테마는 뒤로) / `new`(등록 최신순) |

```json
[
  {
    "themeId": 1, "title": "저주받은 인형의 집", "storeId": 1, "storeName": "미스터리룸 홍대점", "area": "홍대",
    "genres": ["공포", "추리"], "difficulty": 4, "playMinutes": 70, "minPeople": 2, "maxPeople": 4, "price": 25000,
    "posterUrl": "/uploads/posters/3f2a.jpg", "avgRating": 4.0, "reviewCount": 1,
    "recruitingPartyCount": 2, "createdAt": "2026-11-01T10:00:00", "wished": false
  }
]
```

- `recruitingPartyCount`는 모집 중(`RECRUITING`)이면서 기한이 남은 파티 수예요. 메인 "지금 파티 모집 중" 줄과 배너 버튼에 써요.
- `wished`는 로그인한 손님일 때만 의미가 있고, 비로그인이면 `false`예요.
- 메인의 가로 줄은 화면이 이 응답을 **한 번 받아서 나눠 그려요**: 인기 TOP 5, 파티 모집 중, 공포, 추리, 새로 문을 연 테마(최근 14일), 감성·어드벤처·SF.
- **비회원 메인의 추천 배너**도 이 API(`sort=rate`) 상위 5개로 그려요(결정 C1).

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

- 공개되지 않은 테마(PENDING, REJECTED, CLOSED)이거나 매장이 승인 전이면 **404**예요. 사장이 미리 보려면 C-6을 써요.
- 후기 목록은 D-4로 따로 받아요.

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

- 날 유형을 정하는 규칙: **토·일, 또는 HOLIDAY에 있는 날짜면 `WEEKEND`**, 나머지는 `WEEKDAY`예요(결정 T1).
  - 공휴일이면 `holidayName`에 이름(예: `"추석"`)을 넣어요. 화면은 "추석이라 주말 시간표"처럼 안내할 수 있어요.
- `endTime`은 `startTime + play_minutes`로 계산해요.
- 날짜가 오늘이면 **이미 지난 시각은 빼요.** 오늘 이전 날짜면 400이에요.
- 회차별 마감 상태는 없어요(결정 T2). 실제 예약은 테마의 `bookingUrl`에서 해요.

#### B-4 / B-5. 찜 / 찜 취소

| 번호 | 주소 | 성공 | 오류 |
| --- | --- | --- | --- |
| B-4 | `POST /api/themes/{themeId}/wish` | 201 `{ "wishId": 9 }` | 404 공개 안 된 테마 / 409 `이미 찜한 테마입니다.` |
| B-5 | `DELETE /api/themes/{themeId}/wish` | 204 | 404 찜하지 않은 테마 |

- 찜하기는 목록에 **넣기만** 해요. 화면은 그대로 두고 하트만 바꿔요(회의 v2-7).

#### B-6. 찜 목록

`GET /api/my/wishes` · USER · 200 · 화면 S10 `wishes.html` (마이페이지 "찜 목록" 탭)

```json
[
  { "wishId": 9, "themeId": 2, "title": "할머니의 다락방", "storeName": "미스터리룸 홍대점",
    "status": "OPEN", "posterUrl": "/uploads/posters/a1.jpg", "createdAt": "2026-11-16T12:00:00" }
]
```

- 최근에 찜한 순서로 보내요.
- 운영이 끝난(CLOSED) 테마도 목록에 **남아요.** `status`를 같이 보내요.

#### B-7. 장르 목록 · B-8. 지역 목록

| 번호 | 주소 | 응답 |
| --- | --- | --- |
| B-7 | `GET /api/genres` | `[{ "genreId": 1, "name": "공포" }, …]` (7개) |
| B-8 | `GET /api/areas` | `["강남", "건대", "신촌", "홍대"]` (APPROVED 매장의 지역을 중복 없이, 가나다순) |

B-7은 여러 곳에서 써요: 가입(손님), 내 정보 선호 장르, 테마 등록, 통합 검색 장르 칸, 파티 장르 필터.

#### B-9. 매장 목록

`GET /api/stores?area=&keyword=` · 공개 · 200 · 화면 S27 `stores.html`

```json
[
  {
    "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대",
    "address": "서울 마포구 …", "hours": "10:00 ~ 23:00 (연중무휴)", "photoUrl": "/uploads/stores/7b1e.jpg",
    "genres": ["공포", "추리", "감성"], "themeCount": 3, "avgRating": 4.3, "recruitingPartyCount": 3
  }
]
```

- **APPROVED 매장만** 보내요.
- `genres`, `themeCount`, `avgRating`, `recruitingPartyCount`는 그 매장의 OPEN 테마로 계산해요. `avgRating`은 테마 평균 별점들의 평균이에요.
- `keyword`는 매장 이름 일부로 찾고, 띄어쓰기는 무시해요.
- `photoUrl`은 매장 사진이에요. 없으면 `null`이에요(결정 S5).
- 브랜드 정보는 없어요(결정 B1).

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

- 승인되지 않은 매장(`PENDING`, `REJECTED`)은 404예요.
  - 승인된 매장도 사장이 수정하면 다시 `PENDING`이 돼요(결정 S1). 그동안은 404예요.
- 위쪽 **"매장 웹사이트 ↗" 버튼**은 `websiteUrl`로 새 창을 열어요(결정 B2).
- 테마별 예약은 테마 상세의 "예약하러 가기"(`bookingUrl`)로 해요.
- `themes`에는 OPEN 테마만 들어가요.
- 위쪽 큰 배경은 `photoUrl`(매장 사진)이에요. 없으면 평점이 가장 높은 테마의 `posterUrl`을 써요(화면에서 고름).

#### B-11. 지도용 매장 (선택 기능)

`GET /api/stores/map` · 공개 · 200 · 화면 S11 `map.html`

```json
[ { "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대", "lat": 37.556, "lng": 126.923, "themeCount": 3 } ]
```

- APPROVED 매장 가운데 `lat`과 `lng`이 모두 있는 매장만 보내요.

---

### C · 사장 (11)

**공통 규칙**
- 권한 표기 OWNER\*는 사장과 관리자 둘 다 부를 수 있다는 뜻이에요([1-4](#1-4-권한-표기)).
- 사장이 부르면 매 요청마다 **내 매장·내 테마인지** 확인해요. 남의 매장이면 403이에요.
  - 테스트 방법: owner2 계정으로 owner1 매장을 수정해 보면 돼요.

#### C-1. 내 매장 목록

`GET /api/owner/stores` · OWNER\* · 200 · 화면 S12 `owner.html`, 테마 등록 화면의 매장 선택

```json
[
  { "storeId": 1, "name": "미스터리룸 홍대점", "area": "홍대", "address": "서울 마포구 …",
    "phone": "02-000-0001", "websiteUrl": "https://example.com/mystery-hongdae",
    "hours": "10:00 ~ 23:00", "intro": "…", "photoUrl": "/uploads/stores/7b1e.jpg", "bizPlaceNo": "123-45-67890",
    "status": "APPROVED", "rejectReason": null, "themeCount": 3, "createdAt": "2026-11-10T10:00:00" },
  { "storeId": 10, "name": "미스터리룸 신촌점", "status": "REJECTED",
    "rejectReason": "사업장등록증의 상호와 매장 이름이 다릅니다. 다시 확인해 주세요.", "…": "…" }
]
```

- 사장이 부르면 `owner_id = 나`인 매장을, 관리자가 부르면 `owner_id IS NULL`인 매장(직접 등록한 매장)을 보내요.
- `rejectReason`은 반려된 매장일 때만 값이 있어요. 사장 홈에서 매장 옆에 보여 줘요(결정 S4).
- 매장 수정 화면의 처음 값도 이 응답으로 채워요.
- 테마 등록 화면의 매장 선택칸에는 **APPROVED 매장만** 보여 줘요(화면에서 거름).

#### C-2. 사업장 등록번호 중복 확인

`GET /api/owner/stores/check-biz-place-no?bizPlaceNo=` · OWNER\* · 200 → `{ "available": true }`

#### C-3. 매장 등록 📎

`POST /api/owner/stores` · OWNER\* · 201 · 화면 S21 `store-form.html`

| 폼 칸 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| name | text | ✔ | 1~50자 |
| area | text | ✔ | 1~10자 |
| address | text | ✔ | 1~100자 |
| phone | text | ✔ | 숫자와 `-`, 9~13자 |
| websiteUrl | text | ✔ | **매장 웹사이트**. `http://`나 `https://`로 시작, 500자 이내 (결정 B2) |
| hours | text | ✔ | **영업시간** 50자 이내 (결정 S2) |
| intro | text | ✔ | **매장 소개** 200자 이내 (결정 S2) |
| lat, lng | number | | 둘 다 있거나 둘 다 없음 |
| bizPlaceNo | text | ✔ | `^\d{3}-\d{2}-\d{5}$` |
| bizPlaceFile | file | 사장 ✔ | 사업장등록증 이미지. 관리자가 등록할 때는 생략할 수 있어요 |
| storePhoto | file | | **매장 사진** (공개). `/uploads/stores/`에 저장하고 STORE.`photo_url`에 경로를 넣어요 (결정 S5) |

```json
// 응답 201
{ "storeId": 9, "status": "PENDING" }
```

| 누가 등록하나 | status | owner_id |
| --- | --- | --- |
| 사장 | `PENDING` | 나 |
| 관리자 | `APPROVED` (바로 공개, 결정 S3) | NULL |

- 브랜드 칸은 없어요(결정 B1).

| 오류 | 언제 |
| --- | --- |
| 400 | 형식 위반, 파일 규칙 위반, 웹사이트 주소가 `http(s)://`로 시작하지 않음 |
| 409 | `이미 등록된 사업장 등록번호입니다.` |

#### C-4. 매장 수정 📎

`PUT /api/owner/stores/{storeId}` · OWNER\*(내 매장) · 200

- 칸은 C-3과 같아요. `bizPlaceFile`이나 `storePhoto`를 비우면 기존 파일을 그대로 써요.
- **사장이 수정하면 어떤 칸을 고쳤든 `status = PENDING`** 이 돼요(결정 S1). 이미 `APPROVED`였어도 마찬가지예요.
  - 이때 `reject_reason`은 비워요.
  - ⚠️ 매장이 다시 승인될 때까지 **그 매장의 테마도 손님 화면에서 모두 숨겨져요.** 손님 화면은 매장이 APPROVED인 테마만 보여 주기 때문이에요. 화면은 저장 전에 "수정하면 다시 승인을 받을 때까지 매장과 테마가 손님에게 보이지 않아요"라고 확인을 받아요.
- 관리자가 수정하면 `APPROVED` 그대로예요(결정 S3).
- 응답은 `{ "storeId": 9, "status": "PENDING" }`이에요.

| 오류 | 언제 |
| --- | --- |
| 403 | 내 매장이 아님 |
| 404 | 없는 매장 |
| 409 | 번호 중복 |

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

- 모든 상태의 테마를 보내요: `PENDING`, `OPEN`, `REJECTED`, `CLOSED`.
- `REJECTED` 테마는 `rejectReason`을 사장 홈 표에 보여 줘요(결정 S4).

#### C-6. 테마 수정용 상세

`GET /api/owner/themes/{themeId}` · OWNER\*(내 테마) · 200 · 화면 S13 수정 모드

- 응답은 B-2와 같은 모양에 `genreIds`, `status`, `source`, `createdAt`, `updatedAt`을 더한 거예요.
- 상태와 상관없이 볼 수 있어요. 승인 전이어도 볼 수 있어요.

#### C-7. 테마 등록 📎

`POST /api/owner/themes` · OWNER\*(내 매장) · 201 · 화면 S13 `owner-theme.html`

| 폼 칸 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| storeId | number | ✔ | 내 매장이면서 **APPROVED** |
| title | text | ✔ | 1~50자 |
| description | text | | 1300자 이내 |
| difficulty | number | ✔ | 1~5 |
| playMinutes | number | ✔ | 1~300 (제한 시간) |
| minPeople, maxPeople | number | ✔ | 1 ≤ min ≤ max ≤ 20 |
| price | number | ✔ | 0 이상, 1인 고정 가격 |
| bookingUrl | text | ✔ | `http://` 또는 `https://`로 시작, 500자 이내 |
| genreIds | number[] | ✔ | 1개 이상. 폼에서는 `genreIds=1&genreIds=2`처럼 같은 이름 여러 번 |
| poster | file | | 테마 사진 (공개) |

```json
// 응답 201
{ "themeId": 21, "status": "PENDING" }
```

- **한 트랜잭션**에서 THEME과 THEME_GENRE를 넣어요.
- 사장이 등록하면 `PENDING`, `source = OWNER`예요.
- 관리자가 등록하면 `OPEN`, `source = ADMIN`이에요.
- 화면에는 고른 매장의 사업장 등록번호와 전화번호가 함께 보여요(C-1 값, 회의 v2-4).

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `예약 링크는 http:// 또는 https:// 로 시작해야 합니다.` / `최소 인원이 최대 인원보다 클 수 없습니다.` |
| 403 | 내 매장이 아님 |
| 409 | `승인된 매장에만 테마를 등록할 수 있습니다.` |

#### C-8. 테마 수정 📎

`PUT /api/owner/themes/{themeId}` · OWNER\*(내 테마) · 200

- 칸은 C-7과 같아요. 다만 `storeId`는 바꿀 수 없어요. `poster`를 비우면 기존 사진을 그대로 써요.
- 사장이 수정하면 **다시 `PENDING`** 이 되고 `reject_reason`을 비워요. 관리자가 다시 승인해야 손님에게 보여요.
- 관리자가 수정하면 `OPEN` 그대로예요(결정 S3).
- THEME_GENRE는 지우고 다시 넣어요. 같은 트랜잭션이에요.
- `updated_at`은 트리거가 바꿔요.
- 응답은 `{ "themeId": 21, "status": "PENDING" }`이에요.

#### C-9. 운영 종료·재개

`PUT /api/owner/themes/{themeId}/status` · OWNER\*(내 테마) · 200

```json
// 요청
{ "status": "CLOSED" }
// 응답 200
{ "themeId": 1, "status": "CLOSED" }
```

- `OPEN`에서 `CLOSED`로, `CLOSED`에서 `OPEN`으로만 바꿀 수 있어요. 그 밖의 상태에서는 409예요(승인 전·반려 테마는 바꿀 수 없음).
- 종료한 테마도 찜 목록과 내 기록에는 남아요.

#### C-10. 주중/주말 시간표 보기

`GET /api/owner/themes/{themeId}/slots` · OWNER\*(내 테마) · 200 · 화면 S14 `owner-slots.html`

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
1. 값을 검사해요.
   - 형식은 `HH:mm`이어야 해요.
   - 한 유형 안에 같은 시각이 두 번 있으면 안 돼요.
   - 한 유형 안에서 정렬했을 때 **앞뒤 회차 간격이 `play_minutes`보다 짧으면 안 돼요.**
   - 한 유형에 최대 20개까지예요.
2. **한 트랜잭션**에서 그 테마의 TIME_SLOT을 지우고 다시 넣어요.

- 화면의 "주말에도 똑같이 →" 복사 버튼은 화면에서만 처리해요. 저장할 때 이 API 하나로 보내요.
- 이미 만들어진 파티는 날짜와 시각(`play_at`)을 따로 저장하고 있어요. 그래서 시간표가 바뀌어도 파티는 그대로예요.
  - PM 회의의 "파티원 있으면 시간표 잠금"은 시간표가 반복 구조로 바뀌어서 적용하지 않았어요.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `시간은 19:00처럼 입력해 주세요.` / `주중 13:00이 두 번 들어 있습니다.` / `주중 13:00과 13:30 회차가 겹칩니다 (플레이 70분).` |


### C · 관리자 (8)

#### C-12. 관리자 홈 숫자 요약

`GET /api/admin/summary` · ADMIN · 200 · 화면 S25 `admin.html`

```json
{
  "pendingStores": 2, "pendingThemes": 1,
  "oldestPendingStoreAt": "2026-11-16T10:00:00", "oldestPendingThemeAt": "2026-11-17T09:00:00",
  "approvedStores": 5, "openThemes": 18, "waitReports": 3,
  "memberCountByRole": { "USER": 5, "OWNER": 3, "ADMIN": 1 }
}
```

- 서버가 하나라서 회원 수까지 한 번에 내려 줘요.
- "지금 처리할 것" 목록은 C-13과 C-17 결과를 신청일이 오래된 순서로 합쳐서 보여 줘요.
- `waitReports`는 신고 처리 타일(이번 범위 제외)에 "신고 접수 N건"으로만 보여 줘요.

#### C-13. 매장 승인 목록

`GET /api/admin/stores?status=PENDING` · ADMIN · 200 · 화면 S22 `admin-stores.html`

| 쿼리 | 설명 |
| --- | --- |
| status | 기본값 `PENDING`. `APPROVED`, `REJECTED`도 받아요 |

```json
[
  { "storeId": 9, "name": "미스터리룸 합정점", "bizPlaceNo": "222-33-44444",
    "owner": { "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대" },
    "createdAt": "2026-11-17T10:00:00" }
]
```

- 오래된 순서로 보내요. "신청한 사장" 칸은 MEMBER와 JOIN해서 채워요. 관리자가 직접 등록한 매장은 `owner: null`이에요.
- 목록에서는 승인할 수 없어요. 하나를 골라 상세(C-14)로 들어가요.

#### C-14. 매장 승인 상세

`GET /api/admin/stores/{storeId}` · ADMIN · 200 · 화면 S23 `admin-store-detail.html`

```json
{
  "storeId": 9, "name": "미스터리룸 합정점", "area": "합정",
  "address": "서울 마포구 …", "phone": "02-000-0009", "websiteUrl": "https://example.com/mystery-hapjeong",
  "hours": "11:00 ~ 23:00", "intro": "합정역 7번 출구 2분.", "photoUrl": "/uploads/stores/9a2c.jpg",
  "bizPlaceNo": "222-33-44444", "hasBizPlaceFile": true,
  "owner": { "memberId": 1, "loginId": "owner1", "nickname": "미스터리룸홍대", "bizNo": "111-22-33333" },
  "status": "PENDING", "rejectReason": null, "createdAt": "2026-11-17T10:00:00"
}
```

화면은 서류 두 장을 나란히 보여 줘요.

| 서류 | 받는 곳 |
| --- | --- |
| 🏪 사업장등록증 | C-15 |
| 👤 사장 사업자등록증 | A-11 (`owner.memberId`) |

- 관리자는 두 번호와 상호·주소를 대조해요.
- 매장 사진(`photoUrl`)도 함께 보고, 손님에게 보여도 되는 사진인지 확인해요.

#### C-15. 사업장등록증 이미지

`GET /api/admin/stores/{storeId}/biz-place-file` · ADMIN · 200

- 이미지 자체를 보내요. A-11과 같은 방식이에요.
- 파일이 없으면 404예요(관리자 직접 등록 매장).

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

- **PENDING 매장만** 처리할 수 있어요. 아니면 409 `이미 처리된 매장입니다.`예요.
- **반려할 때는 `reason`이 꼭 있어야 해요**: 1~300자, 없으면 400. 사유는 STORE.`reject_reason`에 저장되고 사장 홈(C-1)에 보여요(결정 S4).
- 승인하면 `reject_reason`을 비워요. 그 순간 매장 목록(B-9)에 보이고, 사장이 테마를 등록할 수 있어요.

#### C-17. 테마 승인 목록

`GET /api/admin/themes?status=PENDING` · ADMIN · 200 · 화면 S15 `admin-themes.html`

```json
[
  { "themeId": 21, "title": "거울 속 방", "storeName": "미스터리룸 홍대점", "genres": ["공포"],
    "posterUrl": "/uploads/posters/9c.jpg", "createdAt": "2026-11-17T09:00:00", "updatedAt": "2026-11-17T09:00:00" }
]
```

- 매장 승인과 **다른 탭**이에요. 목록 → 상세 → 승인/반려 순서로 처리해요(회의 v2-10).

#### C-18. 테마 승인 상세

`GET /api/admin/themes/{themeId}` · ADMIN · 200 · 화면 S24 `admin-theme-detail.html`

- 응답은 C-6 모양에 `store: { storeId, name, bizPlaceNo, phone, websiteUrl, status }`를 더한 거예요.
- 상세에서 테마 사진을 함께 봐요(회의 v2-10).
- 승인하기 전에 주소, 전화번호, 예약 링크가 맞는지 관리자가 직접 확인해요.

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

- **PENDING 테마만** 처리할 수 있어요. 아니면 409예요.
- 반려할 때는 `reason`이 필수예요(1~300자). 사유는 THEME.`reject_reason`에 저장되고 사장 홈(C-5)에 보여요(결정 S4).
- 매장이 APPROVED가 아니면 승인할 수 없어요. 409 `매장이 승인되지 않았습니다.`
- 승인하는 순간 손님 메인(B-1)에 나타나요.

### D · 기록·추천 (11)

#### D-1. 후기 쓰기

`POST /api/reviews` · USER · 201

화면은 S17 후기 팝업이에요. 테마 상세, 마이페이지, 내 채팅(끝난 파티) **어디서든 같은 팝업**이 떠요.

| 본문 | 타입 | 필수 | 규칙 |
| --- | --- | :-: | --- |
| themeId | number | ✔ | OPEN 또는 CLOSED 테마 |
| rating | number | ✔ | 1~5 |
| escaped | boolean | ✔ | 탈출 성공. DB에는 `Y`/`N`으로 저장 |
| hintCount | number | ✔ | 0~99 |
| playerCount | number | ✔ | 1~20. 몇 명이서 |
| remainSeconds | number | ✔ | 성공: 0 ~ `play_minutes × 60`. **실패(`escaped: false`)면 반드시 0** (결정 R2) |
| playedDate | date | | 오늘이거나 그 이전. **비우면 작성일** (결정 R1) |
| content | string | | 200자 이내 |

```json
// 요청
{ "themeId": 9, "rating": 4, "escaped": true, "hintCount": 1, "playerCount": 3,
  "remainSeconds": 227, "playedDate": "2026-11-09", "content": "마지막 반전 대박" }
// 응답 201
{ "reviewId": 15 }
```

- 화면은 분과 초 두 칸으로 받아서 `분 × 60 + 초`로 보내요. 실패를 고르면 두 칸을 끄고 0을 보내요.
- 실패인데 0이 아니면 400이에요. DB에도 같은 CHECK(`review_fail_ck`)가 걸려 있어요.
- 닉네임은 저장하지 않아요. 보여 줄 때 JOIN해요.
- THEME 별점 집계는 **트리거**가 해요.

| 오류 | 메시지 예 |
| --- | --- |
| 400 | `남은 시간은 제한 시간(70분)보다 길 수 없습니다.` / `탈출에 실패했다면 남은 시간은 0이어야 합니다.` / `별점은 1~5점입니다.` |
| 404 | 없는 테마 |
| 409 | `이미 이 테마에 후기를 남겼습니다. 내 기록에서 수정해 주세요.` |

#### D-2. 후기 수정

`PUT /api/reviews/{reviewId}` · 작성자 · 200

- 본문은 D-1에서 `themeId`를 뺀 것이에요. **테마는 바꿀 수 없어요.** 트리거가 이 전제로 짜여 있어요.
- 응답은 수정된 후기예요. D-5의 한 줄과 같은 모양이에요.
- 이미 쓴 후기를 고치는 기능은 그대로 둬요(회의 v2-6).

| 오류 | 언제 |
| --- | --- |
| 403 | 내 후기가 아님 |
| 404 | 없는 후기 |

#### D-3. 후기 삭제

`DELETE /api/reviews/{reviewId}` · 작성자 · 204

- **한 트랜잭션**에서 그 후기의 REPORT를 먼저 지우고, 그다음 REVIEW를 지워요. FK 때문이에요.

#### D-4. 테마 후기 + 평균

`GET /api/themes/{themeId}/reviews` · 공개 · 200 · 화면 S09 후기 칸

```json
{
  "avgRating": 4.0, "reviewCount": 1, "playMinutes": 70,
  "reviews": [
    { "reviewId": 3, "nickname": "힌트없이", "rating": 4, "escaped": true, "hintCount": 0,
      "playerCount": 3, "remainSeconds": 754, "playedDate": "2026-10-19",
      "content": "인형 연출이 소름 돋아요.", "createdAt": "2026-10-19T22:00:00",
      "mine": false, "reportedByMe": false }
  ]
}
```

- **VISIBLE 후기만** 최신순으로 보내요.
- 화면은 `remainSeconds`를 `12:34 남기고 (70:00 중)`처럼 바꿔 보여 줘요.
- `mine`이 true면 신고 버튼 대신 수정 버튼을 보여 줘요.
- `reportedByMe`가 true면 신고 버튼을 끄고 "신고함"으로 보여 줘요.

#### D-5. 내 기록

`GET /api/my/reviews` · USER · 200 · 화면 S18 `mypage.html` 내 기록 탭

```json
[
  { "reviewId": 15, "themeId": 9, "themeTitle": "사라진 기억", "storeName": "어둠상자 홍대점", "playMinutes": 70,
    "rating": 4, "escaped": true, "hintCount": 1, "playerCount": 3, "remainSeconds": 227,
    "playedDate": "2026-11-09", "content": null, "status": "VISIBLE" }
]
```

- 플레이한 날 최신순으로 보내요. 숨김(HIDDEN) 후기도 상태와 함께 보내요.
- 각 줄의 "수정" 버튼은 이 값으로 후기 팝업을 채워서 열어요.

#### D-6. 후기 쓸 수 있는 테마

`GET /api/my/review-candidates` · USER · 200 · 화면 S18 "+ 후기 쓰기" 팝업의 "플레이한 테마" 선택칸

```json
[
  { "themeId": 9, "title": "사라진 기억", "storeName": "어둠상자 홍대점", "playMinutes": 70,
    "partyId": 5, "playAt": "2026-11-09T19:00:00", "memberCount": 3 }
]
```

- 내가 참여한 파티 가운데 `play_at`이 지난 파티의 테마를 보내요. 그중 **아직 내 후기가 없는** 테마만이에요.
- 같은 테마는 한 번만, 가장 최근 파티 기준으로 보내요.
- 화면은 고른 테마의 `playMinutes`로 남은 시간 상한을 정하고, `memberCount`로 플레이 인원의 처음 값을 채워요.
- 파티 없이 간 테마의 후기는 테마 상세의 "후기 쓰기"로 써요. 이때는 테마가 정해진 채로 팝업이 열려요.
- 이 API는 v1의 "후기 요청 팝업(D-10)"을 대신해요. 자동 팝업은 없앴어요(회의 v2-6).

#### D-7. 내 선호 장르 · D-8. 선호 장르 저장

| 번호 | 주소 | 요청 | 응답 |
| --- | --- | --- | --- |
| D-7 | `GET /api/my/genres` | | `[{ "genreId": 1, "name": "공포" }, …]` |
| D-8 | `PUT /api/my/genres` | `{ "genreIds": [1, 2] }` | 200, 저장 뒤 목록 (D-7 모양) |

- 화면은 S26 `profile.html`의 선호 장르 칸이에요. v3에서 내 기록 탭에서 이 칸으로 옮겼어요.
- D-8은 **통째로 교체**해요. 한 트랜잭션에서 지우고 다시 넣어요. 빈 배열을 보내면 모두 지워요.
- 처음 장르는 손님 가입(A-1) 때 함께 저장돼요.

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
1. 공개된 테마(OPEN·APPROVED) 가운데 내 선호 장르가 하나라도 겹치는 테마를 골라요.
2. 내가 이미 후기를 쓴 테마는 빼요.
3. 정렬은 **겹치는 장르 수 → 평균 별점 → 최신순**이에요.
4. 최대 5개까지 보내요.

**`reason` 문장 만드는 법** (서버가 만들어요)

| 경우 | 문장 |
| --- | --- |
| 장르 2개 이상 겹침 | `{장르들} 둘 다 좋아하는 {닉네임} 님께` |
| 그 장르 안에서 평점 1위 | `{장르} 장르 평점 1위` |
| 최근 14일 등록 | `새로 문을 연 {장르} 테마` |
| 그 밖 | `{장르} 좋아하시면 꼭` |

- 선호 장르가 없거나 맞는 테마가 없으면 B-1 `sort=rate` 상위 5개를 보내요. 이때 `reason`은 `평점 높은 인기 테마`예요.
- **비회원**은 이 API를 부르지 않아요. 프런트가 B-1 `sort=rate` 상위 5개로 같은 배너를 그려요(ERD 결정 C1).
- 이 기능이 들어오면서 맞춤 추천이 "나중 기능"에서 **이번 범위**로 바뀌었어요. 마이페이지에서는 보여 주지 않아요.

#### D-10. 내 통계 (선택 기능)

`GET /api/my/stats` · USER · 200 · 화면 S18 위쪽 숫자 칸

```json
{ "playCount": 6, "escapeCount": 5, "escapeRate": 83, "topGenre": { "name": "추리", "count": 4 },
  "byGenre": [ { "name": "추리", "count": 4 }, { "name": "공포", "count": 3 } ] }
```

- 내 후기를 기준으로 계산해요. 숨김 후기도 포함해요. 내 기록이니까요.

#### D-11. 후기 신고

`POST /api/reviews/{reviewId}/report` · USER·OWNER · 201 · 화면 S09 후기의 🚩신고 → 신고 팝업 (페이지 이동 없음)

```json
// 요청
{ "reason": "다녀왔는데 힌트 수가 사실과 달라요." }
// 응답 201
{ "reportId": 4 }
```

- 사유는 **자유 글 한 칸**만 받아요: 1~300자. 유형은 받지도 저장하지도 않아요(결정 R3).
- 접수만 해요. 관리자 처리 화면은 이번 범위 밖이에요.

| 오류 | 언제 |
| --- | --- |
| 400 | 사유가 비었거나 300자 초과, 또는 내 후기를 신고 |
| 404 | 없는 후기, 또는 숨긴 후기 |
| 409 | `이미 신고한 후기입니다.` |

## 6. 자동 작업

| 이름 | 담당 | 주기 | 하는 일 |
| --- | --- | --- | --- |
| 모집 기한 마감 | A | 5분마다 (`@Scheduled(cron = "0 */5 * * * *")`) | `UPDATE party SET status='CLOSED' WHERE status='RECRUITING' AND deadline_at <= SYSDATE` |
| 별점 집계 | D (DB) | 후기를 넣거나 바꾸거나 지울 때마다 | 트리거 `trg_review_theme_stats` ([ERD 5-1](ERD.md#5-1-후기--테마-별점-집계-트리거)) |
| 테마 수정일 | C (DB) | 테마 내용이 바뀔 때 | 트리거 `trg_theme_updated_at` |

스케줄러가 돌기 직전 몇 분 사이를 위해, 목록(A-12)과 참여(A-16) API도 `deadline_at > SYSDATE`를 직접 검사해요.

---

## 7. 화면별 호출 API

| 화면 | 파일 (목업) | 담당 | 호출 API |
| --- | --- | --- | --- |
| S01 사이드 메뉴 · 통합 검색 | `js/common.js` | A | (토큰으로 그림), B-7, B-8 → 검색하면 메인 B-1 |
| S02 로그인 | `login.html` | A | A-6 |
| S03 가입 유형 선택 | `signup.html` | A | 없음 |
| S03-1 손님 가입 | `signup-user.html` | A | A-3, A-4, B-7, A-1 |
| S03-2 사장 가입 | `signup-owner.html` | A | A-3, A-4, A-5, A-2 |
| S04 파티 목록 | `party-list.html` | A | A-12, B-7, A-16 (참여 팝업) |
| S05 파티 만들기 | `party-form.html` | A | B-1 (테마 선택), B-3, A-14 |
| S06 파티 방 | `party-room.html` | A | A-13, A-20, A-21, A-17, A-18, A-19, A-15 |
| S07 회원 관리 | `admin-members.html` | A | A-10 |
| S08 메인 + 추천 배너 | `main.html` (실제 `index.html`) | B·D | B-1, D-9 (로그인 손님) |
| S09 테마 상세 | `theme.html` | B | B-2, B-3, D-4, B-4, B-5, D-1 (후기 팝업), D-11 (신고 팝업) |
| S10 찜 목록 탭 | `wishes.html` | B | B-6, B-5 |
| S11 매장 지도 (선택) | `map.html` | B | B-11 |
| S12 사장 홈 | `owner.html` | C | C-1, C-5 |
| S13 테마 등록·수정 | `owner-theme.html` | C | C-1, B-7, C-6, C-7, C-8, C-9 |
| S14 시간표 관리 | `owner-slots.html` | C | C-10, C-11 |
| S15 테마 승인 목록 | `admin-themes.html` | C | C-17 |
| S17 후기 팝업 (공용) | `js/review-modal.js` | D | D-6 (테마 고르기), D-1, D-2 |
| S18 마이페이지 내 기록 | `mypage.html` | D | D-10, D-5, D-3, 후기 팝업 |
| S20 내 채팅 탭 | `chats.html` | A | A-22, 후기 팝업 (끝난 파티) |
| S21 매장 등록 | `store-form.html` | C | C-2, C-3, C-4 |
| S22 매장 승인 목록 | `admin-stores.html` | C | C-13 |
| S23 매장 승인 상세 | `admin-store-detail.html` | C | C-14, C-15, A-11, C-16 |
| S24 테마 승인 상세 | `admin-theme-detail.html` | C | C-18, C-19 |
| S25 관리자 홈 | `admin.html` | C | C-12, A-10, C-13, C-17 |
| S26 내 정보 탭 | `profile.html` | A·D | A-7, A-4, A-8, A-9, B-7, D-7, D-8 |
| S27 매장 목록 | `stores.html` | B | B-8, B-9 |
| S28 매장 상세 | `store.html` | B | B-10 |
| 관리자 직접 등록 | `store-form.html?as=admin` 등 | C | C-1 ~ C-11 (관리자 권한) |

---

## 8. v1 → v3 번호 대응표

| v1 | v1 기능 | v3 | 바뀐 점 |
| --- | --- | --- | --- |
| A-1 | 회원가입 | **A-1 / A-2** | 손님·사장 가입 분리. ownerType 삭제, genreIds·사업자등록증 추가 |
| A-2 | 아이디 중복 | A-3 | 주소 `check-login-id` |
| — | | A-4, A-5 | 🆕 닉네임·사업자번호 중복 확인 |
| A-3 | 로그인 | A-6 | ownerType 삭제, 정지 403 삭제 |
| A-4 | 내 정보 | A-7 | |
| — | | A-8, A-9 | 🆕 닉네임·비밀번호 변경 |
| A-5 | 회원 목록 | A-10 | role 필터, countByRole |
| A-6 | 정지·해제 | 🗑️ | 회원 정지 기능 삭제 |
| — | | A-11 | 🆕 사업자등록증 보기 |
| A-7 | 파티 목록 | A-12 | 모집 중만, 장르 여러 개·검색, intro·deadlineAt·joined·kicked |
| A-8 | 파티 상세 | A-13 | 참여자만, myRole |
| A-9 | 파티 만들기 | A-14 | intro, deadlineAt, 시간표·공휴일 검사 |
| — | | A-15 | 🆕 파티 삭제 (status DELETED) |
| A-10 | 참여 | A-16 | 안내 줄, 기한·강퇴 검사 |
| A-11 | 나가기 | A-17 | |
| — | | A-18 | 🆕 강퇴 (status KICKED, 재참여 불가) |
| A-12 | 모집 마감 | A-19 | |
| A-13 | 새 채팅 | A-20 | msgType, mine |
| A-14 | 채팅 보내기 | A-21 | |
| — | | A-22 | 🆕 내 채팅 목록 |
| B-1 | 테마 목록 | B-1 | keyword에 매장 이름, 공휴일 규칙, recruitingPartyCount |
| B-2 | 상세 | B-2 | recruitingPartyCount |
| B-3 | 시간표 | B-3 | 주중/주말·공휴일 반복, endTime, status 삭제 |
| B-4~B-8 | 찜·취소·찜 목록·장르·지역 | B-4~B-8 | 찜 목록에 status |
| — | | B-9, B-10 | 🆕 매장 목록·상세 (websiteUrl) |
| B-9 | 지도 | B-11 | |
| C-1 | 관리 매장 | C-1 | 점주·본사 구분 삭제, status·rejectReason·websiteUrl |
| — | | C-2 | 🆕 사업장 번호 중복 확인 |
| C-2 | 매장 등록 | C-3 | multipart, 사업장등록증, 웹사이트·영업시간·소개, 브랜드 삭제 |
| C-3 | 매장 수정 | C-4 | 수정하면 무조건 재승인 |
| C-4 | 매장 테마 목록 | C-5 | rejectReason |
| — | | C-6 | 🆕 테마 수정용 상세 |
| C-5 | 테마 등록 | C-7 | multipart(사진), APPROVED 매장만 |
| C-6 | 테마 수정 | C-8 | |
| C-7 | 운영 종료·재개 | C-9 | |
| C-8 | 시간표 등록 (startAts[]) | C-10 / C-11 | 주중/주말 보기 + 통째 저장 |
| C-9 | 시간표 마감·열기 | 🗑️ | 회차별 마감 없음 |
| — | | C-12 | 🆕 관리자 홈 요약 |
| — | | C-13 ~ C-16 | 🆕 매장 승인 목록·상세·서류·처리(반려 사유) |
| C-10 | 테마 승인 대기 | C-17 | |
| — | | C-18 | 🆕 테마 승인 상세 |
| C-11 | 테마 승인·반려 | C-19 | 반려 사유 필수, 매장 승인 확인 |
| C-12, C-13 | 신고 목록·처리 | 🗑️ 나중 | 이번 범위 제외 |
| C-14 | 브랜드 목록 | 🗑️ | 브랜드 정보 받지 않음 |
| C-15 | 브랜드 등록 (본사) | 🗑️ | 본사 계정·브랜드 없음 |
| D-1 | 후기 작성 | D-1 | playerCount, remainSeconds(실패면 0), escaped boolean |
| D-2, D-3 | 수정·삭제 | D-2, D-3 | |
| D-4 | 테마 후기 | D-4 | mine, reportedByMe, 새 필드 |
| D-5 | 내 기록 | D-5 | |
| — | | D-6 | 🆕 후기 쓸 수 있는 테마 |
| D-6, D-7 | 선호 장르 | D-7, D-8 | 화면이 내 정보 탭으로 이동 |
| D-8 | 맞춤 추천 | D-9 | 메인 배너용, reason·description, 이번 범위로 |
| D-9 | 통계 | D-10 | |
| D-10 | 후기 요청 목록 | 🗑️ | 자동 팝업 삭제 → D-6이 대신 |
| D-11 | 후기 신고 | D-11 | 자유 글 사유만, 팝업 |

## 9. 이번 범위에서 뺀 것

| 기능 | 이유 | 나중에 넣을 때 |
| --- | --- | --- |
| 회원 정지·해제 | 회의 v2-9에서 삭제 | MEMBER.status 컬럼 + 관리자 API |
| 후기 신고 처리(숨김) | 회의 v2-6에서 나중으로. 목업 S16은 "범위 제외"로 남겨 둠 | v1 C-12·C-13 방식 그대로. 숨기면 트리거가 별점에서 자동으로 뺌 |
| 후기 요청 자동 팝업 | 회의 v2-6에서 삭제 | — |
| 회차별 마감 | 결정 T2 | 예외 테이블 필요 |
| 브랜드 | 결정 B1 (브랜드 정보 받지 않음) | — |
| 공휴일 관리 화면 | HOLIDAY는 더미 데이터로 해마다 넣음 | 관리자 API |
| 실시간 채팅 (WebSocket) | v1부터 선택 기능 | 지금은 3초마다 A-20 |
| 크롤링 시간표 더블체크 | v1 선택 기능, 목업 없음 | THEME.source = CRAWL 자리만 남겨 둠 |

11/18에 정한 결정은 [ERD 8. 확정된 결정](ERD.md#8-확정된-결정-1118)에 모아 두었어요. 목업 HTML(`visualization/`)도 이 결정에 맞춰 고쳐 두었어요.

