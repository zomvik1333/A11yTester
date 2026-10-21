/* Floating toolbar shown in the app while you test. Also records your clicks so the report can give directions. */
(function () {
  try { if (window.top !== window) return; } catch (e) { return; }
  if (window.__a11yTb) return;
  var KEY_CMDS = '__a11yCmds', KEY_TRAIL = '__a11yTrail', KEY_IN = '__a11yLoggedIn';
  var ss = { get: function (k, d) { try { var v = sessionStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { return d; } },
             set: function (k, v) { try { sessionStorage.setItem(k, JSON.stringify(v)); } catch (e) { } } };
  var mem = { cmds: [] };
  function push(cmd) { var q = ss.get(KEY_CMDS, []); q.push(cmd); ss.set(KEY_CMDS, q); mem.cmds.push(cmd); }

  var host, root, statusEl, btnIn, btnTest, btnDone;
  function build() {
    if (host && !host.isConnected && document.documentElement) { document.documentElement.appendChild(host); return; }
    if (host || !document.documentElement) return;
    host = document.createElement('div');
    host.id = '__a11y_toolbar_host';
    host.style.cssText = 'position:fixed;right:16px;bottom:16px;z-index:2147483647;all:initial;position:fixed;right:16px;bottom:16px;z-index:2147483647;';
    root = host.attachShadow({ mode: 'open' });
    root.innerHTML = '<style>' +
      '.bar{font:14px/1.3 "Segoe UI",Arial,sans-serif;background:#fff;color:#111;border:2px solid #0A3470;border-radius:10px;padding:10px 12px;box-shadow:0 4px 16px rgba(0,0,0,.25);max-width:320px}' +
      '.t{font-weight:700;color:#0A3470;margin:0 0 6px}' +
      'button{font:inherit;font-weight:600;border-radius:6px;padding:7px 12px;margin:4px 6px 0 0;cursor:pointer;border:2px solid #0A3470}' +
      'button:focus-visible{outline:3px solid #C49F47;outline-offset:2px}' +
      '.go{background:#1b7f3b;border-color:#1b7f3b;color:#fff}.pri{background:#0A3470;color:#fff}.sec{background:#fff;color:#0A3470}' +
      '.s{margin-top:6px;font-size:13px;color:#333}' +
      '</style><div class="bar" role="region" aria-label="A11y Tester"><p class="t">A11y Tester</p>' +
      '<button class="go" id="in" type="button">I\'m Logged In</button>' +
      '<button class="pri" id="test" type="button">Test This Screen</button>' +
      '<button class="sec" id="done" type="button">Done</button>' +
      '<div class="s" id="s" role="status"></div></div>';
    statusEl = root.getElementById('s');
    btnIn = root.getElementById('in'); btnTest = root.getElementById('test'); btnDone = root.getElementById('done');
    btnIn.addEventListener('click', function () { ss.set(KEY_IN, 1); ss.set(KEY_TRAIL, []); push('loggedin'); refresh(); setStatus('Thanks. Go to a screen and click Test This Screen.'); });
    btnTest.addEventListener('click', function () { push('test'); setStatus('Testing this screen. Please keep your hands off for a moment.'); });
    btnDone.addEventListener('click', function () { push('done'); setStatus('Building your report. You can close this window when it opens.'); });
    document.documentElement.appendChild(host);
    refresh();
  }
  function refresh() {
    if (!host) return;
    var logged = !!ss.get(KEY_IN, 0) || window.__a11yAuto;
    btnIn.style.display = logged ? 'none' : '';
    btnTest.style.display = logged ? '' : 'none';
    btnDone.style.display = logged ? '' : 'none';
    if (!statusEl.textContent) setStatus(logged ? 'Go to a screen and click Test This Screen.' : 'Log in like normal, then click I\'m Logged In.');
  }
  function setStatus(t) { if (statusEl) statusEl.textContent = t; }

  function labelOf(el) {
    var t = el.getAttribute('aria-label') || el.innerText || el.value || el.getAttribute('title') || el.getAttribute('alt') || '';
    if (!t) { var img = el.querySelector && el.querySelector('img[alt]'); if (img) t = img.getAttribute('alt'); }
    t = String(t).replace(/\s+/g, ' ').trim();
    return t.length > 50 ? t.slice(0, 47) + '...' : t;
  }
  function fieldName(el) {
    var t = (el.labels && el.labels.length ? el.labels[0].innerText : '') || el.getAttribute('aria-label') || el.getAttribute('placeholder') || el.name || 'a';
    return String(t).replace(/\s+/g, ' ').replace(/\*/g, '').trim().slice(0, 40);
  }
  function where(el) {
    if (el.closest('[role=tablist]')) return ' tab';
    if (el.closest('nav,[role=navigation],[role=menubar],[role=menu]')) return ' in the menu';
    if (el.closest('header,[role=banner]')) return ' at the top of the screen';
    if (el.closest('[role=dialog],dialog')) return ' in the popup';
    return '';
  }
  function record(step) {
    if (!ss.get(KEY_IN, 0) && !window.__a11yAuto) return;
    var tr = ss.get(KEY_TRAIL, []);
    if (tr.length && tr[tr.length - 1] === step) return;
    tr.push(step); if (tr.length > 40) tr = tr.slice(-40);
    ss.set(KEY_TRAIL, tr);
  }
  document.addEventListener('click', function (ev) {
    var path = ev.composedPath ? ev.composedPath() : [];
    if (host && path.indexOf(host) >= 0) return;
    var el = ev.target && ev.target.closest ? ev.target.closest('a,button,[role=button],[role=link],[role=tab],[role=menuitem],[role=option],[role=treeitem],summary,input[type=button],input[type=submit],input[type=checkbox],input[type=radio],label,[onclick]') : null;
    if (!el) return;
    var name = labelOf(el);
    if (!name) return;
    if (el.matches('input[type=checkbox],input[type=radio]')) record('Tick ' + fieldName(el) + '.');
    else record('Click "' + name + '"' + where(el) + '.');
  }, true);
  document.addEventListener('change', function (ev) {
    var el = ev.target;
    if (!el || !el.matches) return;
    if (el.matches('select')) record('Pick an option in the ' + fieldName(el) + ' dropdown.');
    else if (el.matches('input:not([type=checkbox]):not([type=radio]),textarea')) record('Type in the ' + fieldName(el) + ' box.');
  }, true);

  window.__a11yTb = {
    take: function () { var q = ss.get(KEY_CMDS, []); ss.set(KEY_CMDS, []); var m = mem.cmds; mem.cmds = []; return q.length ? q : m; },
    trail: function () { return ss.get(KEY_TRAIL, []); },
    hide: function () { if (host) host.style.display = 'none'; return true; },
    show: function (msg) { build(); if (host) host.style.display = ''; if (msg) setStatus(msg); refresh(); return true; },
    status: function (msg) { setStatus(msg); return true; },
    loggedIn: function () { return !!ss.get(KEY_IN, 0); }
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
