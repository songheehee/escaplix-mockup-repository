-- 방탈출 통합예약 (Escaplix) : 테이블 생성 v3 초안 (hr 계정에서 실행)
-- docs/ERD.md 와 짝. 아직 sql/01_create_tables.sql 을 대신하지 않음 (팀 확인 후 옮기기)
-- Oracle XE 11g 기준. 테이블 14개 + 트리거 2개
--  * 한글 1글자 = 3바이트 (AL32UTF8). VARCHAR2 크기는 바이트
--  * 회원번호 컬럼(ERD 점선)은 FK 없이 번호만 저장. 서버 1개로 확정되면 맨 아래 주석을 풀어 FK 를 건다
--  * 테마·매장은 DELETE 하지 말고 status 로 관리
--  * DEFAULT 가 있는 컬럼 : JPA 는 null 을 그대로 INSERT 하므로 @DynamicInsert 를 쓰거나 자바에서 값을 넣는다
--  * THEME.review_count / rating_sum / updated_at 은 트리거가 관리 → 엔티티에서 insertable=false, updatable=false

-- 1. 삭제 (자식 → 부모). 처음엔 "없음" 에러가 나도 무시
DROP TABLE party_message;
DROP TABLE party_member;
DROP TABLE party;
DROP TABLE report;
DROP TABLE review;
DROP TABLE wishlist;
DROP TABLE member_genre;
DROP TABLE time_slot;
DROP TABLE theme_genre;
DROP TABLE theme;
DROP TABLE store;
DROP TABLE brand;
DROP TABLE genre;
DROP TABLE member;

DROP SEQUENCE sq_member;
DROP SEQUENCE sq_genre;
DROP SEQUENCE sq_brand;
DROP SEQUENCE sq_store;
DROP SEQUENCE sq_theme;
DROP SEQUENCE sq_theme_genre;
DROP SEQUENCE sq_time_slot;
DROP SEQUENCE sq_wishlist;
DROP SEQUENCE sq_review;
DROP SEQUENCE sq_report;
DROP SEQUENCE sq_member_genre;
DROP SEQUENCE sq_party;
DROP SEQUENCE sq_party_member;
DROP SEQUENCE sq_party_message;


-- ================= 회원 서버 (member-service, 8081) =================

-- 2. 회원 (손님 / 사장 / 관리자). 사장은 사업자등록번호·사업자등록증 필수
CREATE TABLE member (
    member_id      NUMBER        NOT NULL,
    login_id       VARCHAR2(30)  NOT NULL,                   -- 영문·숫자
    password       VARCHAR2(60)  NOT NULL,                   -- BCrypt 해시
    nickname       VARCHAR2(60)  NOT NULL,                   -- 한글 20자
    role           VARCHAR2(10)  NOT NULL,                   -- USER / OWNER / ADMIN
    biz_no         VARCHAR2(12),                             -- 사업자등록번호 123-45-67890 (사장만)
    biz_file_path  VARCHAR2(500),                            -- 사업자등록증 경로, 비공개 폴더 (사장만)
    created_at     DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT member_pk          PRIMARY KEY (member_id),
    CONSTRAINT member_login_id_uk UNIQUE (login_id),
    CONSTRAINT member_nickname_uk UNIQUE (nickname),
    CONSTRAINT member_biz_no_uk   UNIQUE (biz_no),           -- NULL 은 여러 개 허용됨
    CONSTRAINT member_role_ck     CHECK (role IN ('USER', 'OWNER', 'ADMIN')),
    CONSTRAINT member_owner_ck    CHECK ((role = 'OWNER' AND biz_no IS NOT NULL AND biz_file_path IS NOT NULL)
                                      OR (role <> 'OWNER' AND biz_no IS NULL AND biz_file_path IS NULL))
);


-- ================= 방탈출 서버 (escape-service, 8082) =================

-- 3. 장르 (코드 테이블)
CREATE TABLE genre (
    genre_id  NUMBER        NOT NULL,
    name      VARCHAR2(30)  NOT NULL,
    CONSTRAINT genre_pk      PRIMARY KEY (genre_id),
    CONSTRAINT genre_name_uk UNIQUE (name)
);

