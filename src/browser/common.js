/* A11y Tester shared helpers. Runs inside the page being tested. */
(function () {
  if (window.__a11y && window.__a11y.v === 3) return;
  var A = window.__a11y = { v: 3, marks: new Map(), nextMark: 1 };
  var HOST_ID = '__a11y_toolbar_host';

  A.isOurs = function (el) {
    return !!(el && el.closest && (el.closest('#' + HOST_ID) || el.closest('[data-a11y-overlay]')));
  };

  A.clean = function (t) { return String(t == null ? '' : t).replace(/\s+/g, ' ').trim(); };
  A.short = function (t, n) {
    t = A.clean(t); n = n || 60;
    return t.length > n ? t.slice(0, n - 1).trim() + '...' : t;
  };

  A.visible = function (el) {
    if (!el || el.nodeType !== 1 || !el.getBoundingClientRect) return false;
    if (A.isOurs(el)) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    var s = getComputedStyle(el);
    if (s.visibility === 'hidden' || s.visibility === 'collapse') return false;
    if (parseFloat(s.opacity) === 0) return false;
    return true;
  };

  A.label = function (el) {
    if (!el || el.nodeType !== 1) return '';
    var t = el.getAttribute('aria-label') || '';
    if (!t) {
      var lb = el.getAttribute('aria-labelledby');
      if (lb) { t = lb.split(/\s+/).map(function (id) { var e = document.getElementById(id); return e ? e.innerText || e.textContent : ''; }).join(' '); }
    }
    if (!t && el.labels && el.labels.length) t = el.labels[0].innerText || el.labels[0].textContent || '';
    if (!t) t = el.innerText || '';
    if (!t && el.tagName === 'INPUT' && /^(button|submit|reset)$/i.test(el.type)) t = el.value || '';
    if (!t) t = el.getAttribute('title') || el.getAttribute('alt') || el.getAttribute('placeholder') || '';
    if (!t) { var img = el.querySelector && el.querySelector('img[alt]'); if (img) t = img.getAttribute('alt'); }
    return A.short(t, 50);
  };

  A.kind = function (el) {
    var tag = el.tagName.toLowerCase(), role = (el.getAttribute('role') || '').toLowerCase();
    var map = { button: 'button', link: 'link', tab: 'tab', menuitem: 'menu item', checkbox: 'check box', radio: 'radio button', 'switch': 'switch', option: 'option', combobox: 'dropdown', textbox: 'field', img: 'image', heading: 'heading', dialog: 'popup' };
    if (role && map[role]) return map[role];
    if (tag === 'a') return 'link';
    if (tag === 'button') return 'button';
    if (tag === 'input') {
      var ty = (el.type || 'text').toLowerCase();
      if (ty === 'button' || ty === 'submit' || ty === 'reset' || ty === 'image') return 'button';
      if (ty === 'checkbox') return 'check box';
      if (ty === 'radio') return 'radio button';
      return 'field';
    }
    if (tag === 'select') return 'dropdown';
    if (tag === 'textarea') return 'field';
    if (tag === 'img' || tag === 'svg') return 'image';
    if (/^h[1-6]$/.test(tag)) return 'heading';
    if (tag === 'table') return 'table';
    return 'item';
  };

  A.describe = function (el) {
    if (!el) return 'an item';
    var l = A.label(el), k = A.kind(el);
    return l ? 'the ' + k + ' "' + l + '"' : 'a ' + k + ' with no text';
  };

  A.selector = function (el) {
    if (!el || el.nodeType !== 1) return '';
    var okId = function (id) { return id && /^[A-Za-z][\w-]*$/.test(id) && id.length < 50; };
    var parts = [], cur = el, depth = 0;
    while (cur && cur.nodeType === 1 && cur !== document.body && depth < 4) {
      var p = cur.tagName.toLowerCase();
      if (okId(cur.id)) { parts.unshift(p + '#' + cur.id); break; }
      var cls = Array.prototype.filter.call(cur.classList, function (c) { return /^[A-Za-z][\w-]*$/.test(c) && !/^(ng-|is-|has-|active|focus|hover|selected)/.test(c); }).slice(0, 2);
      if (cls.length) p += '.' + cls.join('.');
      else if (cur.parentElement) {
        var same = Array.prototype.filter.call(cur.parentElement.children, function (c) { return c.tagName === cur.tagName; });
        if (same.length > 1) p += ':nth-of-type(' + (same.indexOf(cur) + 1) + ')';
      }
      parts.unshift(p); cur = cur.parentElement; depth++;
    }
    return parts.join(' > ');
  };

  A.sig = function (el) {
    if (!el) return '';
    return (el.tagName.toLowerCase() + '|' + (el.id || '') + '|' + A.short(A.label(el), 30)).toLowerCase();
  };

  A.mark = function (els) {
    var id = A.nextMark++;
    A.marks.set(id, (Array.isArray(els) ? els : [els]).filter(Boolean));
    return id;
  };

  A.clearOverlays = function () {
    Array.prototype.forEach.call(document.querySelectorAll('[data-a11y-overlay]'), function (n) { n.remove(); });
  };

  A.box = function (r, color, text) {
    var d = document.createElement('div');
    d.setAttribute('data-a11y-overlay', '1');
    d.setAttribute('aria-hidden', 'true');
    d.style.cssText = 'position:fixed;left:' + (r.left - 4) + 'px;top:' + (r.top - 4) + 'px;width:' + (r.width + 8) + 'px;height:' + (r.height + 8) +
      'px;border:4px solid ' + (color || '#e00000') + ';box-sizing:border-box;z-index:2147483647;pointer-events:none;background:transparent;margin:0;padding:0;';
    if (text) {
      var b = document.createElement('div');
      b.textContent = text;
      b.style.cssText = 'position:absolute;left:-4px;top:-22px;background:' + (color || '#e00000') + ';color:#fff;font:bold 12px Arial,sans-serif;padding:1px 5px;line-height:16px;white-space:nowrap;';
      d.appendChild(b);
    }
    document.documentElement.appendChild(d);
    return d;
  };

  A.showMarks = function (ids, scroll) {
    A.clearOverlays();
    var els = [];
    ids.forEach(function (id) { (A.marks.get(id) || []).forEach(function (el) { if (el && el.isConnected) els.push(el); }); });
    if (els.length && scroll !== false) { try { els[0].scrollIntoView({ block: 'center', inline: 'nearest' }); if (window.scrollX > 0 && els[0].getBoundingClientRect().width > innerWidth) window.scrollTo(0, window.scrollY); } catch (e) { } }
    var n = 0;
    els.forEach(function (el) {
      var r = el.getBoundingClientRect();
      if (r.width < 1 && r.height < 1) return;
      A.box(r); n++;
    });
    return n;
  };

  A.textElements = function () {
    var out = [], seen = new Set();
    if (!document.body) return out;
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) { return (n.nodeValue && n.nodeValue.trim().length > 1) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT; }
    });
    var n;
    while ((n = walker.nextNode())) {
      var el = n.parentElement;
      if (!el || seen.has(el)) continue;
      if (/^(SCRIPT|STYLE|NOSCRIPT|TEMPLATE|OPTION)$/.test(el.tagName)) continue;
      if (A.isOurs(el)) continue;
      seen.add(el); out.push(el);
      if (out.length > 4000) break;
    }
    return out;
  };

  A.textRect = function (el) {
    var range = document.createRange(), r = null;
    for (var i = 0; i < el.childNodes.length; i++) {
      var c = el.childNodes[i];
      if (c.nodeType !== 3 || !c.nodeValue.trim()) continue;
      range.selectNodeContents(c);
      var b = range.getBoundingClientRect();
      if (b.width < 1 || b.height < 1) continue;
      r = r ? { left: Math.min(r.left, b.left), top: Math.min(r.top, b.top), right: Math.max(r.right, b.right), bottom: Math.max(r.bottom, b.bottom) }
        : { left: b.left, top: b.top, right: b.right, bottom: b.bottom };
    }
    return r;
  };

  A.textLineRects = function (el) {
    var range = document.createRange(), out = [];
    for (var i = 0; i < el.childNodes.length; i++) {
      var c = el.childNodes[i];
      if (c.nodeType !== 3 || !c.nodeValue.trim()) continue;
      range.selectNodeContents(c);
      var rs = range.getClientRects();
      for (var j = 0; j < rs.length; j++) { if (rs[j].width >= 2 && rs[j].height >= 2) out.push(rs[j]); }
    }
    return out;
  };

  A.INTERACTIVE = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[role=button],[role=link],[role=tab],[role=menuitem],[role=checkbox],[role=radio],[role=switch],[role=option],[role=combobox],[role=textbox],[role=slider],[role=spinbutton],[role=treeitem],[onclick],[tabindex]:not([tabindex^="-"]),[contenteditable=""],[contenteditable=true]';

  A.interactive = function () {
    return Array.prototype.filter.call(document.querySelectorAll(A.INTERACTIVE), function (el) {
      return A.visible(el) && !el.disabled && !el.closest('[inert]') && el.getAttribute('aria-disabled') !== 'true';
    });
  };

  A.settle = function (quietMs, maxMs) {
    quietMs = quietMs || 400; maxMs = maxMs || 6000;
    return new Promise(function (resolve) {
      var t, finished = false;
      var done = function () { if (finished) return; finished = true; try { obs.disconnect(); } catch (e) { } resolve(document.readyState); };
      var obs = new MutationObserver(function (muts) {
        var ours = muts.every(function (m) { return A.isOurs(m.target) || (m.type === 'attributes' && /^data-a11y/.test(m.attributeName || '')); });
        if (ours) return;
        clearTimeout(t); t = setTimeout(done, quietMs);
      });
      obs.observe(document, { subtree: true, childList: true, attributes: true, characterData: true });
      t = setTimeout(done, quietMs);
      setTimeout(done, maxMs);
    });
  };

  A.screenInfo = function () {
    var h1 = document.querySelector('h1, [role=heading][aria-level="1"]');
    var h1t = h1 && A.visible(h1) ? A.short(h1.innerText, 60) : '';
    var title = A.short(document.title, 80);
    var path = location.pathname.replace(/\/\d+(?=\/|$)/g, '/#').replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, '#');
    return { name: h1t || title || location.pathname || 'Untitled screen', title: title, h1: h1t, url: location.href, path: path };
  };

  A.cleanup = function () {
    A.clearOverlays();
    ['data-a11y-ax', 'data-a11y-tab'].forEach(function (a) {
      Array.prototype.forEach.call(document.querySelectorAll('[' + a + ']'), function (n) { n.removeAttribute(a); });
    });
    var s = document.getElementById('__a11y_style'); if (s) s.remove();
    var f = document.getElementById('__a11y_fv'); if (f) f.remove();
    return true;
  };

  A.finding = function (rule, sev, conf, params, els, dev) {
    var list = (Array.isArray(els) ? els : [els]).filter(Boolean);
    var f = { rule: rule, sev: sev, conf: conf || 'confirmed', params: params || {}, dev: dev || '', sig: list.length ? A.sig(list[0]) : '' };
    if (list.length) f.mark = A.mark(list);
    if (!f.dev && list.length) f.dev = A.selector(list[0]);
    return f;
  };
})();
