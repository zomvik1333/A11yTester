/* The on screen panel, saved results across screens, and the report you paste into Word.
   RULES, WCAG and MANUAL are filled in by build-snippet.ps1 from src/report/Rules.ps1. */
(function () {
  var A = window.__a11y;
  var KEY = '__a11ySnippetV1';
  var VERSION = SNIPPET_VERSION;
  var EXTRA_MANUAL = [
    ['2.1.2', 'Press Tab through each screen and into every popup. Focus should never get stuck, and Esc should close popups.'],
    ['2.4.11', 'While tabbing, the item with focus should never hide behind a sticky header, footer or banner.'],
    ['2.4.7', 'While tabbing, you should always be able to see which item has focus.']
  ];
  var PERSON_IN_SNIPPET = { '2.1.2': 1, '2.4.11': 1 };

  function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function fill(t, p) {
    var out = String(t || '');
    Object.keys(p || {}).forEach(function (k) { out = out.split('{' + k + '}').join(String(p[k])); });
    return out.replace(/\{[a-z]+\}/g, 'this item');
  }
  var memStore = null;
  function load() {
    try { var d = JSON.parse(localStorage.getItem(KEY)); if (d && d.screens) return d; } catch (e) { }
    return memStore || { screens: [] };
  }
  function save(d) { memStore = d; try { localStorage.setItem(KEY, JSON.stringify(d)); } catch (e) { } }
  function rank(s) { return s === 'High' ? 3 : s === 'Medium' ? 2 : 1; }

  function screenKey() { return location.href + '|' + A.screenInfo().name; }
  function currentScreen(data, create) {
    var key = screenKey();
    for (var i = data.screens.length - 1; i >= 0; i--) { if ((data.screens[i].key || data.screens[i].url) === key) return data.screens[i]; }
    if (!create) return null;
    var info = A.screenInfo();
    var s = { key: key, url: location.href, name: info.name, how: '', when: new Date().toLocaleString(), issues: [], parts: {} };
    data.screens.push(s);
    return s;
  }

  function pack(list, part, phase) {
    return list.map(function (f) { return { rule: f.rule, sev: f.sev, conf: f.conf, params: f.params, dev: f.dev, sig: f.sig, mark: f.mark || 0, part: part, phase: f.phase || phase }; });
  }

  function mergeZoom(existing, incoming) {
    var out = [];
    incoming.forEach(function (f) {
      var kind = /clip/.test(f.rule) ? 'clip' : /overlap/.test(f.rule) ? 'overlap' : '';
      var prev = kind && f.sig ? existing.concat(out).filter(function (e) { return e.sig === f.sig && e.rule.indexOf(kind) >= 0; })[0] : null;
      if (prev) { if (prev.phase.indexOf(f.phase.toLowerCase()) < 0) prev.phase += ', also ' + f.phase.toLowerCase(); }
      else out.push(f);
    });
    return out;
  }

  function guard(fn, name, out) {
    try { return fn(); } catch (e) {
      out.push({ rule: 'tool-error', sev: 'Low', conf: 'check', params: { module: name, detail: '' }, dev: String(e && e.message || e), sig: '', part: '', phase: '' });
      return [];
    }
  }

  A.snip = {
    lastFindings: [],
    testScreen: function (name, how) {
      A.clearOverlays();
      var errs = [], F = [];
      F = F.concat(pack(guard(function () { A.buildAxFromDom(); return A.srChecks(); }, 'Screen reader', errs), 'screen', 'Screen reader'));
      F = F.concat(pack(guard(function () { return A.kbStatic(); }, 'Keyboard', errs), 'screen', 'Keyboard'));
      F = F.concat(pack(guard(function () {
        A.zoomBaseline(); A.spacingOn();
        try { return A.zoomCheck('spacing'); } finally { A.spacingOff(); }
      }, 'Text spacing', errs), 'screen', 'With wider text spacing'));
      var data = load();
      var s = currentScreen(data, true);
      if (name) s.name = name;
      if (how != null) s.how = how;
      s.when = new Date().toLocaleString();
      s.issues = s.issues.filter(function (i) { return i.part !== 'screen'; });
      var merged = mergeZoom(s.issues, F);
      s.issues = s.issues.concat(merged).concat(pack(errs, 'screen', ''));
      s.parts.screen = true;
      save(data);
      A.snip.lastFindings = s.issues;
      return s.issues;
    },
    checkZoom: function (level, force) {
      var w = window.innerWidth;
      if (!force) {
        if (level === 400 && w > 380) return { tooWide: true, width: w };
        if (level === 200 && w > 760) return { tooWide: true, width: w };
      }
      A.clearOverlays();
      var errs = [];
      var phase = level === 400 ? 'At 400% zoom' : 'At 200% zoom';
      var F = pack(guard(function () { return A.zoomCheck(level === 400 ? 'reflow' : 'resize'); }, 'Zoom', errs), 'zoom' + level, phase);
      var data = load();
      var s = currentScreen(data, true);
      s.issues = s.issues.filter(function (i) { return i.part !== 'zoom' + level; });
      s.issues = s.issues.concat(mergeZoom(s.issues, F)).concat(pack(errs, 'zoom' + level, ''));
      s.parts['zoom' + level] = true;
      save(data);
      A.snip.lastFindings = s.issues;
      return s.issues;
    },
    transcript: function () { A.buildAxFromDom(); return A.transcript(); },
    data: load,
    clear: function () { save({ screens: [] }); try { localStorage.removeItem(KEY); } catch (e) { } A.snip.lastFindings = []; ssSet(TKEY, []); memTrail = []; },
    removeScreen: function () { var d = load(), k = screenKey(); d.screens = d.screens.filter(function (s) { return (s.key || s.url) !== k; }); save(d); }
  };

  /* ---------- Recording clicks and testing each new screen on its own ---------- */
  var TKEY = '__a11ySnipTrail', OKEY = '__a11ySnipAuto';
  var memTrail = [], memAuto = true;
  function ssGet(k) { try { var x = sessionStorage.getItem(k); return x ? JSON.parse(x) : null; } catch (e) { return null; } }
  function ssSet(k, v) { try { sessionStorage.setItem(k, JSON.stringify(v)); } catch (e) { } return v; }
  function trail() { return ssGet(TKEY) || memTrail; }
  function record(step) {
    var t = trail().slice();
    if (t[t.length - 1] === step) return;
    t.push(step);
    if (t.length > 40) t = t.slice(-40);
    memTrail = t; ssSet(TKEY, t);
  }
  function labelOf(el) {
    var t = el.getAttribute('aria-label') || el.innerText || el.value || el.getAttribute('title') || el.getAttribute('alt') || '';
    if (!t) { var img = el.querySelector && el.querySelector('img[alt]'); if (img) t = img.getAttribute('alt'); }
    return A.short(t, 50);
  }
  function fieldName(el) {
    var t = (el.labels && el.labels.length ? el.labels[0].innerText : '') || el.getAttribute('aria-label') || el.getAttribute('placeholder') || el.name || '';
    return A.short(String(t).replace(/\*/g, ''), 40) || 'unlabeled';
  }
  function where(el) {
    if (el.closest('[role=tablist]')) return ' tab';
    if (el.closest('nav,[role=navigation],[role=menubar],[role=menu]')) return ' in the menu';
    if (el.closest('header,[role=banner]')) return ' at the top of the screen';
    if (el.closest('[role=dialog],dialog')) return ' in the popup';
    return '';
  }
  function attachRecorder() {
    if (window.__a11ySnipRec) return;
    window.__a11ySnipRec = true;
    document.addEventListener('click', function (ev) {
      if (host && ev.composedPath && ev.composedPath().indexOf(host) >= 0) return;
      var el = ev.target && ev.target.closest ? ev.target.closest('a,button,[role=button],[role=link],[role=tab],[role=menuitem],[role=option],[role=treeitem],summary,input[type=button],input[type=submit],input[type=checkbox],input[type=radio],label,[onclick]') : null;
      if (!el || A.isOurs(el)) return;
      if (el.matches('input[type=checkbox],input[type=radio]')) { record('Tick ' + fieldName(el) + '.'); return; }
      var name = labelOf(el);
      if (name) record('Click "' + name + '"' + where(el) + '.');
    }, true);
    document.addEventListener('change', function (ev) {
      var el = ev.target;
      if (!el || !el.matches || A.isOurs(el)) return;
      if (el.matches('select')) record('Pick an option in the ' + fieldName(el) + ' dropdown.');
      else if (el.matches('input:not([type=checkbox]):not([type=radio]),textarea')) record('Type in the ' + fieldName(el) + ' box.');
    }, true);
  }
  function autoOn() { var v = ssGet(OKEY); return v === null ? memAuto : !!v; }
  function setAuto(v) { memAuto = v; ssSet(OKEY, v); }
  A.snip.trail = trail;
  A.snip.directions = function () { return ['Log in.'].concat(trail().slice(-10)).join('\n'); };
  A.snip.setAuto = setAuto;
  var lastKey = null, busy = false;
  A.snip.autoCheck = function (force) {
    if (busy || (!force && !autoOn())) return Promise.resolve(false);
    var key = screenKey();
    if (!force && key === lastKey) return Promise.resolve(false);
    lastKey = key;
    var existing = currentScreen(load(), false);
    if (!force && existing && existing.parts && existing.parts.screen) { onTested(existing, true); return Promise.resolve(false); }
    busy = true;
    status('New screen found. Testing it now, keep your hands off for a moment...');
    return A.settle(700, 6000).then(function () {
      busy = false;
      if (screenKey() !== key) { lastKey = null; return false; }
      var info = A.screenInfo();
      var prev = currentScreen(load(), false);
      var how = prev && prev.how ? prev.how : A.snip.directions();
      var list = A.snip.testScreen(info.name, how);
      onTested(currentScreen(load(), false), false, list);
      return true;
    }, function () { busy = false; return false; });
  };
  function onTested(s, already, list) {
    if (!root) return;
    refreshFields();
    renderList();
    var n = (list || (s ? s.issues : [])).filter(function (f) { return f.rule !== 'tool-error'; }).length;
    status((already ? 'Already tested "' : 'Tested "') + (s ? s.name : '') + '". ' + n + ' possible issue(s). Run the zoom check now, or go to the next screen.');
  }
  function startWatcher() {
    if (window.__a11ySnipTimer) clearInterval(window.__a11ySnipTimer);
    window.__a11ySnipTimer = setInterval(function () {
      if (!document.getElementById('__a11y_toolbar_host')) { clearInterval(window.__a11ySnipTimer); window.__a11ySnipTimer = null; return; }
      A.snip.autoCheck(false);
    }, 800);
  }

  /* ---------- Report ---------- */
  var TH = 'background:#0A3470;color:#ffffff;font-weight:bold;text-align:left;padding:5px 8px;border:1px solid #999999;';
  var TD = 'padding:5px 8px;border:1px solid #999999;vertical-align:top;';
  var TDL = TD + 'font-weight:bold;width:150px;background:#F5F5F5;';
  function table(rows, head) {
    var h = '<table style="border-collapse:collapse;width:100%;font-family:Calibri,Arial,sans-serif;font-size:10.5pt;margin:6px 0 14px 0;">';
    rows.forEach(function (r, i) {
      h += '<tr>' + r.map(function (c) { return (head && i === 0) ? '<th style="' + TH + '">' + esc(c) + '</th>' : '<td style="' + TD + '">' + esc(c) + '</td>'; }).join('') + '</tr>';
    });
    return h + '</table>';
  }
  function card(n, f) {
    var r = RULES[f.rule]; if (!r) return '';
    var rows = [['Severity', f.sev + ', ' + (f.conf === 'confirmed' ? 'Confirmed' : 'Please check')]];
    if (f.phase) rows.push(['When it happens', f.phase]);
    rows.push(['What we found', fill(r.What, f.params)]);
    rows.push(['Who this affects', r.Who]);
    rows.push(['Recommended fix', r.Fix]);
    if (f.dev) rows.push(['Note for developers', f.dev]);
    var std = r.Wcag ? 'WCAG 2.2 ' + r.Wcag + ' ' + r.WcagName : '';
    if (r.Dof) std += '. DOF checklist item ' + r.Dof;
    if (std) rows.push(['Rule broken', std]);
    var h = '<h3 style="font-family:Calibri,Arial,sans-serif;color:#1F1F1F;font-size:12pt;margin:14px 0 4px 0;">Issue ' + n + '. ' + esc(r.Title) + '</h3>';
    h += '<table style="border-collapse:collapse;width:100%;font-family:Calibri,Arial,sans-serif;font-size:10.5pt;margin:2px 0 10px 0;">';
    rows.forEach(function (x) { h += '<tr><td style="' + TDL + '">' + esc(x[0]) + '</td><td style="' + TD + '">' + esc(x[1]) + '</td></tr>'; });
    return h + '</table>';
  }
  function steps(how, url) {
    var lines = String(how || '').split(/\r?\n|\.\s+(?=[A-Z])/).map(function (x) { return A.clean(x).replace(/\.$/, ''); }).filter(Boolean);
    if (!lines.length) lines = ['Open ' + url];
    return lines;
  }

  A.snip.reportHtml = function () {
    var data = load();
    var screens = data.screens.filter(function (s) { return s.parts && (s.parts.screen || s.parts.zoom400 || s.parts.zoom200); });
    var all = [];
    screens.forEach(function (s) { s.issues.forEach(function (f) { if (f.rule !== 'tool-error') all.push({ f: f, s: s }); }); });
    var titles = {};
    screens.forEach(function (s) { var t = (s.title || s.name || '').toLowerCase(); });
    var confirmed = all.filter(function (x) { return x.f.conf === 'confirmed'; });
    var high = all.filter(function (x) { return x.f.sev === 'High'; }).length, med = all.filter(function (x) { return x.f.sev === 'Medium'; }).length, low = all.length - high - med;
    var failed = {}, check = {};
    all.forEach(function (x) { var w = RULES[x.f.rule] && RULES[x.f.rule].Wcag; if (!w) return; if (x.f.conf === 'confirmed') failed[w] = 1; else check[w] = 1; });
    var nFail = 0, nPass = 0, nPerson = 0, nLater = 0, nCheck = 0, score = [['Criterion', 'Name', 'Level', 'Result']];
    WCAG.forEach(function (c) {
      var how = PERSON_IN_SNIPPET[c[0]] ? 'Person' : c[3], res;
      if (failed[c[0]]) { res = 'Fail'; nFail++; }
      else if (check[c[0]]) { res = 'Please check'; nCheck++; }
      else if (how === 'Auto') { res = 'Pass (automated)'; nPass++; }
      else if (how === 'Person') { res = 'Needs a person'; nPerson++; }
      else { res = 'Not tested yet'; nLater++; }
      score.push([c[0], c[1], c[2], res]);
    });
    var notCompliant = confirmed.length > 0;
    var app = location.hostname || document.title || 'this app';
    var F = 'font-family:Calibri,Arial,sans-serif;';
    var H1 = F + 'color:#0A3470;font-size:24pt;margin:0 0 4px 0;';
    var H2 = F + 'color:#0A3470;font-size:16pt;margin:22px 0 6px 0;';
    var P = F + 'font-size:11pt;margin:4px 0 8px 0;';
    var h = '<div style="' + F + 'color:#111111;">';
    h += '<h1 style="' + H1 + '">Accessibility Report</h1>';
    h += '<p style="' + P + 'color:#444444;">WCAG 2.2 Level AA check of ' + esc(app) + ', ' + esc(new Date().toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })) + '. Made with A11y Snippet ' + esc(VERSION) + '.</p>';
    h += '<h2 style="' + H2 + '">Bottom line</h2>';
    h += '<p style="' + P + 'font-size:16pt;font-weight:bold;padding:6px 10px;color:' + (notCompliant ? '#9B1C1C;background:#FBEBEB' : '#1B5E20;background:#E5F4E4') + ';">' +
      (notCompliant ? 'Not Compliant' : 'No Automated Failures Found, Manual Checks Needed') + '</p>';
    h += '<p style="' + P + '">We checked ' + screens.length + ' screen(s) and found ' + all.length + ' issue(s). ' + high + ' are High, meaning they block someone completely. ' + med + ' are Medium and ' + low + ' are Low.' +
      (notCompliant ? '' : ' Automated checks cannot cover everything, so the Needs a Person section still has to be done before calling the app compliant.') + '</p>';
    h += table([['Measure', 'Count'], ['Screens checked', String(screens.length)], ['Issues, High', String(high)], ['Issues, Medium', String(med)], ['Issues, Low', String(low)],
      ['Issues the tool is sure about', String(confirmed.length)], ['Issues that need a quick human look', String(all.length - confirmed.length)],
      ['WCAG criteria failed', String(nFail)], ['WCAG criteria passed in automated checks', String(nPass)], ['WCAG criteria needing a person', String(nPerson)]], true);

    var numbered = [];
    screens.forEach(function (s) {
      var list = s.issues.filter(function (f) { return f.rule !== 'tool-error'; }).slice().sort(function (a, b) { return rank(b.sev) - rank(a.sev); });
      list.forEach(function (f) { numbered.push({ f: f, s: s }); });
    });
    numbered.forEach(function (x, i) { x.n = i + 1; });
    if (numbered.length) {
      h += '<h2 style="' + H2 + '">Fix these first</h2>';
      var top = numbered.filter(function (x) { return x.f.conf === 'confirmed'; }).sort(function (a, b) { return rank(b.f.sev) - rank(a.f.sev); }).slice(0, 5);
      h += table([['Issue', 'Problem', 'Screen', 'Severity']].concat(top.map(function (x) { return ['Issue ' + x.n, RULES[x.f.rule].Title, x.s.name, x.f.sev]; })), true);
    }

    h += '<h2 style="' + H2 + '">Issues by screen</h2>';
    screens.forEach(function (s, si) {
      h += '<h2 style="' + F + 'color:#0A3470;font-size:13pt;margin:18px 0 4px 0;">Screen ' + (si + 1) + '. ' + esc(s.name) + '</h2>';
      h += '<p style="' + P + 'font-weight:bold;margin-bottom:2px;">How to get there</p><ol style="' + F + 'font-size:11pt;margin:2px 0 6px 0;">' +
        steps(s.how, s.url).map(function (x) { return '<li>' + esc(x) + '</li>'; }).join('') + '</ol>';
      h += '<p style="' + P + 'font-size:9pt;color:#555555;">Address ' + esc(s.url) + '</p>';
      var done = [];
      if (s.parts.screen) done.push('screen reader, keyboard and text spacing');
      if (s.parts.zoom400) done.push('400% zoom'); if (s.parts.zoom200) done.push('200% zoom');
      h += '<p style="' + P + 'font-size:9.5pt;color:#555555;">Checked ' + esc(done.join(', ')) + '.' + (!s.parts.zoom400 ? ' The 400% zoom check was not run on this screen.' : '') + '</p>';
      var mine = numbered.filter(function (x) { return x.s === s; });
      if (!mine.length) h += '<p style="' + P + 'font-style:italic;">No automated issues found on this screen.</p>';
      mine.forEach(function (x) { h += card(x.n, x.f); });
      s.issues.filter(function (f) { return f.rule === 'tool-error'; }).forEach(function (f) {
        h += '<p style="' + P + 'font-style:italic;color:#7A5C00;">Note. The ' + esc(f.params.module) + ' check could not finish on this screen, so its results may be incomplete.</p>';
      });
    });

    h += '<h2 style="' + H2 + '">Needs a person</h2><p style="' + P + '">No tool can check these automatically. Each takes a few minutes by hand.</p>';
    h += table([['WCAG', 'What to check']].concat(EXTRA_MANUAL).concat(MANUAL), true);
    h += '<h2 style="' + H2 + '">WCAG 2.2 AA scorecard</h2><p style="' + P + '">Pass (automated) means the automated checks found nothing on the screens checked. Not tested yet means a later version will cover it.</p>';
    h += table(score, true);
    h += '<p style="' + P + 'font-size:9pt;color:#555555;">A11y Snippet reads the page code and layout inside your browser. It sends nothing anywhere and takes no screenshots. Use the Show buttons in the panel to see each problem on screen.</p>';
    return h + '</div>';
  };

  function openReport() {
    var html = '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Accessibility Report</title></head><body style="margin:24px;max-width:900px;">' + A.snip.reportHtml() + '</body></html>';
    var w = window.open('', '_blank');
    if (!w) return false;
    w.document.open(); w.document.write(html); w.document.close();
    return true;
  }
  function copyReport(done) {
    var html = A.snip.reportHtml();
    var tmp = document.createElement('div'); tmp.innerHTML = html;
    var text = tmp.innerText;
    try {
      if (window.ClipboardItem && navigator.clipboard && navigator.clipboard.write) {
        navigator.clipboard.write([new ClipboardItem({ 'text/html': new Blob([html], { type: 'text/html' }), 'text/plain': new Blob([text], { type: 'text/plain' }) })])
          .then(function () { done(true); }, function () { done(false); });
        return;
      }
    } catch (e) { }
    done(false);
  }

  /* ---------- Panel ---------- */
  var host, root, el = {};
  function $(id) { return root.getElementById(id); }
  function status(t) { if (el.status) el.status.textContent = t; }
  function renderList() {
    var data = load(), s = currentScreen(data, false);
    var count = data.screens.filter(function (x) { return x.parts && (x.parts.screen || x.parts.zoom400 || x.parts.zoom200); }).length;
    el.saved.textContent = count + ' screen(s) saved for the report.';
    var list = (s ? s.issues : []).filter(function (f) { return f.rule !== 'tool-error'; }).slice().sort(function (a, b) { return rank(b.sev) - rank(a.sev); });
    var live = {};
    (A.snip.lastFindings || []).forEach(function (f) { if (f.mark) live[f.rule + '|' + f.sig + '|' + f.dev] = f.mark; });
    el.list.innerHTML = '';
    if (!s) { el.list.innerHTML = '<p class="muted">Not checked yet.</p>'; return; }
    if (!list.length) { el.list.innerHTML = '<p class="muted">No automated issues found on this screen so far.</p>'; return; }
    list.forEach(function (f) {
      var r = RULES[f.rule]; if (!r) return;
      var d = document.createElement('div'); d.className = 'item sev' + f.sev;
      var mark = f.mark && live[f.rule + '|' + f.sig + '|' + f.dev] === f.mark ? f.mark : 0;
      d.innerHTML = '<div class="it"><span class="badge">' + esc(f.sev) + '</span> ' + esc(r.Title) + (f.conf !== 'confirmed' ? ' <span class="muted">(please check)</span>' : '') + '</div>' +
        '<div class="wf">' + esc(fill(r.What, f.params)) + '</div>' + (mark ? '<button class="sm" data-mark="' + mark + '" type="button">Show me</button>' : '');
      el.list.appendChild(d);
    });
    Array.prototype.forEach.call(el.list.querySelectorAll('button[data-mark]'), function (b) {
      b.addEventListener('click', function () {
        var n = A.showMarks([parseInt(b.getAttribute('data-mark'), 10)]);
        status(n ? 'Outlined in red on the page. Click Hide Boxes when done.' : 'That item is not visible on the page right now.');
      });
    });
  }
  function updateWidth() { if (el.width) el.width.textContent = String(window.innerWidth); }

  function build() {
    var old = document.getElementById('__a11y_toolbar_host'); if (old) old.remove();
    host = document.createElement('div');
    host.id = '__a11y_toolbar_host';
    host.style.cssText = 'all:initial;position:fixed;right:12px;bottom:12px;z-index:2147483647;';
    root = host.attachShadow({ mode: 'open' });
    root.innerHTML = '<style>' +
      '.p{font:13px/1.35 "Segoe UI",Arial,sans-serif;background:#fff;color:#111;border:2px solid #0A3470;border-radius:10px;box-shadow:0 4px 18px rgba(0,0,0,.28);width:300px;max-width:calc(100vw - 30px);max-height:calc(100vh - 30px);overflow:auto;padding:10px 12px}' +
      '.hd{display:flex;justify-content:space-between;align-items:center;margin-bottom:6px}.t{font-weight:700;color:#0A3470;font-size:14px}' +
      'label{display:block;font-weight:600;margin:6px 0 2px}input,textarea{width:100%;box-sizing:border-box;font:inherit;border:1px solid #767676;border-radius:4px;padding:4px 6px}' +
      'button{font:inherit;font-weight:600;border-radius:6px;padding:6px 10px;margin:4px 4px 0 0;cursor:pointer;border:2px solid #0A3470;background:#fff;color:#0A3470}' +
      'button.pri{background:#0A3470;color:#fff}button.sm{padding:2px 8px;font-size:12px;margin-top:4px}button.x{border:0;font-size:18px;padding:0 6px;margin:0}' +
      'button:focus-visible,input:focus-visible,textarea:focus-visible{outline:3px solid #C49F47;outline-offset:2px}' +
      '.sec{border-top:1px solid #ddd;margin-top:8px;padding-top:6px}.muted{color:#555;font-size:12px}.st{margin-top:6px;font-size:12px;color:#0A3470;min-height:16px}' +
      '.item{border-left:4px solid #888;padding:4px 6px;margin:6px 0;background:#fafafa}.sevHigh{border-color:#B00020}.sevMedium{border-color:#C77700}.sevLow{border-color:#5A6B7A}' +
      '.it{font-weight:600}.wf{font-size:12px;margin-top:2px}.badge{font-size:11px;font-weight:700;background:#eee;border-radius:3px;padding:0 4px}' +
      '.min .bd{display:none}' +
      '</style><div class="p" role="region" aria-label="A11y Snippet"><div class="hd"><span class="t">A11y Snippet</span><span>' +
      '<button class="x" id="min" type="button" aria-label="Minimize panel">_</button><button class="x" id="close" type="button" aria-label="Close panel">x</button></span></div>' +
      '<div class="bd"><div class="muted" id="mode"></div>' +
      '<button id="auto" type="button">Pause Auto Testing</button>' +
      '<label for="nm">Screen name</label><input id="nm" type="text">' +
      '<label for="how">How to get here, filled in from your clicks</label><textarea id="how" rows="3"></textarea>' +
      '<button class="pri" id="test" type="button">Test Again</button>' +
      '<div class="sec"><div><strong>Zoom checks</strong></div><div class="muted">Press Ctrl and + until the width below is 320 or less, then click Check 400%. Press Ctrl and 0 when done.</div>' +
      '<div class="muted">Width now <strong id="w">0</strong></div><button id="z4" type="button">Check 400%</button><button id="z2" type="button">Check 200%</button></div>' +
      '<div class="sec"><div><strong>This screen</strong></div><div id="list"></div><button class="sm" id="hide" type="button">Hide Boxes</button><button class="sm" id="sr" type="button">Screen Reader View</button></div>' +
      '<div class="sec"><div class="muted" id="saved"></div><button class="pri" id="copy" type="button">Copy Report</button><button id="open" type="button">Open Report</button>' +
      '<button class="sm" id="clear" type="button">Clear All</button></div><div class="st" id="st" role="status"></div></div></div>';
    el.status = $('st'); el.list = $('list'); el.saved = $('saved'); el.width = $('w');
    var info = A.screenInfo();
    refreshFields();
    function showMode() {
      var on = autoOn();
      $('auto').textContent = on ? 'Pause Auto Testing' : 'Resume Auto Testing';
      $('mode').textContent = on ? 'Auto testing is on. Just use the app and each new screen is tested on its own. If the whole page reloads, press F12, then Ctrl+P, type !A11y and press Enter.' : 'Auto testing is paused. Click Test Again to test this screen.';
    }
    $('auto').addEventListener('click', function () { setAuto(!autoOn()); showMode(); if (autoOn()) A.snip.autoCheck(false); });
    showMode();
    $('test').addEventListener('click', function () {
      status('Checking this screen...');
      setTimeout(function () {
        var list = A.snip.testScreen($('nm').value.trim() || info.name, $('how').value.trim());
        var n = list.filter(function (f) { return f.rule !== 'tool-error'; }).length;
        renderList();
        status('Done. ' + n + ' possible issue(s) on this screen. Next, run the zoom checks, or go to another screen and run the snippet again.');
      }, 50);
    });
    function zoom(level) {
      status('Checking ' + level + '% zoom...');
      setTimeout(function () {
        var r = A.snip.checkZoom(level);
        if (r && r.tooWide) { status('The width is ' + r.width + '. Keep pressing Ctrl and + until it is ' + (level === 400 ? '320' : '640') + ' or less. If it will not go that low, make the window narrower.'); return; }
        renderList();
        status('Done. Press Ctrl and 0 to go back to normal size.');
      }, 50);
    }
    $('z4').addEventListener('click', function () { zoom(400); });
    $('z2').addEventListener('click', function () { zoom(200); });
    $('hide').addEventListener('click', function () { A.clearOverlays(); status(''); });
    $('sr').addEventListener('click', function () {
      var lines = A.snip.transcript();
      var w = window.open('', '_blank');
      if (!w) { status('The browser blocked the new tab. Allow popups for this site and try again.'); return; }
      w.document.open();
      w.document.write('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Screen Reader View</title></head><body style="font:15px/1.5 Segoe UI,Arial,sans-serif;margin:24px;max-width:900px">' +
        '<h1 style="color:#0A3470">What a screen reader would say</h1><p>' + esc(document.title) + '. Lines in red would be heard as a blank.</p><ol>' +
        lines.map(function (l) { return '<li' + (/NO NAME|NO DESCRIPTION/.test(l) ? ' style="color:#B00020;font-weight:600"' : '') + '>' + esc(l) + '</li>'; }).join('') + '</ol></body></html>');
      w.document.close();
    });
    $('copy').addEventListener('click', function () {
      copyReport(function (ok) {
        status(ok ? 'Report copied. Open a blank Word document and press Ctrl and V.' : 'Copy was blocked here. Use Open Report, then press Ctrl and A, Ctrl and C, and paste into Word.');
      });
    });
    $('open').addEventListener('click', function () { if (!openReport()) status('The browser blocked the new tab. Allow popups for this site and try again.'); });
    $('clear').addEventListener('click', function () {
      if ($('clear').getAttribute('data-sure') !== '1') { $('clear').setAttribute('data-sure', '1'); $('clear').textContent = 'Click again to clear'; return; }
      A.snip.clear(); $('clear').removeAttribute('data-sure'); $('clear').textContent = 'Clear All'; lastKey = null; refreshFields(); renderList(); status('All saved screens and recorded clicks cleared.');
    });
    $('min').addEventListener('click', function () { root.querySelector('.p').classList.toggle('min'); });
    $('close').addEventListener('click', function () { A.clearOverlays(); host.remove(); root = null; window.removeEventListener('resize', updateWidth); });
    window.addEventListener('resize', updateWidth);
    document.documentElement.appendChild(host);
    updateWidth();
    renderList();
    attachRecorder();
    startWatcher();
    lastKey = null;
    if (autoOn()) setTimeout(function () { A.snip.autoCheck(false); }, 300);
    else status('Auto testing is paused.');
  }
  function refreshFields() {
    if (!root) return;
    var s = currentScreen(load(), false), info = A.screenInfo();
    root.getElementById('nm').value = s ? s.name : info.name;
    root.getElementById('how').value = s ? (s.how || '') : A.snip.directions();
  }

  A.snip.showPanel = build;
  if (!window.__a11ySnippetNoPanel) build();
})();