-- 4. 브랜드 (본사 계정 없음. 더미 데이터로 넣음 → ERD 결정 B1)
CREATE TABLE brand (
    brand_id    NUMBER        NOT NULL,
    name        VARCHAR2(90)  NOT NULL,
    created_at  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT brand_pk      PRIMARY KEY (brand_id),
    CONSTRAINT brand_name_uk UNIQUE (name)
);

-- 5. 매장 (사장 등록 → PENDING → 관리자 승인 APPROVED / 반려 REJECTED)
CREATE TABLE store (
    store_id             NUMBER         NOT NULL,
    brand_id             NUMBER,                              -- NULL = 개인 매장
    owner_id             NUMBER,                              -- 등록한 사장 (FK 없음). 관리자 직접 등록이면 NULL
    name                 VARCHAR2(150)  NOT NULL,             -- 한글 50자
    area                 VARCHAR2(30)   NOT NULL,             -- 홍대 / 강남 / 건대 / 신촌 ...
    address              VARCHAR2(300)  NOT NULL,
    phone                VARCHAR2(20)   NOT NULL,
    hours                VARCHAR2(150),                       -- 영업시간 한 줄 (ERD 결정 S2)
    intro                VARCHAR2(600),                       -- 매장 소개 한글 200자 (ERD 결정 S2)
    lat                  NUMBER(9,6),                         -- 지도 (선택 기능)
    lng                  NUMBER(9,6),
    biz_place_no         VARCHAR2(12)   NOT NULL,             -- 사업장 등록번호
    biz_place_file_path  VARCHAR2(500),                       -- 사업장등록증 경로, 비공개 폴더
    status               VARCHAR2(10)   DEFAULT 'PENDING' NOT NULL,
    created_at           DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT store_pk           PRIMARY KEY (store_id),
    CONSTRAINT store_brand_fk     FOREIGN KEY (brand_id) REFERENCES brand(brand_id),
    CONSTRAINT store_biz_place_uk UNIQUE (biz_place_no),
    CONSTRAINT store_status_ck    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT store_file_ck      CHECK (owner_id IS NULL OR biz_place_file_path IS NOT NULL)
);

-- 6. 테마 (등록·수정 → PENDING → 승인 OPEN / 반려 REJECTED, 운영 종료 CLOSED)
CREATE TABLE theme (
    theme_id      NUMBER          NOT NULL,
    store_id      NUMBER          NOT NULL,
    title         VARCHAR2(150)   NOT NULL,
    description   VARCHAR2(4000),
    difficulty    NUMBER(1)       NOT NULL,
    play_minutes  NUMBER(3)       NOT NULL,                  -- 제한 시간 (분)
    min_people    NUMBER(2)       NOT NULL,
    max_people    NUMBER(2)       NOT NULL,
    price         NUMBER(7)       NOT NULL,                  -- 1인 가격, 인원 상관없이 고정
    poster_url    VARCHAR2(500),                             -- 테마 사진 경로 (공개 폴더)
    booking_url   VARCHAR2(500)   NOT NULL,                  -- http(s):// 로 시작 (서버 검사)
    source        VARCHAR2(10)    DEFAULT 'OWNER' NOT NULL,   -- OWNER / ADMIN / CRAWL
    status        VARCHAR2(10)    DEFAULT 'PENDING' NOT NULL,
    review_count  NUMBER(6)       DEFAULT 0 NOT NULL,         -- 트리거가 관리 (VISIBLE 후기 수)
    rating_sum    NUMBER(8)       DEFAULT 0 NOT NULL,         -- 트리거가 관리 (VISIBLE 별점 합)
    created_at    DATE            DEFAULT SYSDATE NOT NULL,
    updated_at    DATE            DEFAULT SYSDATE NOT NULL,   -- 트리거가 관리
    CONSTRAINT theme_pk         PRIMARY KEY (theme_id),
    CONSTRAINT theme_store_fk   FOREIGN KEY (store_id) REFERENCES store(store_id),
    CONSTRAINT theme_diff_ck    CHECK (difficulty BETWEEN 1 AND 5),
    CONSTRAINT theme_minutes_ck CHECK (play_minutes > 0),
    CONSTRAINT theme_people_ck  CHECK (min_people >= 1 AND min_people <= max_people),
    CONSTRAINT theme_price_ck   CHECK (price >= 0),
    CONSTRAINT theme_source_ck  CHECK (source IN ('OWNER', 'ADMIN', 'CRAWL')),
    CONSTRAINT theme_status_ck  CHECK (status IN ('PENDING', 'OPEN', 'REJECTED', 'CLOSED'))
);

