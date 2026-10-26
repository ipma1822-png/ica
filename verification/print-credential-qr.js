/* ICA print-only credential QR. No database writes or personal data in QR. */
(() => {
  'use strict';
  const result = document.getElementById('result');
  if (!result) return;
  function sync() {
    const card = result.querySelector('.credential-card');
    if (!card || card.querySelector('.ica-print-qr')) return;
    const number = card.querySelector('.record-no')?.textContent?.trim();
    if (!number || typeof QRCode !== 'function') return;
    const url = new URL('https://ipma1822-png.github.io/ica/verification/');
    url.searchParams.set('code', number);
    url.searchParams.set('lang', document.documentElement.lang === 'en' ? 'en' : 'ko');
    const wrap = document.createElement('div');
    wrap.className = 'ica-print-qr';
    wrap.setAttribute('aria-label', 'ICA official verification QR');
    const qr = document.createElement('div');
    qr.className = 'ica-print-qr-image';
    const caption = document.createElement('small');
    caption.textContent = 'SCAN TO VERIFY · ICA';
    wrap.append(qr, caption);
    card.querySelector('.official-seal')?.after(wrap);
    if (!wrap.isConnected) return;
    try {
      new QRCode(qr, { text: url.href, width: 160, height: 160, correctLevel: QRCode.CorrectLevel.M });
    } catch (_) { wrap.remove(); }
  }

  window.downloadCredentialQr = function(no) {
    const card = [...result.querySelectorAll('.credential-card')].find(el => el.querySelector('.record-no')?.textContent?.trim() === String(no).trim());
    if (!card) return;
    sync();
    const qr = card.querySelector('.ica-print-qr-image');
    const canvas = qr?.querySelector('canvas');
    const img = qr?.querySelector('img');
    if (!canvas && !img) { alert('QR코드를 생성하지 못했습니다. 다시 시도해 주세요.'); return; }
    const out = document.createElement('canvas');
    out.width = out.height = 1080;
    const ctx = out.getContext('2d');
    ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, 1080, 1080);
    ctx.imageSmoothingEnabled = false;
    try {
      ctx.drawImage(canvas || img, 40, 40, 1000, 1000);
      const a = document.createElement('a');
      a.download = 'ICA-QR-' + String(no).replace(/[^a-zA-Z0-9_-]/g, '_') + '.png';
      a.href = out.toDataURL('image/png');
      a.click();
    } catch (_) { alert('QR 다운로드에 실패했습니다. 다시 시도해 주세요.'); }
  };
  new MutationObserver(sync).observe(result, { childList: true, subtree: false });
  sync();
})();
