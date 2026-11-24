// ==UserScript==
// @name         Odak - Reels & Shorts Engelleyici
// @description  Instagram ve YouTube'da Reels, Shorts, Keşfet, öneriler ve reklamları gizler. Mola, odak ve uyku modları, günlük süre sayacı. Sağ kenardaki ⚙ ile ayarlanır.
// @version      2.2
// @match        *://*.instagram.com/*
// @match        *://*.youtube.com/*
// @run-at       document-start
// @inject-into  content
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const IG = location.hostname.endsWith('instagram.com');
  const YT = location.hostname.endsWith('youtube.com');
  if ((!IG && !YT) || window.top !== window) return;
  // Hem uygulama hem Safari eklentisi varsa iki kez çalışmasın
  if (document.documentElement.hasAttribute('data-odak')) return;
  document.documentElement.setAttribute('data-odak', '');

  // ===================== Ayarlar =====================
  // Her ayar "true" iken o şey gizlenir / engellenir.
  const OPTIONS = IG ? [
    { key: 'reels', label: "Reels'i gizle", hint: 'Reels sekmesi, akıştaki Reels ve videolar', def: true },
    { key: 'sentReel', label: 'Gönderilen Reels açılsın', hint: "DM'den gelen tek Reels'i izle, sonrakine geçemezsin", def: true },
    { key: 'explore', label: "Keşfet'i gizle", hint: 'Arama sayfasındaki ızgara (arama kutusu kalır)', def: true },
    { key: 'search', label: 'Arama çubuğunu gizle', hint: 'Hesap arama kutusu', def: false },
    { key: 'suggested', label: 'Önerilen gönderileri gizle', hint: 'Akışta takip etmediğin hesapların gönderileri', def: true },
    { key: 'ads', label: 'Reklamları gizle', hint: 'Sponsorlu gönderiler', def: true },
    { key: 'feed', label: 'Ana akışı tamamen gizle', hint: 'Hikayeler, DM ve profiller kalır', def: false },
  ] : [
    { key: 'shorts', label: "Shorts'u gizle", hint: 'Shorts sekmesi, rafları ve videoları', def: true },
    { key: 'sentShort', label: 'Paylaşılan Shorts açılsın', hint: 'Gelen Shorts linki normal video olarak açılır, kaydırma yok', def: true },
    { key: 'home', label: 'Ana sayfa önerilerini gizle', hint: 'Arama ve abonelikler kalır', def: false },
    { key: 'related', label: 'İzlerken önerileri gizle', hint: 'Videonun altındaki ve sonundaki öneriler', def: false },
    { key: 'ads', label: 'Reklamları gizle', hint: 'Reklam alanları; atlanabilir reklamı otomatik atlar', def: true },
    { key: 'noCaptions', label: 'Tam ekranda altyazı açılmasın', hint: 'İstersen oynatıcıdan elle açabilirsin', def: true },
  ];

  const STORE_KEY = 'odak-ayarlar';
  const MOLA_MIN = 10;
  const FOCUS_MIN = 60;

  const state = loadState();

  function loadState() {
    const s = {
      opts: {}, pauseUntil: 0, focusUntil: 0,
      sleepOn: false, sleepFrom: '23:00', sleepTo: '07:00',
      day: '', sec: 0,
    };
    OPTIONS.forEach((o) => { s.opts[o.key] = o.def; });
    try {
      const saved = JSON.parse(localStorage.getItem(STORE_KEY) || '{}');
      Object.assign(s.opts, saved.opts || {});
      ['pauseUntil', 'focusUntil', 'sleepOn', 'sleepFrom', 'sleepTo', 'day', 'sec']
        .forEach((k) => { if (k in saved) s[k] = saved[k]; });
    } catch (_) { /* bozuk kayıt: varsayılanlar */ }
    return s;
  }

  function saveState() {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); } catch (_) { /* yer yok */ }
  }

  const isPaused = () => state.pauseUntil > Date.now();
  // Mola sırasında tüm filtreler kapalı sayılır.
  const on = (key) => !isPaused() && !!state.opts[key];

  // ===================== Yardımcılar =====================
  const pad = (n) => String(n).padStart(2, '0');
  const clock = (ts) => { const d = new Date(ts); return `${pad(d.getHours())}:${pad(d.getMinutes())}`; };
  const toMin = (hhmm) => { const [h, m] = String(hhmm).split(':').map(Number); return (h || 0) * 60 + (m || 0); };
  const today = () => { const d = new Date(); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; };

  function duration(sec) {
    const m = Math.floor(sec / 60);
    return m >= 60 ? `${Math.floor(m / 60)} sa ${m % 60} dk` : `${m} dk`;
  }

  function el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    Object.entries(attrs || {}).forEach(([k, v]) => {
      if (k === 'class') node.className = v;
      else if (k === 'text') node.textContent = v;
      else node.setAttribute(k, v);
    });
    children.forEach((c) => { if (c) node.appendChild(c); });
    return node;
  }

  const HIDDEN_ATTR = 'data-odak-gizli';
  const AD_ATTR = 'data-odak-reklam';

  function mark(node, hide, attr = HIDDEN_ATTR) {
    if (hide) { if (!node.hasAttribute(attr)) node.setAttribute(attr, ''); }
    else if (node.hasAttribute(attr)) node.removeAttribute(attr);
  }

  function inSleep() {
    if (!state.sleepOn) return false;
    const d = new Date();
    const t = d.getHours() * 60 + d.getMinutes();
    const a = toMin(state.sleepFrom);
    const b = toMin(state.sleepTo);
    return a <= b ? (t >= a && t < b) : (t >= a || t < b);
  }

  function shieldReason() {
    if (state.focusUntil > Date.now()) return { title: 'Odak modu', text: `Bu site kilitli. Bitiş: ${clock(state.focusUntil)}` };
    if (inSleep()) return { title: 'Uyku modu', text: `Bu site kilitli. Bitiş: ${state.sleepTo}` };
    return null;
  }

  // ===================== Engellenen sayfalar =====================
  function isBlockedPath(path) {
    if (IG) {
      if (on('reels')) {
        // Reels akışı ve profil Reels sekmesi
        if (/^\/reels(?:\/|$)/.test(path) || /^\/[^/]+\/reels\/?$/.test(path)) return true;
        // Tek Reels (/reel/ID): sadece izin verilmişse açılır
        if (/^\/(?:[^/]+\/)?reel\/[^/]+/.test(path) && !on('sentReel')) return true;
      }
      if (on('search') && /^\/explore\/search(?:\/|$)/.test(path)) return true;
      if (on('search') && on('explore') && /^\/explore(?:\/|$)/.test(path)) return true;
      return false;
    }
    return on('shorts') && (/^\/shorts(?:\/|$)/.test(path) ||
      /^\/(?:@[^/]+|channel\/[^/]+|c\/[^/]+|user\/[^/]+)\/shorts\/?$/.test(path));
  }

  function redirectTarget(path) {
    if (YT && on('sentShort')) {
      const m = path.match(/^\/shorts\/([^/?#]+)/);
      if (m) return `/watch?v=${m[1]}`;
    }
    return '/';
  }

  // ===================== Gizleme kuralları =====================
  // Sadece hızlı seçiciler: :has() yok. Kapsayıcıları JavaScript işaretler.
  const HIDE = '{ display: none !important; }';

  const IG_SEARCH_INPUTS = ['placeholder^="Ara"', 'placeholder^="Search"', 'aria-label^="Ara"', 'aria-label^="Search"']
    .map((a) => `input[${a}]`).join(', ');

  const YT_SHORTS = [
    'ytm-reel-shelf-renderer',
    'ytm-shorts-lockup-view-model',
    'ytm-shorts-lockup-view-model-v2',
    'ytd-reel-shelf-renderer',
    'ytd-rich-shelf-renderer[is-shorts]',
    'ytd-mini-guide-entry-renderer[aria-label="Shorts"]',
    'yt-tab-shape[tab-title="Shorts"]',
    'a[href*="/shorts/"]',
  ];

  const YT_HOME = [
    'html.odak-home ytm-browse',
    'html.odak-home ytd-browse[page-subtype="home"] #primary',
  ];

  const YT_RELATED = [
    'ytm-item-section-renderer[section-identifier="related-items"]',
    'ytm-watch-next-secondary-results-renderer',
    'ytd-watch-next-secondary-results-renderer',
    '#related',
    '.ytp-endscreen-content',
    '.ytp-ce-element',
    '.videowall-endscreen',
  ];

  const YT_ADS = [
    'ad-slot-renderer',
    'ytm-promoted-sparkles-web-renderer',
    'ytm-promoted-video-renderer',
    'ytm-companion-ad-renderer',
    'ytm-companion-slot',
    'ytd-ad-slot-renderer',
    'ytd-in-feed-ad-layout-renderer',
    'ytd-promoted-sparkles-web-renderer',
    'ytd-banner-promo-renderer',
    'ytd-statement-banner-renderer',
    '#masthead-ad',
    '#player-ads',
    'ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"]',
  ];

  // Shorts bağlantısı içeren en dıştaki kutu (sıra önemli: raflar önce)
  const YT_SHORT_CONTAINERS = [
    'ytm-rich-section-renderer', 'ytd-rich-section-renderer', 'grid-shelf-view-model',
    'ytm-reel-shelf-renderer', 'ytd-reel-shelf-renderer',
    'ytm-rich-item-renderer', 'ytd-rich-item-renderer',
    'ytm-video-with-context-renderer', 'ytm-compact-video-renderer',
    'ytd-video-renderer', 'ytd-grid-video-renderer', 'ytd-compact-video-renderer',
  ];

  // Sınıf adları değişse bile "Shorts" yazan sekme/çipleri yakalamak için
  const YT_TEXT_TARGETS = [
    'ytm-pivot-bar-item-renderer', 'ytm-chip-cloud-chip-renderer', 'yt-chip-cloud-chip-renderer',
    'yt-tab-shape', '[role="tab"]', 'ytd-guide-entry-renderer', 'ytd-mini-guide-entry-renderer',
  ].join(',');

  function buildCss() {
    const rules = [`[${HIDDEN_ATTR}], [${AD_ATTR}] ${HIDE}`];
    if (IG) {
      if (on('reels')) {
        // DM'deki Reels bağlantıları sadece "Gönderilen Reels açılsın" açıkken görünür
        const reelLinks = on('sentReel') ? 'html:not(.odak-direct) a[href*="/reel/"]' : 'a[href*="/reel/"]';
        rules.push(`a[href*="/reels/"], ${reelLinks} ${HIDE}`);
      }
      if (on('explore')) {
        rules.push(`html.odak-explore main a[href*="/p/"], html.odak-explore main a[href*="/reel/"], html.odak-explore main video ${HIDE}`);
      }
      if (on('search')) rules.push(`${IG_SEARCH_INPUTS} ${HIDE}`);
      if (on('search') && on('explore')) rules.push(`a[href="/explore/"] ${HIDE}`);
      if (on('feed')) rules.push(`html.odak-home main article ${HIDE}`);
    }
    if (YT) {
      if (on('shorts')) rules.push(`${YT_SHORTS.join(', ')} ${HIDE}`);
      if (on('home')) rules.push(`${YT_HOME.join(', ')} ${HIDE}`);
      if (on('related')) rules.push(`${YT_RELATED.join(', ')} ${HIDE}`);
      if (on('ads')) rules.push(`${YT_ADS.join(', ')} ${HIDE}`);
    }
    return rules.join('\n');
  }

  function syncPathClasses(path) {
    const root = document.documentElement;
    root.classList.toggle('odak-home', path === '/');
    if (IG) {
      root.classList.toggle('odak-explore', /^\/explore\/?$/.test(path));
      root.classList.toggle('odak-direct', /^\/direct(?:\/|$)/.test(path));
    }
  }

  // ---- Instagram: Reels, reklam ve önerilen gönderileri tanı ----
  const AD_WORDS = new Set(['Sponsorlu', 'Sponsored']);
  const FOLLOW_WORDS = new Set(['Takip Et', 'Follow']);
  let igChecked = new WeakMap(); // gönderi -> son kontrol zamanı

  function hasLeafText(root, selector, words) {
    for (const n of root.querySelectorAll(selector)) {
      if (n.childElementCount === 0 && words.has(n.textContent.trim())) return true;
    }
    return false;
  }

  function shouldHideArticle(art) {
    if (on('reels') && art.querySelector('a[href*="/reel/"], video')) return true;
    const text = art.textContent;
    if (on('ads') && (text.includes('Sponsorlu') || text.includes('Sponsored')) &&
      hasLeafText(art, 'span, a', AD_WORDS)) return true;
    // Takip etmediğin hesabın gönderisinde "Takip Et" düğmesi olur
    if (on('suggested') && (text.includes('Takip Et') || text.includes('Follow')) &&
      [...art.querySelectorAll('button, [role="button"]')].some((b) => FOLLOW_WORDS.has(b.textContent.trim()))) return true;
    return false;
  }

  function sweepInstagram() {
    if (location.pathname === '/') {
      const now = Date.now();
      document.querySelectorAll('article').forEach((art) => {
        if (art.hasAttribute(HIDDEN_ATTR)) return;
        if (now - (igChecked.get(art) || 0) < 800) return; // aynı gönderiyi sık sık tarama
        igChecked.set(art, now);
        if (shouldHideArticle(art)) mark(art, true);
      });
    }
    if (on('search')) {
      document.querySelectorAll(IG_SEARCH_INPUTS).forEach((input) => {
        if (input.parentElement) mark(input.parentElement, true);
      });
    }
  }

  // ---- YouTube ----
  function shortContainer(link) {
    for (const sel of YT_SHORT_CONTAINERS) {
      const c = link.closest(sel);
      if (c) return c;
    }
    return null;
  }

  function sweepYouTube() {
    const shorts = on('shorts');
    if (shorts) {
      document.querySelectorAll('a[href*="/shorts/"]').forEach((a) => {
        const c = shortContainer(a);
        if (c) mark(c, true);
      });
    }
    // YouTube kutuları yeniden kullanır: artık Shorts içermeyen kutuyu geri göster
    document.querySelectorAll(`[${HIDDEN_ATTR}]`).forEach((n) => {
      if (n.matches(YT_TEXT_TARGETS)) return;
      if (!shorts || !n.querySelector('a[href*="/shorts/"], ytm-shorts-lockup-view-model, ytm-shorts-lockup-view-model-v2')) mark(n, false);
    });
    document.querySelectorAll(YT_TEXT_TARGETS).forEach((n) => {
      mark(n, shorts && n.textContent.trim() === 'Shorts');
    });

    const ads = on('ads');
    if (ads) {
      document.querySelectorAll('ad-slot-renderer, ytd-ad-slot-renderer').forEach((ad) => {
        mark(ad.closest('ytm-rich-item-renderer, ytd-rich-item-renderer') || ad, true, AD_ATTR);
      });
      const skip = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
      if (skip) skip.click();
    }
    document.querySelectorAll(`[${AD_ATTR}]`).forEach((n) => {
      const stillAd = n.matches('ad-slot-renderer, ytd-ad-slot-renderer') ||
        n.querySelector('ad-slot-renderer, ytd-ad-slot-renderer');
      if (!ads || !stillAd) mark(n, false, AD_ATTR);
    });
  }

  function resetMarks() {
    document.querySelectorAll(`[${HIDDEN_ATTR}], [${AD_ATTR}]`).forEach((n) => {
      n.removeAttribute(HIDDEN_ATTR);
      n.removeAttribute(AD_ATTR);
    });
    igChecked = new WeakMap();
  }

  // ===================== Menü ve kilit ekranı =====================
  const UI_CSS = `
    * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    .tab { position: fixed; right: 0; top: 42%; width: 30px; height: 44px; padding: 0; border: 0;
      border-radius: 10px 0 0 10px; background: rgba(0,0,0,.5); color: #fff; font-size: 18px; opacity: .75; }
    .tab.paused { background: #f59e0b; opacity: 1; }
    .sheet { position: fixed; inset: 0; display: none; align-items: flex-end; justify-content: center; background: rgba(0,0,0,.45); }
    .sheet.open { display: flex; }
    .card { width: 100%; max-width: 480px; max-height: 85vh; overflow-y: auto; -webkit-overflow-scrolling: touch;
      background: #fff; color: #111; border-radius: 16px 16px 0 0; font-size: 15px;
      padding: 14px 16px calc(18px + env(safe-area-inset-bottom)); }
    .head { display: flex; align-items: center; justify-content: space-between; }
    .head b { font-size: 18px; }
    .close { border: 0; background: transparent; color: inherit; font-size: 20px; padding: 4px 8px; }
    .stat { color: #777; font-size: 13px; margin: 2px 0 8px; }
    .notice { display: none; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 8px;
      padding: 8px 10px; border-radius: 10px; background: #fff4e0; color: #8a5300; font-size: 13px; }
    .notice.show { display: flex; }
    .notice button { border: 0; border-radius: 8px; padding: 6px 10px; background: #8a5300; color: #fff; font-size: 13px; }
    h4 { margin: 14px 0 2px; font-size: 12px; letter-spacing: .04em; text-transform: uppercase; color: #888; }
    .row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 0;
      border-bottom: 1px solid rgba(0,0,0,.08); }
    .text { display: flex; flex-direction: column; gap: 2px; }
    .hint { font-size: 12px; color: #888; }
    input[type=checkbox] { appearance: none; -webkit-appearance: none; flex: none; position: relative; margin: 0;
      width: 46px; height: 28px; border-radius: 14px; background: #ccc; transition: background .2s; }
    input[type=checkbox]::after { content: ''; position: absolute; top: 3px; left: 3px; width: 22px; height: 22px;
      border-radius: 50%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.3); transition: left .2s; }
    input[type=checkbox]:checked { background: #34c759; }
    input[type=checkbox]:checked::after { left: 21px; }
    .times { display: flex; align-items: center; gap: 8px; padding: 8px 0 4px; font-size: 14px; }
    .times input { font-size: 15px; padding: 6px; border: 1px solid #ccc; border-radius: 8px; background: transparent; color: inherit; }
    .btn { display: block; width: 100%; margin-top: 8px; padding: 11px 12px; border: 0; border-radius: 10px;
      background: #f0f0f0; color: inherit; font-size: 15px; text-align: left; }
    .btn small { display: block; margin-top: 2px; font-size: 12px; color: #888; }
    .foot { margin-top: 12px; font-size: 12px; color: #999; }
    .shield { position: fixed; inset: 0; display: none; flex-direction: column; align-items: center; justify-content: center;
      gap: 10px; padding: 24px; background: #0f1115; color: #fff; text-align: center; }
    .shield.open { display: flex; }
    .shield b { font-size: 26px; }
    .shield p { margin: 0; max-width: 320px; color: #b8bcc6; font-size: 16px; }
    @media (prefers-color-scheme: dark) {
      .card { background: #1c1c1e; color: #f2f2f2; }
      .row { border-color: rgba(255,255,255,.1); }
      .btn { background: #2c2c2e; }
      .times input { border-color: #444; }
      .notice { background: #3a2a10; color: #ffcc80; }
    }
  `;

  let ui = null;

  function switchRow(label, hint, checked, onChange) {
    const box = el('input', { type: 'checkbox' });
    box.checked = checked;
    box.addEventListener('change', () => onChange(box.checked, box));
    return el('label', { class: 'row' },
      el('span', { class: 'text' }, el('span', { text: label }), hint ? el('span', { class: 'hint', text: hint }) : null),
      box);
  }

  function actionButton(label, hint, onClick) {
    const b = el('button', { class: 'btn' }, el('span', { text: label }), hint ? el('small', { text: hint }) : null);
    b.addEventListener('click', onClick);
    return b;
  }

  function buildUI() {
    const host = el('div', { id: 'odak-ui', style: 'all: initial; position: fixed; top: 0; left: 0; width: 0; height: 0; z-index: 2147483647;' });
    const root = host.attachShadow({ mode: 'open' });
    root.appendChild(el('style', { text: UI_CSS }));

    const tab = el('button', { class: 'tab', 'aria-label': 'Odak ayarları', text: '⚙' });
    const close = el('button', { class: 'close', 'aria-label': 'Kapat', text: '✕' });
    const stat = el('div', { class: 'stat' });
    const noticeText = el('span');
    const endPause = el('button', { text: 'Bitir' });
    const notice = el('div', { class: 'notice' }, noticeText, endPause);

    // lang="tr": büyük harfte "GİZLENENLER" doğru yazılsın
    const card = el('div', { class: 'card', lang: 'tr' },
      el('div', { class: 'head' }, el('b', { text: 'Odak' }), close),
      stat, notice,
      el('h4', { text: 'Gizlenenler' }));

    OPTIONS.forEach((o) => {
      card.appendChild(switchRow(o.label, o.hint, !!state.opts[o.key], (v) => {
        state.opts[o.key] = v;
        saveState();
        applySettings();
      }));
    });

    card.appendChild(el('h4', { text: 'Modlar' }));
    card.appendChild(actionButton(`${MOLA_MIN} dk mola`, 'Paylaşım yapmak için tüm filtreleri geçici olarak kapatır', () => {
      state.pauseUntil = Date.now() + MOLA_MIN * 60 * 1000;
      saveState();
      applySettings();
    }));
    card.appendChild(actionButton(`Odak modu: ${FOCUS_MIN} dk kilitle`, 'Bu site tamamen kilitlenir, erken açılmaz', () => {
      if (!confirm(`Bu site ${FOCUS_MIN} dakika kilitlenecek ve kilit erken açılmayacak. Başlatılsın mı?`)) return;
      state.focusUntil = Date.now() + FOCUS_MIN * 60 * 1000;
      saveState();
      openSheet(false);
      syncShield();
    }));

    const from = el('input', { type: 'time' });
    const to = el('input', { type: 'time' });
    from.value = state.sleepFrom;
    to.value = state.sleepTo;
    from.addEventListener('change', () => { if (from.value) { state.sleepFrom = from.value; saveState(); } });
    to.addEventListener('change', () => { if (to.value) { state.sleepTo = to.value; saveState(); } });
    card.appendChild(switchRow('Uyku modu', 'Bu saatler arasında site kilitlenir', state.sleepOn, (v, box) => {
      if (v && !confirm(`Uyku modu açılıyor: ${state.sleepFrom} - ${state.sleepTo} arası bu site kilitlenecek. Kilitliyken ayar değiştirilemez. Onaylıyor musun?`)) {
        box.checked = false;
        return;
      }
      state.sleepOn = v;
      saveState();
      syncShield();
    }));
    card.appendChild(el('div', { class: 'times' }, el('span', { text: 'Başlangıç' }), from, el('span', { text: 'Bitiş' }), to));

    if (YT) {
      card.appendChild(el('h4', { text: 'Video' }));
      card.appendChild(actionButton('Videoyu PiP penceresinde aç', 'Başka uygulamaya geçince de izlemeye/dinlemeye devam et', openPip));
    }

    card.appendChild(el('div', { class: 'foot', text: 'Ayarlar sadece bu sitede geçerli.' }));

    const sheet = el('div', { class: 'sheet' }, card);
    const shieldTitle = el('b');
    const shieldText = el('p');
    const shield = el('div', { class: 'shield' }, shieldTitle, shieldText);

    tab.addEventListener('click', () => openSheet(true));
    close.addEventListener('click', () => openSheet(false));
    sheet.addEventListener('click', (e) => { if (e.target === sheet) openSheet(false); });
    endPause.addEventListener('click', () => { state.pauseUntil = 0; saveState(); applySettings(); });

    root.append(tab, sheet, shield);
    ui = { host, tab, sheet, stat, notice, noticeText, shield, shieldTitle, shieldText };
  }

  function openSheet(open) {
    ui.sheet.classList.toggle('open', open);
    if (open) refreshPanel();
  }

  function refreshPanel() {
    if (!ui) return;
    const paused = isPaused();
    ui.tab.classList.toggle('paused', paused);
    if (!ui.sheet.classList.contains('open')) return;
    ui.stat.textContent = `Bugün burada: ${duration(state.day === today() ? state.sec : 0)}`;
    ui.notice.classList.toggle('show', paused);
    if (paused) ui.noticeText.textContent = `Mola: filtreler kapalı. Bitiş: ${clock(state.pauseUntil)}`;
  }

  function ensureUI() {
    if (!document.body) return;
    if (!ui) { buildUI(); syncShield(); }
    if (!ui.host.isConnected) document.body.appendChild(ui.host);
  }

  function syncShield() {
    if (!ui) return;
    const reason = shieldReason();
    ui.shield.classList.toggle('open', !!reason);
    if (!reason) return;
    ui.sheet.classList.remove('open');
    ui.shieldTitle.textContent = reason.title;
    ui.shieldText.textContent = reason.text;
    document.querySelectorAll('video').forEach((v) => { try { v.pause(); } catch (_) { /* yok */ } });
  }

  function openPip() {
    const videos = [...document.querySelectorAll('video')];
    const v = videos.find((x) => x.readyState > 0) || videos[0];
    if (!v) { alert('Önce bir video aç.'); return; }
    try {
      v.removeAttribute('disablepictureinpicture');
      v.disablePictureInPicture = false;
      if (v.webkitSupportsPresentationMode && v.webkitSupportsPresentationMode('picture-in-picture')) {
        v.webkitSetPresentationMode('picture-in-picture');
      } else if (v.requestPictureInPicture) {
        v.requestPictureInPicture();
      }
      openSheet(false);
    } catch (e) {
      alert(`PiP açılamadı: ${e.message}`);
    }
  }

  // ===================== Motor =====================
  // Sayfa sadece değiştiğinde taranır (MutationObserver), sürekli tarama yok.
  let styleEl = null;
  let version = '';
  let redirecting = false;
  let lastHref = '';
  let sweepTimer = 0;

  const settingsVersion = () => `${JSON.stringify(state.opts)}|${isPaused()}`;

  function ensureStyle() {
    if (!styleEl) {
      styleEl = document.createElement('style');
      styleEl.id = 'odak-style';
    }
    if (!styleEl.isConnected) (document.head || document.documentElement).appendChild(styleEl);
  }

  // Ayar veya mola durumu değiştiyse kuralları yeniden kur
  function applySettings(force) {
    const v = settingsVersion();
    if (!force && v === version) return;
    version = v;
    ensureStyle();
    styleEl.textContent = buildCss();
    resetMarks();
    route();
    refreshPanel();
  }

  let lastPath = location.pathname;

  function route() {
    if (redirecting) return;
    lastHref = location.href;
    const path = location.pathname;
    if (isBlockedPath(path)) {
      redirecting = true;
      location.replace(redirectTarget(path));
      return;
    }
    notifyApp(lastPath, path);
    lastPath = path;
    syncPathClasses(path);
    scheduleSweep();
  }

  // ---- Uygulamayla haberleşme (sadece Odak uygulamasında; Safari'de sessizce atlanır) ----
  // Videodan çıkınca uygulama videoyu alttaki mini oynatıcıda sürdürür.
  const appBridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.odak;
  let lastWatch = null;

  function trackWatch() {
    if (!YT || !appBridge || location.pathname !== '/watch') return;
    const v = document.querySelector('video.html5-main-video') || document.querySelector('video');
    const id = new URLSearchParams(location.search).get('v');
    if (!v || !id) return;
    lastWatch = {
      id,
      time: v.currentTime || 0,
      playing: !v.paused && !v.ended,
      ended: v.ended,
      title: document.title.replace(/\s*-\s*YouTube\s*$/, ''),
    };
  }

  function notifyApp(prevPath, path) {
    if (!YT || !appBridge) return;
    try {
      if (path === '/watch') {
        appBridge.postMessage({ type: 'watch' });
      } else if (prevPath === '/watch' && lastWatch && !lastWatch.ended && lastWatch.time > 1) {
        appBridge.postMessage({ type: 'mini', ...lastWatch });
        lastWatch = null;
      }
    } catch (_) { /* uygulama dışında */ }
  }

  function scheduleSweep() {
    if (sweepTimer) return;
    sweepTimer = setTimeout(() => { sweepTimer = 0; sweep(); }, 120);
  }

  function sweep() {
    ensureStyle();
    if (!document.body) return;
    ensureUI();
    if (IG) sweepInstagram();
    else sweepYouTube();
  }

  // Günlük süre sayacı (sekme görünürken ve kilitli değilken)
  function countUsage() {
    if (document.visibilityState !== 'visible' || shieldReason()) return;
    const d = today();
    if (state.day !== d) { state.day = d; state.sec = 0; }
    state.sec += 1;
    if (state.sec % 5 === 0) saveState();
  }

  // Engellenen bir bağlantıya dokunulursa hiç açılmasın
  document.addEventListener('click', (e) => {
    const a = e.target instanceof Element && e.target.closest('a[href]');
    if (!a) return;
    let url;
    try { url = new URL(a.href, location.href); } catch (_) { return; }
    if (url.hostname !== location.hostname || !isBlockedPath(url.pathname)) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    const target = redirectTarget(url.pathname);
    if (target !== '/') location.assign(target);
  }, true);

  // iOS, video dili telefon dilinden farklıysa tam ekranda altyazıyı kendiliğinden açar.
  // Tam ekrana geçerken altyazıyı kapat; sonradan oynatıcıdan elle açılabilir.
  function captionsOff(video) {
    for (const track of video.textTracks) {
      if (track.kind === 'subtitles' || track.kind === 'captions') track.mode = 'disabled';
    }
  }

  if (YT) {
    document.addEventListener('webkitbeginfullscreen', (e) => {
      const video = e.target;
      if (!on('noCaptions') || !(video instanceof HTMLVideoElement)) return;
      [0, 300, 1000].forEach((ms) => setTimeout(() => captionsOff(video), ms));
      const onAddTrack = () => captionsOff(video);
      video.textTracks.addEventListener('addtrack', onAddTrack);
      video.addEventListener('webkitendfullscreen', () => {
        video.textTracks.removeEventListener('addtrack', onAddTrack);
      }, { once: true });
    }, true);
  }

  applySettings(true);
  new MutationObserver(scheduleSweep).observe(document.documentElement, { childList: true, subtree: true });
  // Site sayfa yenilemeden gezinir: adres değişimini ucuz bir kontrolle yakala
  setInterval(() => {
    trackWatch(); // videodan çıkmadan hemen önceki konumu bilmek için
    if (location.href !== lastHref) route();
  }, 250);
  setInterval(() => {
    applySettings(false); // mola bittiyse filtreleri geri aç
    syncShield();
    countUsage();
    refreshPanel();
  }, 1000);
  window.addEventListener('pagehide', saveState);
})();
