// 회원가입 공통 (손님·사장 가입 화면이 같이 씀)
// 비밀번호 확인: 두 칸이 같은지 입력할 때마다 검사 (목업용 간단 버전)
(function () {
  const pw = document.getElementById("pw");
  const pw2 = document.getElementById("pw2");
  const msg = document.getElementById("pw-msg");
  if (!pw || !pw2 || !msg) return;
  function check() {
    if (pw2.value === "") {
      msg.className = "badge";
      msg.textContent = "비밀번호를 한 번 더 입력해 주세요";
    } else if (pw.value === pw2.value) {
      msg.className = "badge ok";
      msg.textContent = "비밀번호가 같아요";
    } else {
      msg.className = "badge bad";
      msg.textContent = "비밀번호가 달라요";
    }
  }
  pw.addEventListener("input", check);
  pw2.addEventListener("input", check);
})();