-- 7. 테마-장르 (N:M)
CREATE TABLE theme_genre (
    id        NUMBER  NOT NULL,
    theme_id  NUMBER  NOT NULL,
    genre_id  NUMBER  NOT NULL,
    CONSTRAINT theme_genre_pk       PRIMARY KEY (id),
    CONSTRAINT theme_genre_theme_fk FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT theme_genre_genre_fk FOREIGN KEY (genre_id) REFERENCES genre(genre_id),
    CONSTRAINT theme_genre_uk       UNIQUE (theme_id, genre_id)
);

-- 8. 시간표 (날짜 없이 주중/주말 반복. 종료 시각 = start_time + theme.play_minutes)
CREATE TABLE time_slot (
    slot_id     NUMBER        NOT NULL,
    theme_id    NUMBER        NOT NULL,
    day_type    VARCHAR2(10)  NOT NULL,                      -- WEEKDAY(월~금) / WEEKEND(토·일)
    start_time  VARCHAR2(5)   NOT NULL,                      -- '19:00'
    created_at  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT time_slot_pk       PRIMARY KEY (slot_id),
    CONSTRAINT time_slot_theme_fk FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT time_slot_uk       UNIQUE (theme_id, day_type, start_time),
    CONSTRAINT time_slot_day_ck   CHECK (day_type IN ('WEEKDAY', 'WEEKEND')),
    CONSTRAINT time_slot_time_ck  CHECK (REGEXP_LIKE(start_time, '^([01][0-9]|2[0-3]):[0-5][0-9]$'))
);

-- 9. 찜 (회원 ↔ 테마)
CREATE TABLE wishlist (
    wish_id     NUMBER  NOT NULL,
    member_id   NUMBER  NOT NULL,                            -- FK 없음
    theme_id    NUMBER  NOT NULL,
    created_at  DATE    DEFAULT SYSDATE NOT NULL,
    CONSTRAINT wishlist_pk       PRIMARY KEY (wish_id),
    CONSTRAINT wishlist_theme_fk FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT wishlist_uk       UNIQUE (member_id, theme_id)
);

-- 10. 후기 (남은 시간은 초 단위. 상한 play_minutes*60 은 서버 검사)
CREATE TABLE review (
    review_id       NUMBER        NOT NULL,
    member_id       NUMBER        NOT NULL,                  -- FK 없음
    nickname        VARCHAR2(60)  NOT NULL,                  -- 작성 당시 닉네임 복사본
    theme_id        NUMBER        NOT NULL,
    rating          NUMBER(1)     NOT NULL,
    escaped         CHAR(1)       NOT NULL,                  -- Y / N
    hint_count      NUMBER(2)     DEFAULT 0 NOT NULL,
    player_count    NUMBER(2)     NOT NULL,                  -- 몇 명이서
    remain_seconds  NUMBER(5)     DEFAULT 0 NOT NULL,        -- 3분 47초 = 227
    played_date     DATE          DEFAULT TRUNC(SYSDATE) NOT NULL,
    content         VARCHAR2(600),
    status          VARCHAR2(10)  DEFAULT 'VISIBLE' NOT NULL,
    created_at      DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT review_pk         PRIMARY KEY (review_id),
    CONSTRAINT review_theme_fk   FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT review_uk         UNIQUE (member_id, theme_id),
    CONSTRAINT review_rating_ck  CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT review_escaped_ck CHECK (escaped IN ('Y', 'N')),
    CONSTRAINT review_hint_ck    CHECK (hint_count >= 0),
    CONSTRAINT review_player_ck  CHECK (player_count >= 1),
    CONSTRAINT review_remain_ck  CHECK (remain_seconds >= 0),
    CONSTRAINT review_status_ck  CHECK (status IN ('VISIBLE', 'HIDDEN'))
);

