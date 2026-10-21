/* Module 2. Keyboard only checks. The driver presses real Tab keys; these helpers record and judge each stop. */
(function () {
  var A = window.__a11y;

  A.deepActive = function () {
    var a = document.activeElement;
    while (a && a.shadowRoot && a.shadowRoot.activeElement) a = a.shadowRoot.activeElement;
    return a;
  };

  function fixedAncestor(e) {
    while (e && e !== document.documentElement && e !== document.body) {
      var p = getComputedStyle(e).position;
      if (p === 'fixed' || p === 'sticky') return e;
      e = e.parentElement;
    }
    return null;
  }

  A.kbStart = function () {
    A.tabs = []; A.tabInfo = []; A.tabIndexOf = new Map(); A.obscured = []; A.invisibleFocus = [];
    window.scrollTo(0, 0);
    var s = document.createElement('span');
    s.tabIndex = -1;
    s.setAttribute('data-a11y-overlay', '1');
    s.style.cssText = 'position:absolute;left:0;top:0;width:1px;height:1px;overflow:hidden;';
    if (document.body) {
      document.body.insertBefore(s, document.body.firstChild);
      s.focus();
      s.remove();
    }
    return true;
  };

  A.kbStep = function (i) {
    var el = A.deepActive();
    if (!el || el === document.body || el === document.documentElement) return { none: true };
    if (A.isOurs(el)) return { ours: true };
    if (A.tabIndexOf.has(el)) return { repeat: true, first: A.tabIndexOf.get(el), label: A.describe(el) };
    A.tabIndexOf.set(el, A.tabs.length);
    A.tabs.push(el);
    var r = el.getBoundingClientRect();
    var info = { i: A.tabs.length - 1, label: A.describe(el), x: r.left + window.scrollX, y: r.top + window.scrollY, w: r.width, h: r.height };
    A.tabInfo.push(info);
    var s = getComputedStyle(el);
    var offscreen = r.right + window.scrollX < 0 || r.bottom + window.scrollY < 0 || r.left > document.documentElement.scrollWidth;
    if (r.width < 1 || r.height < 1 || s.visibility === 'hidden' || parseFloat(s.opacity) === 0 || offscreen) {
      if (el.tagName !== 'IFRAME') A.invisibleFocus.push(el);
      info.invisible = true;
      return info;
    }
    if (r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth) {
      var pts = [[r.left + r.width / 2, r.top + r.height / 2], [r.left + 3, r.top + 3], [r.right - 3, r.top + 3], [r.left + 3, r.bottom - 3], [r.right - 3, r.bottom - 3]]
        .filter(function (p) { return p[0] >= 0 && p[1] >= 0 && p[0] < innerWidth && p[1] < innerHeight; });
      var hits = 0, coverEl = null;
      pts.forEach(function (p) {
        var h = document.elementFromPoint(p[0], p[1]);
        if (!h) return;
        if (h === el || el.contains(h) || h.contains(el)) hits++;
        else if (!coverEl) coverEl = h;
      });
      if (pts.length && hits === 0 && coverEl) {
        var fx = fixedAncestor(coverEl);
        if (fx && !fx.contains(el)) { A.obscured.push({ el: el, by: fx }); info.obscured = true; }
      }
    }
    return info;
  };

  function covered(el) {
    for (var i = 0; i < A.tabs.length; i++) {
      var t = A.tabs[i];
      if (t === el || t.contains(el) || el.contains(t)) return true;
    }
    return false;
  }

  A.kbAnalyze = function () {
    var F = [];
    var unreachable = [], fakes = [], fakeChecks = [];
    A.interactive().forEach(function (el) {
      if (covered(el)) return;
      if (el.closest('[aria-hidden=true]')) return;
      var tag = el.tagName.toLowerCase(), role = el.getAttribute('role');
      if (tag === 'input' && el.type === 'radio' && A.tabs.some(function (t) { return t.type === 'radio' && t.name === el.name; })) return;
      var comp = el.closest('[role=tablist],[role=menu],[role=menubar],[role=listbox],[role=tree],[role=grid],[role=radiogroup],[role=toolbar],[role=treegrid]');
      if (comp && A.tabs.some(function (t) { return comp.contains(t); })) return;
      if (tag === 'label') return;
      var native = /^(a|button|input|select|textarea|summary)$/.test(tag);
      if (!native && !role && el.hasAttribute('onclick')) { fakes.push(el); return; }
      unreachable.push(el);
    });
    var pointerScan = document.body ? document.body.querySelectorAll('div,span,li,td,img,i,svg,p,em,strong') : [];
    for (var k = 0; k < pointerScan.length && fakeChecks.length < 6; k++) {
      var el = pointerScan[k];
      if (!A.visible(el)) continue;
      if (getComputedStyle(el).cursor !== 'pointer') continue;
      var par = el.parentElement;
      if (par && getComputedStyle(par).cursor === 'pointer') continue;
      if (el.closest('a,button,label,summary,input,select,textarea,[role],[tabindex],[onclick]')) continue;
      if (el.querySelector(A.INTERACTIVE)) continue;
      var rr = el.getBoundingClientRect();
      if (rr.width < 8 || rr.height < 8) continue;
      if (fakes.indexOf(el) >= 0 || covered(el)) continue;
      fakeChecks.push(el);
    }
    unreachable.slice(0, 5).forEach(function (el) {
      F.push(A.finding('kb-unreachable', 'High', 'confirmed', { name: A.describe(el) }, el,
        A.selector(el) + (el.getAttribute('tabindex') === '-1' ? ' has tabindex="-1". Remove it or use 0.' : ' never receives focus from the Tab key.')));
    });
    fakes.slice(0, 5).forEach(function (el) {
      F.push(A.finding('kb-fake', 'High', 'confirmed', { name: A.describe(el) }, el,
        A.selector(el) + ' has onclick but no role or tabindex. Use a <button> element.'));
    });
    fakeChecks.slice(0, 3).forEach(function (el) {
      F.push(A.finding('kb-fake-check', 'Medium', 'check', { name: A.describe(el) }, el,
        A.selector(el) + ' shows a pointer cursor but is not a link or button. If it can be clicked, use a <button>.'));
    });
    A.invisibleFocus.slice(0, 3).forEach(function (el) {
      F.push(A.finding('kb-focus-hidden-item', 'Medium', 'confirmed', { name: A.describe(el) }, [],
        A.selector(el) + ' receives focus while invisible or off screen.'));
    });
    A.obscured.slice(0, 3).forEach(function (o) {
      F.push(A.finding('kb-obscured', 'Medium', 'confirmed', { name: A.describe(o.el), cover: A.describe(o.by) }, [o.el, o.by],
        A.selector(o.el) + ' is hidden behind fixed or sticky ' + A.selector(o.by) + '. Add scroll-padding-top or scroll-padding-bottom on html equal to the bar height so focused items scroll clear of it.'));
    });

    // Focus order. Flag a jump up within the same column, or right to left on the same row.
    var jumps = [];
    for (var i = 1; i < A.tabInfo.length; i++) {
      var p = A.tabInfo[i - 1], c = A.tabInfo[i];
      if (p.invisible || c.invisible || !p.w || !c.w) continue;
      var overlapX = Math.min(p.x + p.w, c.x + c.w) - Math.max(p.x, c.x);
      var up = c.y + c.h < p.y - 30 && overlapX > 0;
      var sameRow = Math.abs(c.y - p.y) < 10 && c.x + c.w < p.x - 30;
      if (up || sameRow) jumps.push([p, c]);
    }
    var posTab = Array.prototype.filter.call(document.querySelectorAll('[tabindex]'), function (e) { return parseInt(e.getAttribute('tabindex'), 10) > 0; });
    var posVisible = posTab.filter(function (e) { return A.visible(e); });
    if (jumps.length || posVisible.length) {
      var ex = jumps.slice(0, 2).map(function (j) { return 'from ' + j[0].label + ' (stop ' + (j[0].i + 1) + ') back to ' + j[1].label + ' (stop ' + (j[1].i + 1) + ')'; }).join(', and ');
      if (!ex) ex = 'straight to ' + A.describe(posVisible[0]) + ' before anything else, because it is forced to the front of the order';
      var f = A.finding('kb-order', 'Medium', jumps.length ? 'check' : 'confirmed', { example: ex, count: jumps.length }, [],
        (posTab.length ? posTab.length + ' element(s) use a positive tabindex, which forces an unusual order, e.g. ' + A.selector(posTab[0]) + '. ' : '') + 'Match DOM order to the visual order.');
      f.tabNumbers = true;
      F.push(f);
    }

    // Skip link or main region
    var first = A.tabs[0];
    var hasSkip = first && first.tagName === 'A' && /^#/.test(first.getAttribute('href') || '') && /skip|main|content|jump/i.test(first.innerText || first.getAttribute('aria-label') || '');
    var hasMain = !!document.querySelector('main,[role=main]');
    var menuStops = A.tabs.filter(function (t) { return t.closest('nav,[role=navigation],header,[role=banner]'); }).length;
    if (!hasSkip && !hasMain && menuStops >= 3) {
      F.push(A.finding('kb-skip', 'Low', 'confirmed', { count: menuStops }, [], 'Add <a href="#main" class="skip-link">Skip to main content</a> as the first item and a <main id="main"> region.'));
    }
    return { findings: F, stops: A.tabs.length };
  };

  A.showTabNumbers = function () {
    A.clearOverlays();
    window.scrollTo(0, 0);
    A.tabs.slice(0, 60).forEach(function (el, i) {
      var r = el.getBoundingClientRect();
      if (r.width < 1 || r.height < 1) return;
      A.box(r, '#0A3470', String(i + 1));
    });
    return true;
  };

  /* Focus visible: the driver screenshots each stop focused and unfocused and compares pixels here. */
  A.fvPrep = function () {
    var s = document.getElementById('__a11y_fv');
    if (!s) { s = document.createElement('style'); s.id = '__a11y_fv'; (document.head || document.documentElement).appendChild(s); }
    s.textContent = '*{caret-color:transparent !important;transition:none !important;animation:none !important;}';
    return Math.min(A.tabs.length, 40);
  };
  A.fvFocus = function (i) {
    var el = A.tabs[i];
    if (!el || !el.isConnected || !A.visible(el)) return null;
    try { el.scrollIntoView({ block: 'center', inline: 'nearest' }); } catch (e) { }
    el.focus({ preventScroll: true });
    if (A.deepActive() !== el) return null;
    var r = el.getBoundingClientRect();
    var pad = 8;
    var x = Math.max(0, r.left - pad), y = Math.max(0, r.top - pad);
    var w = Math.min(innerWidth, r.right + pad) - x, h = Math.min(innerHeight, r.bottom + pad) - y;
    if (w < 2 || h < 2) return null;
    return { x: Math.round(x + window.scrollX), y: Math.round(y + window.scrollY), w: Math.round(w), h: Math.round(h) };
  };
  A.fvBlur = function (i) {
    var el = A.tabs[i];
    if (el) el.blur();
    return true;
  };
  A.fvCompare = function (a, b) {
    if (a === b) return Promise.resolve(0);
    var load = function (b64) {
      var bin = atob(b64), u = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
      return createImageBitmap(new Blob([u], { type: 'image/png' }));
    };
    return Promise.all([load(a), load(b)]).then(function (imgs) {
      var w = Math.min(imgs[0].width, imgs[1].width), h = Math.min(imgs[0].height, imgs[1].height);
      var c = document.createElement('canvas'); c.width = w; c.height = h;
      var ctx = c.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(imgs[0], 0, 0); var d1 = ctx.getImageData(0, 0, w, h).data;
      ctx.clearRect(0, 0, w, h);
      ctx.drawImage(imgs[1], 0, 0); var d2 = ctx.getImageData(0, 0, w, h).data;
      var diff = 0;
      for (var i = 0; i < d1.length; i += 4) {
        if (Math.abs(d1[i] - d2[i]) + Math.abs(d1[i + 1] - d2[i + 1]) + Math.abs(d1[i + 2] - d2[i + 2]) > 60) diff++;
      }
      return diff;
    });
  };
  A.fvResult = function (noVisible) {
    var F = [];
    noVisible.slice(0, 5).forEach(function (i) {
      var el = A.tabs[i];
      if (!el) return;
      F.push(A.finding('kb-focus-invisible', 'Medium', 'confirmed', { name: A.describe(el) }, el,
        A.selector(el) + ' shows no visible change on focus. Add a :focus-visible outline, at least 2px with 3:1 contrast.'));
    });
    var s = document.getElementById('__a11y_fv'); if (s) s.remove();
    return F;
  };
})();
