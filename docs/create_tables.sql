-- 방탈출 통합예약 (Escaplix) : 테이블 생성 v3 (hr 계정에서 실행)
-- docs/ERD.md 와 짝. 11/18 팀 결정(ERD 8번 표) 반영
-- Oracle XE 11g, 서버 1개(모놀리식). 테이블 14개 + 트리거 2개
--  * 한글 1글자 = 3바이트 (AL32UTF8). VARCHAR2 크기는 바이트
--  * 서버가 하나라 회원번호 컬럼도 전부 진짜 FK. 닉네임은 복사하지 않고 MEMBER 와 JOIN
--  * 매장·테마·파티는 DELETE 하지 말고 status 로 관리
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
DROP TABLE holiday;
DROP TABLE genre;
DROP TABLE member;
-- (brand 는 이전 버전 정리용. 지금은 안 씀)
DROP TABLE brand;

DROP SEQUENCE sq_member;
DROP SEQUENCE sq_genre;
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
-- (sq_brand 는 이전 버전 정리용)
DROP SEQUENCE sq_brand;


-- 2. 회원 (손님 / 사장 / 관리자). 사장은 사업자등록번호·사업자등록증 필수
CREATE TABLE member (
    member_id      NUMBER        NOT NULL,
    login_id       VARCHAR2(30)  NOT NULL,                   -- 영문·숫자
    password       VARCHAR2(60)  NOT NULL,                   -- BCrypt 해시
    nickname       VARCHAR2(60)  NOT NULL,                   -- 한글 20자. 바꾸면 모든 화면에 바로 반영 (JOIN)
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

-- 3. 장르 (코드 테이블)
CREATE TABLE genre (
    genre_id  NUMBER        NOT NULL,
    name      VARCHAR2(30)  NOT NULL,
    CONSTRAINT genre_pk      PRIMARY KEY (genre_id),
    CONSTRAINT genre_name_uk UNIQUE (name)
);

-- 4. 공휴일 (공휴일은 주말 시간표로 봄. 더미 데이터로 해마다 넣음)
CREATE TABLE holiday (
    holiday_date  DATE          NOT NULL,                    -- 시각 없이 날짜만 (TRUNC)
    name          VARCHAR2(60)  NOT NULL,                    -- 설날, 추석 ...
    CONSTRAINT holiday_pk      PRIMARY KEY (holiday_date),
    CONSTRAINT holiday_date_ck CHECK (holiday_date = TRUNC(holiday_date))
);

-- 5. 매장 (사장 등록·수정 → PENDING → 관리자 승인 APPROVED / 반려 REJECTED + 사유)
CREATE TABLE store (
    store_id             NUMBER         NOT NULL,
    owner_id             NUMBER,                              -- 등록한 사장. 관리자 직접 등록이면 NULL
    name                 VARCHAR2(150)  NOT NULL,             -- 한글 50자
    area                 VARCHAR2(30)   NOT NULL,             -- 홍대 / 강남 / 건대 / 신촌 ...
    address              VARCHAR2(300)  NOT NULL,
    phone                VARCHAR2(20)   NOT NULL,
    website_url          VARCHAR2(500)  NOT NULL,             -- 매장 웹사이트. http(s):// 로 시작 (서버 검사)
    hours                VARCHAR2(150)  NOT NULL,             -- 영업시간 한 줄 "10:00 ~ 23:00 (연중무휴)"
    intro                VARCHAR2(600)  NOT NULL,             -- 매장 소개 한글 200자
    photo_url            VARCHAR2(500),                       -- 매장 사진 공개 주소 "/uploads/stores/uuid.jpg". 없으면 NULL
    lat                  NUMBER(9,6),                         -- 지도 (선택 기능)
    lng                  NUMBER(9,6),
    biz_place_no         VARCHAR2(12)   NOT NULL,             -- 사업장 등록번호
    biz_place_file_path  VARCHAR2(500),                       -- 사업장등록증 경로, 비공개 폴더
    status               VARCHAR2(10)   DEFAULT 'PENDING' NOT NULL,
    reject_reason        VARCHAR2(900),                       -- 반려 사유 (관리자 작성, 한글 300자)
    created_at           DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT store_pk           PRIMARY KEY (store_id),
    CONSTRAINT store_owner_fk     FOREIGN KEY (owner_id) REFERENCES member(member_id),
    CONSTRAINT store_biz_place_uk UNIQUE (biz_place_no),
    CONSTRAINT store_status_ck    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT store_file_ck      CHECK (owner_id IS NULL OR biz_place_file_path IS NOT NULL),
    CONSTRAINT store_reject_ck    CHECK (status <> 'REJECTED' OR reject_reason IS NOT NULL)
);

-- 6. 테마 (등록·수정 → PENDING → 승인 OPEN / 반려 REJECTED + 사유, 운영 종료 CLOSED)
CREATE TABLE theme (
    theme_id       NUMBER          NOT NULL,
    store_id       NUMBER          NOT NULL,
    title          VARCHAR2(150)   NOT NULL,
    description    VARCHAR2(4000),
    difficulty     NUMBER(1)       NOT NULL,
    play_minutes   NUMBER(3)       NOT NULL,                 -- 제한 시간 (분)
    min_people     NUMBER(2)       NOT NULL,
    max_people     NUMBER(2)       NOT NULL,
    price          NUMBER(7)       NOT NULL,                 -- 1인 가격, 인원 상관없이 고정
    poster_url     VARCHAR2(500),                            -- 테마 사진 경로 (공개 폴더)
    booking_url    VARCHAR2(500)   NOT NULL,                 -- 이 테마 예약 링크. http(s):// (서버 검사)
    source         VARCHAR2(10)    DEFAULT 'OWNER' NOT NULL,  -- OWNER / ADMIN / CRAWL
    status         VARCHAR2(10)    DEFAULT 'PENDING' NOT NULL,
    reject_reason  VARCHAR2(900),                            -- 반려 사유 (관리자 작성)
    review_count   NUMBER(6)       DEFAULT 0 NOT NULL,        -- 트리거가 관리 (VISIBLE 후기 수)
    rating_sum     NUMBER(8)       DEFAULT 0 NOT NULL,        -- 트리거가 관리 (VISIBLE 별점 합)
    created_at     DATE            DEFAULT SYSDATE NOT NULL,
    updated_at     DATE            DEFAULT SYSDATE NOT NULL,  -- 트리거가 관리
    CONSTRAINT theme_pk         PRIMARY KEY (theme_id),
    CONSTRAINT theme_store_fk   FOREIGN KEY (store_id) REFERENCES store(store_id),
    CONSTRAINT theme_diff_ck    CHECK (difficulty BETWEEN 1 AND 5),
    CONSTRAINT theme_minutes_ck CHECK (play_minutes > 0),
    CONSTRAINT theme_people_ck  CHECK (min_people >= 1 AND min_people <= max_people),
    CONSTRAINT theme_price_ck   CHECK (price >= 0),
    CONSTRAINT theme_source_ck  CHECK (source IN ('OWNER', 'ADMIN', 'CRAWL')),
    CONSTRAINT theme_status_ck  CHECK (status IN ('PENDING', 'OPEN', 'REJECTED', 'CLOSED')),
    CONSTRAINT theme_reject_ck  CHECK (status <> 'REJECTED' OR reject_reason IS NOT NULL)
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

-- 8. 시간표 (날짜 없이 주중/주말 반복. 토·일·공휴일 = WEEKEND. 종료 시각 = start_time + theme.play_minutes)
CREATE TABLE time_slot (
    slot_id     NUMBER        NOT NULL,
    theme_id    NUMBER        NOT NULL,
    day_type    VARCHAR2(10)  NOT NULL,                      -- WEEKDAY / WEEKEND
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
    member_id   NUMBER  NOT NULL,
    theme_id    NUMBER  NOT NULL,
    created_at  DATE    DEFAULT SYSDATE NOT NULL,
    CONSTRAINT wishlist_pk        PRIMARY KEY (wish_id),
    CONSTRAINT wishlist_member_fk FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT wishlist_theme_fk  FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT wishlist_uk        UNIQUE (member_id, theme_id)
);

-- 10. 후기 (남은 시간은 분·초 두 칸, 실패면 둘 다 0. 상한 분*60+초 <= play_minutes*60 은 서버 검사)
CREATE TABLE review (
    review_id       NUMBER        NOT NULL,
    member_id       NUMBER        NOT NULL,
    theme_id        NUMBER        NOT NULL,
    rating          NUMBER(1)     NOT NULL,
    escaped         CHAR(1)       NOT NULL,                  -- Y / N
    hint_count      NUMBER(2)     DEFAULT 0 NOT NULL,
    player_count    NUMBER(2)     NOT NULL,                  -- 몇 명이서
    remain_minutes  NUMBER(3)     DEFAULT 0 NOT NULL,        -- 남은 시간 분 (3분 47초면 3)
    remain_seconds  NUMBER(2)     DEFAULT 0 NOT NULL,        -- 남은 시간 초 0~59 (3분 47초면 47)
    played_date     DATE          DEFAULT TRUNC(SYSDATE) NOT NULL,  -- 비우면 작성일
    content         VARCHAR2(600),
    status          VARCHAR2(10)  DEFAULT 'VISIBLE' NOT NULL,
    created_at      DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT review_pk         PRIMARY KEY (review_id),
    CONSTRAINT review_member_fk  FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT review_theme_fk   FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT review_uk         UNIQUE (member_id, theme_id),
    CONSTRAINT review_rating_ck  CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT review_escaped_ck CHECK (escaped IN ('Y', 'N')),
    CONSTRAINT review_hint_ck    CHECK (hint_count >= 0),
    CONSTRAINT review_player_ck  CHECK (player_count >= 1),
    CONSTRAINT review_min_ck     CHECK (remain_minutes >= 0),
    CONSTRAINT review_sec_ck     CHECK (remain_seconds BETWEEN 0 AND 59),
    CONSTRAINT review_fail_ck    CHECK (escaped = 'Y' OR (remain_minutes = 0 AND remain_seconds = 0)),
    CONSTRAINT review_status_ck  CHECK (status IN ('VISIBLE', 'HIDDEN'))
);

-- 11. 후기 신고 (사유는 자유 글만. 이번 범위는 접수까지)
CREATE TABLE report (
    report_id    NUMBER         NOT NULL,
    review_id    NUMBER         NOT NULL,
    reporter_id  NUMBER         NOT NULL,
    reason       VARCHAR2(900)  NOT NULL,                    -- 한글 300자
    status       VARCHAR2(10)   DEFAULT 'WAIT' NOT NULL,
    created_at   DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT report_pk          PRIMARY KEY (report_id),
    CONSTRAINT report_review_fk   FOREIGN KEY (review_id) REFERENCES review(review_id),
    CONSTRAINT report_reporter_fk FOREIGN KEY (reporter_id) REFERENCES member(member_id),
    CONSTRAINT report_uk          UNIQUE (review_id, reporter_id),
    CONSTRAINT report_status_ck   CHECK (status IN ('WAIT', 'DONE'))
);

-- 12. 선호 장르 (손님 가입 때 처음 들어감)
CREATE TABLE member_genre (
    id         NUMBER  NOT NULL,
    member_id  NUMBER  NOT NULL,
    genre_id   NUMBER  NOT NULL,
    CONSTRAINT member_genre_pk        PRIMARY KEY (id),
    CONSTRAINT member_genre_member_fk FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT member_genre_genre_fk  FOREIGN KEY (genre_id) REFERENCES genre(genre_id),
    CONSTRAINT member_genre_uk        UNIQUE (member_id, genre_id)
);

-- 13. 파티 (현재 인원 = party_member 에서 status='JOINED' 줄 수. 삭제는 status='DELETED')
CREATE TABLE party (
    party_id     NUMBER         NOT NULL,
    theme_id     NUMBER         NOT NULL,
    leader_id    NUMBER         NOT NULL,                    -- 방장
    title        VARCHAR2(300)  NOT NULL,                    -- 한글 100자
    intro        VARCHAR2(300)  NOT NULL,                    -- 방장 한마디 한글 100자
    play_at      DATE           NOT NULL,                    -- 날짜 + 시각 (그 날 유형 시간표에 있는 시각)
    deadline_at  DATE           NOT NULL,                    -- 모집 기한
    max_people   NUMBER(2)      NOT NULL,                    -- 방장 포함
    status       VARCHAR2(12)   DEFAULT 'RECRUITING' NOT NULL,
    created_at   DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT party_pk          PRIMARY KEY (party_id),
    CONSTRAINT party_theme_fk    FOREIGN KEY (theme_id) REFERENCES theme(theme_id),
    CONSTRAINT party_leader_fk   FOREIGN KEY (leader_id) REFERENCES member(member_id),
    CONSTRAINT party_people_ck   CHECK (max_people >= 2),
    CONSTRAINT party_deadline_ck CHECK (deadline_at <= play_at),
    CONSTRAINT party_status_ck   CHECK (status IN ('RECRUITING', 'FULL', 'CLOSED', 'DELETED'))
);

-- 14. 파티 참여자 (방장도 한 줄. 나가면 줄 삭제, 강퇴되면 status='KICKED' 로 남겨 재참여 막음)
CREATE TABLE party_member (
    id         NUMBER        NOT NULL,
    party_id   NUMBER        NOT NULL,
    member_id  NUMBER        NOT NULL,
    status     VARCHAR2(10)  DEFAULT 'JOINED' NOT NULL,      -- JOINED / KICKED
    joined_at  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT party_member_pk        PRIMARY KEY (id),
    CONSTRAINT party_member_party_fk  FOREIGN KEY (party_id) REFERENCES party(party_id),
    CONSTRAINT party_member_member_fk FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT party_member_uk        UNIQUE (party_id, member_id),
    CONSTRAINT party_member_status_ck CHECK (status IN ('JOINED', 'KICKED'))
);

-- 15. 파티 채팅 (msg_type: CHAT 일반 / JOIN·LEAVE·KICK 안내 줄)
CREATE TABLE party_message (
    message_id  NUMBER          NOT NULL,
    party_id    NUMBER          NOT NULL,
    member_id   NUMBER          NOT NULL,                    -- 보낸 사람 / 안내 대상
    msg_type    VARCHAR2(10)    DEFAULT 'CHAT' NOT NULL,
    content     VARCHAR2(1500),                              -- 한글 500자. 안내 줄은 NULL
    created_at  DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT party_message_pk        PRIMARY KEY (message_id),
    CONSTRAINT party_message_party_fk  FOREIGN KEY (party_id) REFERENCES party(party_id),
    CONSTRAINT party_message_member_fk FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT party_message_type_ck   CHECK (msg_type IN ('CHAT', 'JOIN', 'LEAVE', 'KICK')),
    CONSTRAINT party_message_text_ck   CHECK (msg_type <> 'CHAT' OR content IS NOT NULL)
);


-- 16. 시퀀스 (holiday 는 날짜가 PK 라 시퀀스 없음)
CREATE SEQUENCE sq_member;
CREATE SEQUENCE sq_genre;
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
