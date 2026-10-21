/* Keyboard checks for the snippet. Works out the Tab order from the page, focuses each
   stop to see what changes, and reads the stylesheets to catch focus outlines that were removed. */
(function () {
  var A = window.__a11y;
  var FOCUSABLE = 'a[href],area[href],button,input:not([type=hidden]),select,textarea,summary,iframe,[tabindex],[contenteditable=""],[contenteditable=true],audio[controls],video[controls]';

  function domIndexSort(list) {
    return list.sort(function (a, b) { return (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1; });
  }

  A.tabOrder = function () {
    var list = Array.prototype.filter.call(document.querySelectorAll(FOCUSABLE), function (el) {
      if (A.isOurs(el) || el.disabled || el.tabIndex < 0) return false;
      if (el.closest('[inert]')) return false;
      var d = el.closest('details:not([open])');
      if (d && !(el.tagName === 'SUMMARY' && el.parentElement === d)) return false;
      if (!el.getClientRects().length) return false;
      var s = getComputedStyle(el);
      if (s.visibility === 'hidden' || s.display === 'none') return false;
      return true;
    });
    var groups = {};
    list = list.filter(function (el) {
      if (el.tagName !== 'INPUT' || el.type !== 'radio' || !el.name) return true;
      var key = el.name + '|' + (el.form ? Array.prototype.indexOf.call(document.forms, el.form) : -1);
      if (!groups[key]) {
        var all = Array.prototype.filter.call(document.querySelectorAll('input[type=radio]'), function (r) { return r.name === el.name && r.form === el.form; });
        groups[key] = all.filter(function (r) { return r.checked; })[0] || el;
      }
      return groups[key] === el;
    });
    var pos = domIndexSort(list.filter(function (el) { return el.tabIndex > 0; })).sort(function (a, b) { return a.tabIndex - b.tabIndex; });
    var zero = domIndexSort(list.filter(function (el) { return el.tabIndex === 0; }));
    return pos.concat(zero);
  };

  A.focusRules = function () {
    var rules = [], unknown = false;
    function walk(list) {
      for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (r.cssRules && !r.selectorText) {
          if (r.media && r.media.mediaText && !matchMedia(r.media.mediaText).matches) continue;
          try { walk(r.cssRules); } catch (e) { }
          continue;
        }
        if (!r.selectorText || !r.style) continue;
        var st = r.style;
        var isFocus = /:focus/.test(r.selectorText);
        var kills = st.outlineStyle === 'none' || st.outlineWidth === '0px' || st.outlineWidth === '0';
        if (isFocus || kills) rules.push(r);
        if (rules.length > 3000) return;
      }
    }
    for (var i = 0; i < document.styleSheets.length; i++) {
      try { walk(document.styleSheets[i].cssRules); } catch (e) { unknown = true; }
    }
    return { rules: rules, unknown: unknown };
  };

  function verdict(el, info) {
    var indicator = false, removed = false;
    info.rules.forEach(function (r) {
      r.selectorText.split(',').forEach(function (sel) {
        sel = sel.trim();
        if (/:focus-within/.test(sel)) return;
        var isF = /:focus/.test(sel);
        var base = sel.replace(/:focus-visible|:focus/g, '').trim();
        if (!base || /[>+~\s]$/.test(base)) base += '*';
        var m = false;
        try { m = el.matches(base); } catch (e) { m = false; }
        if (!m) return;
        var st = r.style;
        var kills = st.outlineStyle === 'none' || st.outlineWidth === '0px' || st.outlineWidth === '0';
        var shows = (st.outlineStyle && st.outlineStyle !== 'none' && st.outlineWidth !== '0px') || (st.boxShadow && st.boxShadow !== 'none') ||
          st.borderTopColor || st.borderBottomColor || st.borderTopWidth || st.backgroundColor || st.backgroundImage || st.color || st.textDecorationLine;
        if (isF && shows) indicator = true;
        else if (kills) removed = true;
      });
    });
    if (indicator) return 'ok';
    if (removed) return 'removed';
    return info.unknown ? 'unknown' : 'ok';
  }

  function snap(el) {
    var s = getComputedStyle(el);
    var p = el.parentElement ? getComputedStyle(el.parentElement) : null;
    return [s.outlineStyle, s.outlineWidth, s.outlineColor, s.boxShadow, s.borderTopColor, s.borderBottomColor, s.borderTopWidth, s.backgroundColor, s.color, s.textDecorationLine,
      p ? p.boxShadow + p.outlineStyle + p.borderTopColor + p.backgroundColor : ''].join('|');
  }

  A.kbStatic = function () {
    A.tabs = A.tabOrder();
    A.tabInfo = []; A.invisibleFocus = []; A.obscured = []; A.tabIndexOf = new Map();
    var prev = A.deepActive ? A.deepActive() : document.activeElement;
    var rules = A.focusRules();
    var noVisible = [];
    var sx = window.scrollX, sy = window.scrollY;
    A.tabs.forEach(function (el, i) {
      A.tabIndexOf.set(el, i);
      var before = snap(el);
      try { el.focus({ preventScroll: true }); } catch (e) { }
      var focused = (A.deepActive ? A.deepActive() : document.activeElement) === el;
      var r = el.getBoundingClientRect(), s = getComputedStyle(el);
      var info = { i: i, label: A.describe(el), x: r.left + window.scrollX, y: r.top + window.scrollY, w: r.width, h: r.height };
      var offscreen = r.right + window.scrollX < 0 || r.bottom + window.scrollY < 0 || r.left + window.scrollX > document.documentElement.scrollWidth;
      if ((r.width < 1 || r.height < 1 || s.visibility === 'hidden' || parseFloat(s.opacity) === 0 || offscreen) && el.tagName !== 'IFRAME') {
        A.invisibleFocus.push(el); info.invisible = true;
      } else if (focused && i < 80) {
        if (snap(el) === before && verdict(el, rules) === 'removed') noVisible.push(i);
      }
      A.tabInfo.push(info);
      try { el.blur(); } catch (e) { }
    });
    window.scrollTo(sx, sy);
    try { if (prev && prev.focus && prev !== document.body) prev.focus({ preventScroll: true }); } catch (e) { }
    var res = A.kbAnalyze();
    return res.findings.concat(A.fvResult(noVisible));
  };
})();
