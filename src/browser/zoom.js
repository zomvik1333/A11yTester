/* Module 1. Zoom, reflow and text spacing checks. */
(function () {
  var A = window.__a11y;
  var SCROLL_OK = 'table,[role=grid],[role=table],[role=treegrid],pre,code,canvas,svg,video,iframe,map,[role=img],[data-a11y-allow-scroll]';

  A.zoomBaseline = function () {
    A.base = [];
    A.textElements().forEach(function (el) {
      if (!A.visible(el)) return;
      var r = A.textRect(el);
      if (!r) return;
      if (r.right + window.scrollX <= 0 || r.bottom + window.scrollY <= 0) return;
      A.base.push({ el: el, text: A.short(el.innerText || el.textContent, 70) });
    });
    return A.base.length;
  };

  function containedByScroller(el, vw) {
    var a = el.parentElement;
    while (a && a !== document.body && a !== document.documentElement) {
      var s = getComputedStyle(a);
      if (s.overflowX !== 'visible') {
        var r = a.getBoundingClientRect();
        if (r.right <= vw + 4) return true;
      }
      a = a.parentElement;
    }
    return false;
  }

  function horizontalScroll(F) {
    var vw = document.documentElement.clientWidth;
    var sw = Math.max(document.documentElement.scrollWidth, document.body ? document.body.scrollWidth : 0);
    if (sw <= vw + 4) return;
    var offenders = [];
    var all = document.body.getElementsByTagName('*');
    for (var i = 0; i < all.length && offenders.length < 12; i++) {
      var el = all[i];
      if (A.isOurs(el)) continue;
      var r = el.getBoundingClientRect();
      if (r.width < 1 || r.height < 1) continue;
      if (r.right + window.scrollX <= vw + 4) continue;
      var s = getComputedStyle(el);
      if (s.position === 'fixed') continue;
      var p = el.parentElement;
      var pr = p ? p.getBoundingClientRect() : null;
      if (p && p !== document.body && pr.right + window.scrollX > vw + 4) continue;
      if (containedByScroller(el, vw)) continue;
      offenders.push(el);
    }
    var allowed = offenders.length > 0 && offenders.every(function (el) { return el.matches(SCROLL_OK) || el.closest(SCROLL_OK) || el.querySelector(SCROLL_OK); });
    var names = offenders.slice(0, 3).map(A.describe).join(', ');
    F.push(A.finding(allowed ? 'zoom-reflow-table' : 'zoom-reflow', allowed ? 'Low' : 'High', allowed ? 'check' : 'confirmed',
      { width: Math.round(sw), items: names || 'the page itself' }, offenders.slice(0, 3),
      offenders.length ? 'Widest items ' + offenders.slice(0, 3).map(A.selector).join(' ; ') + '. Page is ' + Math.round(sw) + 'px wide at a 320px viewport.' : 'html or body has a fixed min-width.'));
  }

  function clipped(F, rule, max) {
    var found = 0, seenBox = new Set();
    var els = A.textElements();
    for (var i = 0; i < els.length && found < max; i++) {
      var el = els[i];
      if (!A.visible(el)) continue;
      var tr = A.textRect(el);
      if (!tr) continue;
      var s = getComputedStyle(el);
      if (s.textOverflow === 'ellipsis' && s.overflowX !== 'visible' && el.scrollWidth > el.clientWidth + 1) {
        F.push(A.finding(rule, 'Medium', 'confirmed', { text: A.short(el.innerText, 50), how: 'shortened with dots, so the end of it is hidden' }, el, A.selector(el) + ' uses text-overflow ellipsis'));
        found++; continue;
      }
      var a = el, depth = 0;
      while (a && a !== document.body && depth < 6) {
        var as = getComputedStyle(a);
        var hx = as.overflowX === 'hidden' || as.overflowX === 'clip';
        var hy = as.overflowY === 'hidden' || as.overflowY === 'clip';
        if (hx || hy) {
          var ar = a.getBoundingClientRect();
          if (ar.width > 4 && ar.height > 4) {
            var cutX = hx && (tr.right > ar.right + 2 || tr.left < ar.left - 2);
            var cutY = hy && (tr.bottom > ar.bottom + 2 || tr.top < ar.top - 2);
            if ((cutX || cutY) && !seenBox.has(a) && !a.closest('[aria-hidden=true]')) {
              seenBox.add(a);
              F.push(A.finding(rule, 'High', 'confirmed', { text: A.short(el.innerText, 50), how: 'cut off' }, a,
                A.selector(a) + ' has overflow hidden with a fixed ' + (cutY ? 'height' : 'width') + '. Let it grow with its content.'));
              found++;
            }
          }
          break;
        }
        a = a.parentElement; depth++;
      }
    }
  }

  function clipBox(node, cache) {
    if (!node || node === document.documentElement || node === document.body) return null;
    if (cache.has(node)) return cache.get(node);
    var box = clipBox(node.parentElement, cache);
    var s = getComputedStyle(node);
    if (s.overflowX !== 'visible' || s.overflowY !== 'visible') {
      var r = node.getBoundingClientRect();
      var own = { l: s.overflowX !== 'visible' ? r.left : -1e9, t: s.overflowY !== 'visible' ? r.top : -1e9, r: s.overflowX !== 'visible' ? r.right : 1e9, b: s.overflowY !== 'visible' ? r.bottom : 1e9 };
      box = box ? { l: Math.max(box.l, own.l), t: Math.max(box.t, own.t), r: Math.min(box.r, own.r), b: Math.min(box.b, own.b) } : own;
    }
    cache.set(node, box);
    return box;
  }

  function overlaps(F, rule, max) {
    var items = [];
    var vh = window.innerHeight;
    var cache = new Map();
    A.textElements().forEach(function (el) {
      if (items.length > 2500 || !A.visible(el)) return;
      var cb = clipBox(el, cache);
      A.textLineRects(el).forEach(function (r) {
        var l = r.left, t = r.top, rr = r.right, b = r.bottom;
        if (cb) { l = Math.max(l, cb.l); t = Math.max(t, cb.t); rr = Math.min(rr, cb.r); b = Math.min(b, cb.b); }
        if (rr - l < 2 || b - t < 2) return;
        if (b < -vh || t > vh * 4) return;
        items.push({ el: el, l: l, t: t, r: rr, b: b });
      });
    });
    items.sort(function (a, b) { return a.t - b.t; });
    var hits = [], pairs = new Set();
    for (var i = 0; i < items.length && hits.length < max; i++) {
      var a = items[i];
      for (var j = i + 1; j < items.length; j++) {
        var b = items[j];
        if (b.t >= a.b) break;
        if (a.el === b.el || a.el.contains(b.el) || b.el.contains(a.el)) continue;
        var x = Math.min(a.r, b.r) - Math.max(a.l, b.l);
        var y = Math.min(a.b, b.b) - Math.max(a.t, b.t);
        if (x <= 3 || y <= 3) continue;
        var sa = (a.r - a.l) * (a.b - a.t), sb = (b.r - b.l) * (b.b - b.t);
        if (x * y < 0.25 * Math.min(sa, sb)) continue;
        var key = A.sig(a.el) + '~' + A.sig(b.el);
        if (pairs.has(key)) continue;
        pairs.add(key);
        hits.push([a.el, b.el]);
        if (hits.length >= max) break;
      }
    }
    hits.forEach(function (h) {
      F.push(A.finding(rule, 'Medium', 'confirmed', { text: A.short(h[0].innerText, 40), other: A.short(h[1].innerText, 40) }, h,
        A.selector(h[0]) + ' overlaps ' + A.selector(h[1])));
    });
  }

  function lostContent(F) {
    if (!A.base) return;
    var vw = document.documentElement.clientWidth;
    var sw = Math.max(document.documentElement.scrollWidth, vw);
    var lost = [];
    A.base.forEach(function (b) {
      if (lost.length >= 4) return;
      var el = b.el;
      if (!el.isConnected) return;
      if (A.visible(el)) {
        var r = A.textRect(el);
        if (r && (r.right + window.scrollX < 0 || r.left + window.scrollX > sw)) lost.push(b);
        return;
      }
      if (el.closest('nav,[role=navigation],header,[role=banner],[role=menu],[role=menubar],aside,[role=dialog],details,[role=tabpanel]')) return;
      lost.push(b);
    });
    lost.forEach(function (b) {
      F.push(A.finding('zoom-lost', 'Medium', 'check', { text: b.text }, [], A.selector(b.el) + ' is hidden or off screen at a 320px viewport.'));
    });
  }

  A.zoomCheck = function (mode) {
    var F = [];
    if (mode === 'reflow') {
      horizontalScroll(F);
      clipped(F, 'zoom-clip-400', 4);
      overlaps(F, 'zoom-overlap-400', 3);
      lostContent(F);
    } else if (mode === 'resize') {
      clipped(F, 'zoom-clip-200', 4);
      overlaps(F, 'zoom-overlap-200', 3);
    } else if (mode === 'spacing') {
      clipped(F, 'spacing-clip', 4);
      overlaps(F, 'spacing-overlap', 3);
    }
    return F;
  };

  A.spacingOn = function () {
    var s = document.getElementById('__a11y_style');
    if (!s) { s = document.createElement('style'); s.id = '__a11y_style'; (document.head || document.documentElement).appendChild(s); }
    s.textContent = '*:not([data-a11y-overlay]){line-height:1.5 !important;letter-spacing:0.12em !important;word-spacing:0.16em !important;} p{margin-bottom:2em !important;}';
    return true;
  };
  A.spacingOff = function () { var s = document.getElementById('__a11y_style'); if (s) s.remove(); return true; };
})();
