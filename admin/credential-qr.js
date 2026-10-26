/* ICA QR generation is local-only. No record writes or external QR requests. */
(() => {
  'use strict';
  let activeNo = '';
  const panel = document.createElement('section');
  panel.className = 'credential-qr hidden';
  panel.setAttribute('aria-label', '자격증 QR코드');
  panel.innerHTML = '<h3>ICA 공식 조회 QR코드</h3><p class="qr-number"></p><label>조회 언어 <select class="qr-language"><option value="ko">한국어</option><option value="en">English</option></select></label><div class="qr-preview"></div><p class="qr-message" role="status"></p><div class="actions"><button type="button" class="qr-download">QR PNG 다운로드</button><a class="qr-link" target="_blank" rel="noopener">공개조회 확인 ↗</a><button type="button" class="qr-close">닫기</button></div><small>등록번호와 공식 조회 주소만 포함합니다. 인쇄 시 여백을 유지하고 30mm 이상을 권장합니다. 유효 여부는 조회 화면의 현재 상태를 확인하세요.</small>';
  document.getElementById('appView').append(panel);
  const preview = panel.querySelector('.qr-preview');
  const language = panel.querySelector('.qr-language');
  const download = panel.querySelector('.qr-download');
  const message = panel.querySelector('.qr-message');
  let png = null;
  function render() {
    png = null; download.disabled = true; preview.replaceChildren(); message.textContent = '';
    try {
      const url = new URL(ICA_CONFIG.verificationUrl);
      url.searchParams.set('code', activeNo);
      url.searchParams.set('lang', language.value);
      panel.querySelector('.qr-link').href = url.href;
      panel.querySelector('.qr-number').textContent = activeNo;
      const encoder = new QRCode(document.createElement('div'), {text: url.href, width: 256, height: 256, correctLevel: QRCode.CorrectLevel.M});
      const matrix = encoder._oQRCode, count = matrix.getModuleCount();
      const scale = Math.ceil(1024 / (count + 8)), side = (count + 8) * scale;
      png = document.createElement('canvas'); png.width = png.height = side;
      const ctx = png.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, side, side); ctx.fillStyle = '#000';
      for (let r = 0; r < count; r++) for (let c = 0; c < count; c++) if (matrix.isDark(r, c)) ctx.fillRect((c + 4) * scale, (r + 4) * scale, scale, scale);
      png.setAttribute('aria-label', 'ICA 공식 조회 QR코드');
      preview.append(png); download.disabled = false;
      message.textContent = `${side} × ${side}px · PNG · 무료 자체 생성`;
    } catch (error) { png = null; message.textContent = 'QR 생성에 실패했습니다. 페이지를 새로고침해 주세요.'; }
  }
  function open(no, anchor) {
    if (document.getElementById('appView').classList.contains('hidden')) return;
    activeNo = String(no || '').trim(); if (!activeNo) return;
    anchor.after(panel); panel.classList.remove('hidden'); render(); panel.scrollIntoView({behavior: 'smooth', block: 'nearest'});
  }
  window.openCredentialQr = no => open(no, document.getElementById('issueMsg'));
  language.addEventListener('change', render);
  panel.querySelector('.qr-close').onclick = () => panel.classList.add('hidden');
  download.onclick = () => {
    if (!png) return;
    const a = document.createElement('a');
    a.download = `ICA-QR-${activeNo.replace(/[^a-zA-Z0-9_-]/g, '_')}-${language.value}.png`;
    a.href = png.toDataURL('image/png'); a.click();
  };
  document.getElementById('registryList').addEventListener('click', event => {
    const button = event.target.closest('[data-credential-qr]');
    if (button) open(button.dataset.credentialQr, button.closest('article'));
  });
})();
