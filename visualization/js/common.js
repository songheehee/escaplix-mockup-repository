// 공통 헤더 (S01) 목업
// 실제 서비스에서는 sessionStorage의 토큰을 보고 그리지만,
// 여기서는 <body data-as="guest|user|owner|admin"> 값으로 "누가 보고 있는지"를 흉내 낸다.

(function () {
  // ?as=admin 처럼 주소로 바꿔 볼 수도 있다 (관리자가 매장·테마를 직접 등록하는 화면 등)
  const who = new URLSearchParams(location.search).get("as") || document.body.dataset.as || "guest";

  const menus = {
    guest: { name: null, links: [["stores.html", "매장", "🏪"], ["map.html", "매장 지도", "🗺"]] },
    user: {
      name: ["탈출왕", "USER"],
      links: [["stores.html", "매장", "🏪"], ["party-list.html", "파티", "👥"], ["mypage.html", "마이페이지", "🙂"]],
    },
    owner: {
      name: ["미스터리룸홍대", "OWNER · 사장"],
      links: [["owner.html", "사장 홈", "🏠"], ["store-form.html", "매장 등록", "➕"], ["owner-theme.html", "테마 등록", "🚪"], ["owner-slots.html", "시간표 관리", "🕒"]],
    },
    admin: {
      name: ["관리자", "ADMIN"],
      links: [
        ["admin.html", "관리자 홈", "🎛"], ["admin-stores.html", "매장 승인", "🏪"], ["admin-themes.html", "테마 승인", "🚪"],
        ["admin-members.html", "회원 관리", "👤"],
      ],
    },
  };

  const m = menus[who];

  const header = document.createElement("header");
  header.className = "site-header";

  // ☰ 버튼 (사이드 패널 열기/닫기)
  const burger = document.createElement("button");
  burger.type = "button";
  burger.className = "burger";
  burger.setAttribute("aria-label", "메뉴 열기");
  burger.setAttribute("aria-controls", "side-nav");
  burger.setAttribute("aria-expanded", "false");
  for (let k = 0; k < 3; k++) burger.append(document.createElement("span"));
  header.append(burger);

  function makeLogo() {
    const logo = document.createElement("a");
    logo.className = "logo";
    logo.href = who === "owner" ? "owner.html" : who === "admin" ? "admin.html" : "main.html";
    logo.append("Escap");
    const span = document.createElement("span");
    span.textContent = "lix";
    logo.append(span);
    return logo;
  }
  let searchForm = null; // 검색창은 사이드 패널 안으로

  // 통합 검색창 (손님·비회원)
  // 한 줄 안에: 🔍 검색어 + 고른 조건 칩(✕로 하나씩 빼기) + ⚙
  // 누르면 바로 아래로 같은 톤의 패널이 붙어서 펼쳐지고, "검색" 한 번으로 둘 다 적용 → 메인 결과
  if (who === "guest" || who === "user") {
    const qs = new URLSearchParams(location.search);
    const onMain = /main\.html$/.test(location.pathname);
    const FIELDS = [
      { key: "area", label: "지역", options: [["", "전체"], ["홍대", "홍대"], ["강남", "강남"], ["건대", "건대"], ["신촌", "신촌"]] },
      { key: "date", label: "날짜", type: "date" },
      { key: "people", label: "인원", options: [["", "상관없음"], ["2", "2명"], ["3", "3명"], ["4", "4명"], ["5", "5명"], ["6", "6명"]] },
      { key: "genre", label: "장르", options: [["", "전체"], ["공포", "공포"], ["추리", "추리"], ["감성", "감성"], ["잠입", "잠입"], ["어드벤처", "어드벤처"], ["SF", "SF"], ["코믹", "코믹"]] },
      { key: "sort", label: "정렬", options: [["rate", "평점순"], ["new", "최신순"]], def: "rate" },
    ];
    const mk = function (tag, cls, text) {
      const n = document.createElement(tag);
      if (cls) n.className = cls;
      if (text != null) n.textContent = text;
      return n;
    };

    const form = mk("form", "unified-search");
    form.action = "main.html";
    form.setAttribute("role", "search");

    // 1) 한 줄 막대
    const bar = mk("div", "us-bar");
    bar.append(mk("span", "us-ico", "🔍"));
    const input = mk("input", "us-input");
    input.type = "search";
    input.name = "q";
    input.placeholder = "테마·매장 검색";
    input.autocomplete = "off";
    input.setAttribute("aria-label", "테마·매장 검색");
    if (onMain) input.value = qs.get("q") || "";
    const chips = mk("div", "us-chips");
    const toggle = mk("button", "us-toggle", "⚙");
    toggle.type = "button";
    toggle.title = "조건 고르기";
    toggle.setAttribute("aria-expanded", "false");
    bar.append(input, chips, toggle);

    // 2) 아래로 붙는 패널
    const panel = mk("div", "us-panel");
    panel.hidden = true;
    const grid = mk("div", "us-grid");
    const controls = {};
    FIELDS.forEach(function (f) {
      const wrap = mk("label", "us-field");
      wrap.append(mk("span", null, f.label));
      let c;
      if (f.type === "date") {
        c = mk("input");
        c.type = "date";
        c.min = "2026-11-17"; // 목업 기준 오늘 (오늘 이후만)
      } else {
        c = mk("select");
        f.options.forEach(function (o) {
          const op = mk("option", null, o[1]);
          op.value = o[0];
          c.append(op);
        });
      }
      c.name = f.key;
      c.value = (onMain && qs.get(f.key)) || f.def || "";
      controls[f.key] = c;
      wrap.append(c);
      grid.append(wrap);
    });
    const foot = mk("div", "us-foot");
    const summary = mk("span", "us-summary");
    const reset = mk("button", "us-reset", "초기화");
    reset.type = "button";
    const go = mk("button", "us-go", "검색");
    go.type = "submit";
    foot.append(summary, reset, go);
    panel.append(grid, foot);

    form.append(bar, panel);

    // 고른 조건 → 막대 안 칩 + 패널 아래 요약
    function text(f) {
      const c = controls[f.key];
      if (!c.value || c.value === f.def) return "";
      if (f.type === "date") return c.value.slice(5).replace("-", "/");
      return c.options[c.selectedIndex].textContent;
    }
    function draw() {
      chips.textContent = "";
      const parts = [];
      FIELDS.forEach(function (f) {
        const t = text(f);
        if (!t) return;
        parts.push(t);
        const chip = mk("span", "us-chip", t);
        const x = mk("button", null, "✕");
        x.type = "button";
        x.setAttribute("aria-label", f.label + " 조건 빼기");
        x.addEventListener("click", function (e) {
          e.stopPropagation();
          controls[f.key].value = f.def || "";
          draw();
          if (onMain) form.requestSubmit(); // 결과 화면이면 바로 다시 검색
        });
        chip.append(x);
        chips.append(chip);
      });
      toggle.classList.toggle("on", parts.length > 0);
      const kw = input.value.trim();
      summary.textContent = (kw ? "‘" + kw + "’ " : "") + (parts.length ? parts.join(" · ") : (kw ? "" : "모든 테마"));
    }
    draw();
    grid.addEventListener("change", draw);
    input.addEventListener("input", draw);

    function open(v) {
      panel.hidden = !v;
      form.classList.toggle("open", v);
      toggle.setAttribute("aria-expanded", String(v));
    }
    toggle.addEventListener("click", function () { open(panel.hidden); });
    chips.addEventListener("click", function () { open(true); });
    input.addEventListener("focus", function () { open(true); });
    reset.addEventListener("click", function () {
      input.value = "";
      FIELDS.forEach(function (f) { controls[f.key].value = f.def || ""; });
      draw();
    });
    document.addEventListener("click", function (e) { if (!form.contains(e.target)) open(false); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") open(false); });
    form.addEventListener("submit", function () {
      // 빈 값·기본값은 주소에 안 붙게
      Array.from(form.elements).forEach(function (x) {
        const f = FIELDS.find(function (y) { return y.key === x.name; });
        if (x.name && (x.value === "" || (f && x.value === f.def))) x.disabled = true;
      });
    });
    searchForm = form;
  }


  // ---------- 왼쪽 사이드 패널 ----------
  const side = document.createElement("aside");
  side.className = "side-nav";
  side.id = "side-nav";
  side.setAttribute("aria-label", "메뉴");
  side.setAttribute("aria-hidden", "true");

  const sideTop = document.createElement("div");
  sideTop.className = "sn-top";
  const close = document.createElement("button");
  close.type = "button";
  close.className = "sn-close";
  close.textContent = "✕";
  close.setAttribute("aria-label", "메뉴 닫기");
  sideTop.append(makeLogo(), close);
  side.append(sideTop);

  // 누가 보고 있나
  const me = document.createElement("div");
  me.className = "sn-me";
  if (m.name) {
    const av = document.createElement("div");
    av.className = "sn-avatar";
    av.textContent = m.name[0].slice(0, 1);
    const txt = document.createElement("div");
    const b = document.createElement("b");
    b.textContent = m.name[0];
    const badge = document.createElement("span");
    badge.className = "role-badge";
    badge.textContent = m.name[1];
    txt.append(b, document.createElement("br"), badge);
    me.append(av, txt);
  } else {
    const hi = document.createElement("p");
    hi.textContent = "로그인하면 파티를 만들고 찜할 수 있어요";
    const row = document.createElement("div");
    row.className = "sn-auth";
    const login = document.createElement("a");
    login.className = "btn small";
    login.href = "login.html";
    login.textContent = "로그인";
    const signup = document.createElement("a");
    signup.className = "btn ghost small";
    signup.href = "signup.html";
    signup.textContent = "회원가입";
    row.append(login, signup);
    me.append(hi, row);
    me.classList.add("guest");
  }
  side.append(me);

  // 메뉴 (지금 화면은 강조)
  const here = location.pathname.split("/").pop() || "main.html";
  const nav = document.createElement("nav");
  nav.className = "sn-links";
  m.links.forEach(function (l) {
    const a = document.createElement("a");
    a.href = l[0];
    const ico = document.createElement("span");
    ico.className = "sn-ico";
    ico.textContent = l[2] || "•";
    ico.setAttribute("aria-hidden", "true");
    a.append(ico, l[1]);
    if (l[0].split("?")[0] === here) { a.classList.add("on"); a.setAttribute("aria-current", "page"); }
    nav.append(a);
  });
  if (searchForm) {
    const sw = document.createElement("div");
    sw.className = "sn-search";
    sw.append(searchForm);
    side.insertBefore(sw, me.nextSibling);
  }
  side.append(nav);

  // 화면 모드 (라이트/다크)
  if (window.escaplixTheme) {
    const tw = document.createElement("div");
    tw.className = "sn-theme-wrap";
    tw.append(window.escaplixTheme.button(true));
    side.append(tw);
  }

  // 아래쪽: 로그아웃 · 흐름 지도
  const foot = document.createElement("div");
  foot.className = "sn-foot";
  if (m.name) {
    const out = document.createElement("a");
    out.href = "login.html";
    out.textContent = "↩ 로그아웃";
    foot.append(out);
  }
  const map = document.createElement("a");
  map.href = "index.html";
  map.className = "muted";
  map.textContent = "목업 흐름 지도";
  foot.append(map);
  side.append(foot);

  const dim = document.createElement("div");
  dim.className = "side-dim";

  function setSide(open) {
    side.classList.toggle("open", open);
    dim.classList.toggle("open", open);
    document.body.classList.toggle("side-open", open);
    side.setAttribute("aria-hidden", String(!open));
    burger.setAttribute("aria-expanded", String(open));
    burger.setAttribute("aria-label", open ? "메뉴 닫기" : "메뉴 열기");
    burger.classList.toggle("x", open);
    side.querySelectorAll("a, button").forEach(function (x) { x.tabIndex = open ? 0 : -1; });
    if (open) close.focus();
  }
  burger.addEventListener("click", function () { setSide(!side.classList.contains("open")); });
  close.addEventListener("click", function () { setSide(false); burger.focus(); });
  dim.addEventListener("click", function () { setSide(false); });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && side.classList.contains("open")) { setSide(false); burger.focus(); }
  });


  document.body.prepend(header);
  document.body.append(dim, side);
  setSide(false);
})();
