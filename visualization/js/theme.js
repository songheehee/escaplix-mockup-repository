// 라이트/다크 모드 (모든 화면 <head>에서 가장 먼저 불러서, 깜빡임 없이 저장된 모드로 시작)
// 저장: localStorage "escaplix-theme" = "dark" | "light"  (못 쓰는 환경이면 그냥 다크)
(function () {
  const KEY = "escaplix-theme";
  let saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) { /* 개인정보 보호 모드 등 */ }
  document.documentElement.dataset.theme = saved === "light" ? "light" : "dark";

  window.escaplixTheme = {
    get: function () { return document.documentElement.dataset.theme; },
    toggle: function () {
      const next = this.get() === "dark" ? "light" : "dark";
      document.documentElement.dataset.theme = next;
      try { localStorage.setItem(KEY, next); } catch (e) { /* 저장 못 해도 화면은 바뀜 */ }
      document.querySelectorAll("[data-theme-toggle]").forEach(window.escaplixTheme.paint);
      return next;
    },
    // 버튼 모양 다시 그리기 (모드가 바뀔 때마다)
    paint: function (btn) {
      const dark = document.documentElement.dataset.theme === "dark";
      if (btn.dataset.themeToggle === "label") {
        // 사이드 패널용: [아이콘] 지금 모드 · 스위치
        btn.textContent = "";
        const ico = document.createElement("span");
        ico.className = "sn-ico";
        ico.textContent = dark ? "🌙" : "☀";
        const label = document.createElement("span");
        label.className = "sn-theme-label";
        label.textContent = dark ? "다크 모드" : "라이트 모드";
        const sw = document.createElement("span");
        sw.className = "sn-switch" + (dark ? " on" : "");
        btn.append(ico, label, sw);
        btn.setAttribute("aria-pressed", String(dark));
        btn.title = dark ? "라이트 모드로 바꾸기" : "다크 모드로 바꾸기";
        btn.setAttribute("aria-label", btn.title);
        return;
      }
      btn.textContent = dark ? "☀" : "🌙";
      btn.title = dark ? "라이트 모드로" : "다크 모드로";
      btn.setAttribute("aria-label", btn.title);
    },
    // 버튼 만들기: button(true) = 사이드 패널용 스위치 줄, button() = 동그란 아이콘 (흐름 지도)
    button: function (withLabel) {
      const b = document.createElement("button");
      b.type = "button";
      b.className = withLabel ? "sn-theme" : "theme-toggle";
      b.setAttribute("data-theme-toggle", withLabel ? "label" : "");
      b.addEventListener("click", function () { window.escaplixTheme.toggle(); });
      window.escaplixTheme.paint(b);
      return b;
    },
  };
})();