-- 11. 후기 신고 (이번 범위는 접수까지. 처리 화면은 나중)
CREATE TABLE report (
    report_id    NUMBER         NOT NULL,
    review_id    NUMBER         NOT NULL,
    reporter_id  NUMBER         NOT NULL,                    -- FK 없음
    reason       VARCHAR2(900)  NOT NULL,                    -- "[유형] 자세한 내용"
    status       VARCHAR2(10)   DEFAULT 'WAIT' NOT NULL,
    created_at   DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT report_pk        PRIMARY KEY (report_id),
    CONSTRAINT report_review_fk FOREIGN KEY (review_id) REFERENCES review(review_id),
    CONSTRAINT report_uk        UNIQUE (review_id, reporter_id),
    CONSTRAINT report_status_ck CHECK (status IN ('WAIT', 'DONE'))
);

-- 12. 선호 장르 (손님 가입 때 처음 들어감)
CREATE TABLE member_genre (
    id         NUMBER  NOT NULL,
    member_id  NUMBER  NOT NULL,                             -- FK 없음
    genre_id   NUMBER  NOT NULL,
    CONSTRAINT member_genre_pk       PRIMARY KEY (id),
    CONSTRAINT member_genre_genre_fk FOREIGN KEY (genre_id) REFERENCES genre(genre_id),
    CONSTRAINT member_genre_uk       UNIQUE (member_id, genre_id)
);

-- 13. 파티 (현재 인원은 party_member 줄 수로 계산)
CREATE TABLE party (
    party_id     NUMBER         NOT NULL,
    theme_id     NUMBER         NOT NULL,
    leader_id    NUMBER         NOT NULL,                    -- 방장 (FK 없음)
    title        VARCHAR2(300)  NOT NULL,                    -- 한글 100자
    intro        VARCHAR2(300)  NOT NULL,                    -- 방장 한마디 한글 100자
    play_at      DATE           NOT NULL,                    -- 날짜 + 시각 (그 요일 시간표에 있는 시각)
    deadline_at  DATE           NOT NULL,                    -- 모집 기한
    max_people   NUMBER(2)      NOT NULL,                    -- 방장 포함
    status       VARCHAR2(12)   DEFAULT 'RECRUITING' NOT NULL,
    created_at   DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT party_pk          PRIMARY KEY (party_id),
    CONSTRAINT party_theme_fk    FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT party_people_ck   CHECK (max_people >= 2),
    CONSTRAINT party_deadline_ck CHECK (deadline_at <= play_at),
    CONSTRAINT party_status_ck   CHECK (status IN ('RECRUITING', 'FULL', 'CLOSED'))
);

-- 14. 파티 참여자 (방장도 한 줄)
CREATE TABLE party_member (
    id         NUMBER        NOT NULL,
    party_id   NUMBER        NOT NULL,
    member_id  NUMBER        NOT NULL,                       -- FK 없음
    nickname   VARCHAR2(60)  NOT NULL,
    joined_at  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT party_member_pk       PRIMARY KEY (id),
    CONSTRAINT party_member_party_fk FOREIGN KEY (party_id) REFERENCES party(party_id),
    CONSTRAINT party_member_uk       UNIQUE (party_id, member_id)
);

