// 매장 가짜 데이터 (매장 목록 S27 · 매장 상세 S28 이 같이 씀)
// 실제 서비스: 목록 B-9 GET /api/stores?area=&keyword= , 상세 B-10 GET /api/stores/{id} (+ 그 매장 OPEN 테마)
const STORES = [
  {
    id: 1, name: "미스터리룸 홍대점", area: "홍대", addr: "서울 마포구 (예시 주소) 1층",
    phone: "02-000-0001", hours: "10:00 ~ 23:00 (연중무휴)", website: "https://example.com/store/1", g: "horror",
    intro: "홍대입구역 9번 출구 3분. 공포·추리 테마가 강한 매장이에요.",
    themes: [
      { id: 1, name: "저주받은 인형의 집", genres: ["공포", "추리"], g: "horror", lv: 4, min: 70, ppl: "2~4", price: 25000, rate: 4.0, reviews: 1, parties: 2 },
      { id: 2, name: "할머니의 다락방", genres: ["감성"], g: "emotion", lv: 2, min: 60, ppl: "2~4", price: 22000, rate: 4.7, reviews: 3, parties: 1 },
      { id: 3, name: "13번째 배심원", genres: ["추리"], g: "mystery", lv: 3, min: 75, ppl: "2~5", price: 23000, rate: 4.2, reviews: 2, parties: 0 },
    ],
  },
  {
    id: 2, name: "미스터리룸 강남점", area: "강남", addr: "서울 강남구 (예시 주소) B1",
    phone: "02-000-0002", hours: "11:00 ~ 24:00", website: "https://example.com/store/2", g: "stealth",
    intro: "강남역 11번 출구. 잠입·SF 같은 대형 세트 테마가 있어요.",
    themes: [
      { id: 5, name: "금고털이", genres: ["잠입", "추리"], g: "stealth", lv: 4, min: 60, ppl: "2~4", price: 26000, rate: 5.0, reviews: 2, parties: 1 },
      { id: 7, name: "우주정거장 탈출", genres: ["SF"], g: "sf", lv: 3, min: 65, ppl: "2~5", price: 27000, rate: 4.1, reviews: 4, parties: 0 },
    ],
  },
  {
    id: 3, name: "어둠상자 홍대점", area: "홍대", addr: "서울 마포구 (예시 주소) 3층",
    phone: "02-000-0003", hours: "12:00 ~ 22:00 (화 휴무)", website: "https://example.com/store/3", g: "mystery",
    intro: "작은 개인 매장. 스토리가 탄탄한 추리 테마 위주예요.",
    themes: [
      { id: 4, name: "가면 무도회", genres: ["잠입", "추리"], g: "stealth", lv: 4, min: 70, ppl: "2~4", price: 25000, rate: null, reviews: 0, parties: 0 },
      { id: 9, name: "사라진 기억", genres: ["추리", "감성"], g: "mystery", lv: 3, min: 70, ppl: "2~4", price: 24000, rate: 4.4, reviews: 5, parties: 0 },
    ],
  },
  {
    id: 4, name: "열쇠공방 건대점", area: "건대", addr: "서울 광진구 (예시 주소) 2층",
    phone: "02-000-0004", hours: "10:30 ~ 23:30", website: "https://example.com/store/4", g: "adventure",
    intro: "건대입구역 2번 출구. 무서운 테마와 어드벤처 테마가 반반이에요.",
    themes: [
      { id: 6, name: "폐병원 304호", genres: ["공포"], g: "horror", lv: 5, min: 70, ppl: "2~4", price: 25000, rate: 4.5, reviews: 6, parties: 1 },
      { id: 11, name: "황금 신전의 비밀", genres: ["어드벤처"], g: "adventure", lv: 3, min: 70, ppl: "2~6", price: 23000, rate: 4.0, reviews: 1, parties: 0 },
    ],
  },
  {
    id: 5, name: "열쇠공방 신촌점", area: "신촌", addr: "서울 서대문구 (예시 주소) 4층",
    phone: "02-000-0005", hours: "11:00 ~ 23:00", website: "https://example.com/store/5", g: "horror",
    intro: "신촌역 3번 출구. 인원이 많아도 할 수 있는 테마가 있어요.",
    themes: [
      { id: 8, name: "좀비 연구소", genres: ["공포", "어드벤처"], g: "horror", lv: 4, min: 60, ppl: "3~6", price: 22000, rate: 3.0, reviews: 2, parties: 0 },
      { id: 10, name: "명탐정의 마지막 사건", genres: ["추리"], g: "mystery", lv: 4, min: 80, ppl: "2~5", price: 26000, rate: 4.3, reviews: 3, parties: 0 },
    ],
  },
];

// 작은 도우미: 요소 만들기 (글자는 항상 textContent)
function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}
function storeRate(s) {
  const rated = s.themes.filter(function (t) { return t.rate; });
  if (!rated.length) return null;
  return rated.reduce(function (a, t) { return a + t.rate; }, 0) / rated.length;
}
