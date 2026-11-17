// S17 후기 쓰기 팝업 (공용)
// 어느 화면이든 이 파일만 불러오면, data-review 가 붙은 버튼을 눌렀을 때
// 페이지 이동 없이 같은 팝업이 뜬다. (실제 서비스에선 js/review-modal.js, D 담당)
//
// 버튼 예시
//   <a href="#" data-review data-theme="저주받은 인형의 집 · 미스터리룸 홍대점" data-limit="70">후기 쓰기</a>
//   <a href="#" data-review="edit" data-theme="…" data-limit="60" data-rate="5" data-min="8" data-sec="12" …>수정</a>
//   data-theme 이 없으면 "플레이한 테마" 선택 칸이 나온다 (마이페이지).

(function () {
  // 1. 팝업 뼈대 (화면마다 한 번만 만든다. 고정 문구라 innerHTML 사용, 사용자 값은 아래에서 textContent/value로)
  const modal = document.createElement("div");
  modal.className = "modal";
  modal.id = "review-modal";
  modal.innerHTML = `
    <div class="card" role="dialog" aria-modal="true" aria-labelledby="rv-title">
      <div class="screen-id">S17 · 후기 팝업 (공용) · D</div>
      <h2 id="rv-title" style="margin-top:4px">후기 쓰기</h2>

      <div id="rv-theme-fixed" class="card small" style="background:#faf9f6"></div>
      <div id="rv-theme-pick">
        <label for="rv-theme">플레이한 테마</label>
        <select id="rv-theme">
          <option data-limit="70">사라진 기억 · 어둠상자 홍대점 (제한 70분)</option>
          <option data-limit="60">금고털이 · 미스터리룸 강남점 (제한 60분)</option>
        </select>
      </div>

      <label>별점</label>
      <div class="rating" id="rv-stars"></div>

      <label>결과</label>
      <div class="row small">
        <label class="row" style="margin:0;font-weight:400"><input type="radio" name="rv-esc" value="ok" checked style="width:auto"> 탈출 성공</label>
        <label class="row" style="margin:0;font-weight:400"><input type="radio" name="rv-esc" value="fail" style="width:auto"> 실패</label>
      </div>

      <div class="grid" style="grid-template-columns:1fr 1fr;gap:8px">
        <div><label for="rv-hint">사용한 힌트</label><input id="rv-hint" type="number" min="0" value="0"></div>
        <div><label for="rv-ppl">플레이 인원</label><input id="rv-ppl" type="number" min="1" value="2"></div>
      </div>

      <label>남은 시간 <span class="muted" style="font-weight:400">(탈출했을 때 타이머에 남아 있던 시간)</span></label>
      <div class="remain">
        <input id="rv-min" type="number" min="0" value="0" aria-label="분"><span>분</span>
        <input id="rv-sec" type="number" min="0" max="59" value="0" aria-label="초"><span>초</span>
        <span class="muted" id="rv-show"></span>
      </div>
      <p class="warn-line" id="rv-warn"></p>

      <label for="rv-text">한 줄 후기 (선택)</label>
      <textarea id="rv-text" placeholder="안 써도 별점만 남아요"></textarea>

      <div class="row" style="justify-content:flex-end;margin-top:10px">
        <button type="button" class="btn gray" data-rv-close>닫기</button>
        <button type="button" class="btn" id="rv-save">저장</button>
      </div>
    </div>`;
  document.body.append(modal);

  const $ = function (id) { return document.getElementById(id); };
  const pad = function (n) { return String(n).padStart(2, "0"); };
  let limit = 70;
  let rate = 4;

  // 별점: 눌러서 고르기
  const starsBox = $("rv-stars");
  function drawStars() {
    starsBox.textContent = "";
    for (let i = 1; i <= 5; i++) {
      const b = document.createElement("span");
      b.textContent = i <= rate ? "★" : "☆";
      b.style.cursor = "pointer";
      b.addEventListener("click", function () { rate = i; drawStars(); });
      starsBox.append(b);
    }
  }

  // 남은 시간 mm:ss 미리보기 + 검사
  function updateRemain() {
    const mm = Math.max(0, parseInt($("rv-min").value || "0", 10));
    const ss = Math.max(0, parseInt($("rv-sec").value || "0", 10));
    $("rv-show").textContent = "= " + pad(mm) + ":" + pad(ss) + " / " + limit + ":00";
    let w = "";
    if (ss > 59) w = "초는 0~59까지예요";
    else if (mm * 60 + ss > limit * 60) w = "제한 시간(" + limit + "분)보다 길 수 없어요";
    $("rv-warn").textContent = w;
    $("rv-save").disabled = w !== "";
  }
  $("rv-min").addEventListener("input", updateRemain);
  $("rv-sec").addEventListener("input", updateRemain);
  $("rv-theme").addEventListener("change", function () {
    limit = +this.selectedOptions[0].dataset.limit;
    updateRemain();
  });

  function open(btn) {
    const d = btn.dataset;
    const edit = d.review === "edit";
    $("rv-title").textContent = edit ? "후기 수정" : "후기 쓰기";

    if (d.theme) {
      $("rv-theme-fixed").hidden = false;
      $("rv-theme-pick").hidden = true;
      $("rv-theme-fixed").textContent = "🚪 " + d.theme + " (제한 " + (d.limit || 70) + "분)";
      limit = +(d.limit || 70);
    } else {
      $("rv-theme-fixed").hidden = true;
      $("rv-theme-pick").hidden = false;
      limit = +$("rv-theme").selectedOptions[0].dataset.limit;
    }

    rate = +(d.rate || 4);
    $("rv-hint").value = d.hint || 0;
    $("rv-ppl").value = d.ppl || 2;
    $("rv-min").value = d.min || 0;
    $("rv-sec").value = d.sec || 0;
    $("rv-text").value = d.text || "";
    modal.querySelector('input[name="rv-esc"][value="' + (d.fail ? "fail" : "ok") + '"]').checked = true;

    drawStars();
    updateRemain();
    modal.classList.add("open");
    $("rv-hint").focus();
  }
  function close() { modal.classList.remove("open"); }

  document.addEventListener("click", function (e) {
    const btn = e.target.closest("[data-review]");
    if (btn) { e.preventDefault(); open(btn); return; }
    if (e.target === modal || e.target.closest("[data-rv-close]")) close();
  });
  $("rv-save").addEventListener("click", function () {
    // 실제 서비스: 새로 쓰기 D-1 POST /api/reviews, 수정 D-2 PUT /api/reviews/{id}
    close();
  });
  document.addEventListener("keydown", function (e) { if (e.key === "Escape") close(); });
})();