-- 15. 파티 채팅 (msg_type: CHAT 일반 / JOIN·LEAVE·KICK 안내 줄)
CREATE TABLE party_message (
    message_id  NUMBER          NOT NULL,
    party_id    NUMBER          NOT NULL,
    member_id   NUMBER          NOT NULL,                    -- 보낸 사람 / 안내 대상 (FK 없음)
    nickname    VARCHAR2(60)    NOT NULL,
    msg_type    VARCHAR2(10)    DEFAULT 'CHAT' NOT NULL,
    content     VARCHAR2(1500),                              -- 한글 500자. 안내 줄은 NULL
    created_at  DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT party_message_pk       PRIMARY KEY (message_id),
    CONSTRAINT party_message_party_fk FOREIGN KEY (party_id) REFERENCES party(party_id),
    CONSTRAINT party_message_type_ck  CHECK (msg_type IN ('CHAT', 'JOIN', 'LEAVE', 'KICK')),
    CONSTRAINT party_message_text_ck  CHECK (msg_type <> 'CHAT' OR content IS NOT NULL)
);


-- 16. 시퀀스
CREATE SEQUENCE sq_member;
CREATE SEQUENCE sq_genre;
CREATE SEQUENCE sq_brand;
CREATE SEQUENCE sq_store;
CREATE SEQUENCE sq_theme;
CREATE SEQUENCE sq_theme_genre;
CREATE SEQUENCE sq_time_slot;
CREATE SEQUENCE sq_wishlist;
CREATE SEQUENCE sq_review;
CREATE SEQUENCE sq_report;
CREATE SEQUENCE sq_member_genre;
CREATE SEQUENCE sq_party;
CREATE SEQUENCE sq_party_member;
CREATE SEQUENCE sq_party_message;


-- 17. 트리거 (SQL Developer 는 블록 끝 "/" 까지 F5 로 실행)

-- 17-1. 후기 → 테마 별점 집계. VISIBLE 후기만 셈. 숨김(HIDDEN)으로 바뀌면 빠짐
--       REVIEW 를 다시 읽지 않고 THEME 만 고치므로 ORA-04091(mutating) 없음
CREATE OR REPLACE TRIGGER trg_review_theme_stats
AFTER INSERT OR DELETE OR UPDATE OF rating, status ON review
FOR EACH ROW
BEGIN
    IF (INSERTING OR UPDATING) AND :NEW.status = 'VISIBLE' THEN
        UPDATE theme
           SET review_count = review_count + 1,
               rating_sum   = rating_sum + :NEW.rating
         WHERE theme_id = :NEW.theme_id;
    END IF;
    IF (DELETING OR UPDATING) AND :OLD.status = 'VISIBLE' THEN
        UPDATE theme
           SET review_count = review_count - 1,
               rating_sum   = rating_sum - :OLD.rating
         WHERE theme_id = :OLD.theme_id;
    END IF;
END;
/

-- 17-2. 테마 수정일. 내용 컬럼이 바뀔 때만 (별점 집계로는 안 바뀜)
CREATE OR REPLACE TRIGGER trg_theme_updated_at
BEFORE UPDATE OF store_id, title, description, difficulty, play_minutes, min_people, max_people,
                 price, poster_url, booking_url, status ON theme
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSDATE;
END;
/


-- ================= 서버 1개로 확정되면 (MSA 안 할 때)만 =================
-- ALTER TABLE store         ADD CONSTRAINT store_owner_fk          FOREIGN KEY (owner_id)    REFERENCES member(member_id);
-- ALTER TABLE wishlist      ADD CONSTRAINT wishlist_member_fk      FOREIGN KEY (member_id)   REFERENCES member(member_id);
-- ALTER TABLE review        ADD CONSTRAINT review_member_fk        FOREIGN KEY (member_id)   REFERENCES member(member_id);
-- ALTER TABLE report        ADD CONSTRAINT report_reporter_fk      FOREIGN KEY (reporter_id) REFERENCES member(member_id);
-- ALTER TABLE member_genre  ADD CONSTRAINT member_genre_member_fk  FOREIGN KEY (member_id)   REFERENCES member(member_id);
-- ALTER TABLE party         ADD CONSTRAINT party_leader_fk         FOREIGN KEY (leader_id)   REFERENCES member(member_id);
-- ALTER TABLE party_member  ADD CONSTRAINT party_member_member_fk  FOREIGN KEY (member_id)   REFERENCES member(member_id);
-- ALTER TABLE party_message ADD CONSTRAINT party_message_member_fk FOREIGN KEY (member_id)   REFERENCES member(member_id);
