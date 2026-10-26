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
  new MutationObserver(sync).observe(result, { childList: true, subtree: false });
  sync();
})();
