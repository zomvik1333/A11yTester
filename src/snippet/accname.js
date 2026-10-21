/* Builds a screen reader view of the page from the page itself, the same shape the
   browser's accessibility tree gives the PowerShell tool, so the same checks can run. */
(function () {
  var A = window.__a11y;
  var ROLE_OK = /^(button|link|textbox|searchbox|combobox|listbox|checkbox|radio|switch|menuitem|menuitemcheckbox|menuitemradio|tab|slider|spinbutton|treeitem|option|heading|img|image|navigation|main|banner|contentinfo|complementary|search|form|region|list|listitem|table|grid|treegrid|row|cell|gridcell|columnheader|rowheader|dialog|alertdialog|alert|status|none|presentation|group|tablist|tabpanel|menu|menubar|toolbar|tree|radiogroup|article|figure|separator|progressbar|log|marquee|timer|note|document|application|math|term|definition|paragraph|generic)$/;
  var FROM_CONTENT = { button: 1, link: 1, heading: 1, menuitem: 1, menuitemcheckbox: 1, menuitemradio: 1, tab: 1, option: 1, cell: 1, gridcell: 1, columnheader: 1, rowheader: 1, checkbox: 1, radio: 1, 'switch': 1, treeitem: 1, listitem: 0, tooltip: 1 };

  function inScope(el) {
    var p = el.parentElement;
    while (p && p !== document.body) {
      if (/^(ARTICLE|ASIDE|MAIN|NAV|SECTION)$/.test(p.tagName) || /^(article|complementary|main|navigation|region)$/.test(p.getAttribute('role') || '')) return true;
      p = p.parentElement;
    }
    return false;
  }

  function implicitRole(el) {
    var t = el.tagName.toLowerCase();
    if (t === 'a' || t === 'area') return el.hasAttribute('href') ? 'link' : 'generic';
    if (t === 'button' || t === 'summary') return 'button';
    if (t === 'input') {
      var ty = (el.getAttribute('type') || 'text').toLowerCase();
      if (/^(button|submit|reset|image)$/.test(ty)) return 'button';
      if (ty === 'checkbox') return 'checkbox';
      if (ty === 'radio') return 'radio';
      if (ty === 'range') return 'slider';
      if (ty === 'number') return 'spinbutton';
      if (ty === 'search') return 'searchbox';
      if (ty === 'hidden') return 'none';
      return 'textbox';
    }
    if (t === 'select') return (el.multiple || el.size > 1) ? 'listbox' : 'combobox';
    if (t === 'textarea') return 'textbox';
    if (t === 'img') { var alt = el.getAttribute('alt'); return alt === '' ? 'none' : 'image'; }
    if (t === 'svg') return 'none';
    if (/^h[1-6]$/.test(t)) return 'heading';
    if (t === 'nav') return 'navigation';
    if (t === 'main') return 'main';
    if (t === 'header') return inScope(el) ? 'generic' : 'banner';
    if (t === 'footer') return inScope(el) ? 'generic' : 'contentinfo';
    if (t === 'aside') return 'complementary';
    if (t === 'form') return 'form';
    if (t === 'section') return (el.getAttribute('aria-label') || el.getAttribute('aria-labelledby')) ? 'region' : 'generic';
    if (t === 'table') return 'table';
    if (t === 'th') return el.getAttribute('scope') === 'row' ? 'rowheader' : 'columnheader';
    if (t === 'td') return 'cell';
    if (t === 'tr') return 'row';
    if (t === 'ul' || t === 'ol' || t === 'menu') return 'list';
    if (t === 'li') return 'listitem';
    if (t === 'dialog') return 'dialog';
    if (t === 'option') return 'option';
    if (t === 'fieldset') return 'group';
    if (t === 'p') return 'paragraph';
    if (t === 'iframe') return 'Iframe';
    return 'generic';
  }

  function roleOf(el) {
    var r = (el.getAttribute('role') || '').trim().split(/\s+/)[0].toLowerCase();
    if (r === 'img') r = 'image';
    if (r && ROLE_OK.test(r)) return r;
    return implicitRole(el);
  }

  function hidden(el) {
    if (el.hidden) return true;
    if (el.getAttribute('aria-hidden') === 'true') return true;
    var s = getComputedStyle(el);
    return s.display === 'none' || s.visibility === 'hidden';
  }

  function textOf(node, depth) {
    if (depth > 20) return '';
    var out = [];
    for (var i = 0; i < node.childNodes.length; i++) {
      var c = node.childNodes[i];
      if (c.nodeType === 3) { out.push(c.nodeValue); continue; }
      if (c.nodeType !== 1 || hidden(c)) continue;
      if (c.getAttribute('aria-label')) { out.push(c.getAttribute('aria-label')); continue; }
      if (c.tagName === 'IMG') { out.push(c.getAttribute('alt') || ''); continue; }
      if (c.tagName === 'INPUT' && /^(button|submit|reset)$/i.test(c.type)) { out.push(c.value); continue; }
      out.push(textOf(c, depth + 1));
    }
    return out.join(' ');
  }

  function byIds(ids) {
    return ids.split(/\s+/).map(function (id) { var e = document.getElementById(id); return e ? (e.getAttribute('aria-label') || textOf(e, 0)) : ''; }).join(' ');
  }

  A.accName = function (el, role) {
    var n = '';
    var lb = el.getAttribute('aria-labelledby');
    if (lb) n = A.clean(byIds(lb));
    if (!n) n = A.clean(el.getAttribute('aria-label') || '');
    if (n) return n;
    var t = el.tagName;
    if (t === 'INPUT' || t === 'SELECT' || t === 'TEXTAREA') {
      if (t === 'INPUT' && /^(button|submit|reset)$/i.test(el.type)) {
        n = el.value || (el.type === 'submit' ? 'Submit' : el.type === 'reset' ? 'Reset' : '');
      } else if (t === 'INPUT' && el.type === 'image') {
        n = el.getAttribute('alt') || el.value || '';
      } else if (el.labels && el.labels.length) {
        n = Array.prototype.map.call(el.labels, function (l) { return textOf(l, 0); }).join(' ');
      }
    } else if (t === 'IMG' || t === 'AREA') {
      n = el.getAttribute('alt') || '';
    } else if (t === 'FIELDSET') {
      var lg = el.querySelector('legend'); n = lg ? textOf(lg, 0) : '';
    } else if (t === 'TABLE') {
      var cap = el.querySelector('caption'); n = cap ? textOf(cap, 0) : '';
    }
    n = A.clean(n);
    if (!n && (FROM_CONTENT[role] || /^H[1-6]$/.test(t))) n = A.clean(textOf(el, 0));
    if (!n) n = A.clean(el.getAttribute('title') || '');
    if (!n && (role === 'textbox' || role === 'searchbox' || role === 'combobox')) n = A.clean(el.getAttribute('placeholder') || '');
    return n;
  };

  A.buildAxFromDom = function () {
    var byId = new Map(), next = 1;
    var root = { id: next++, role: 'RootWebArea', name: A.clean(document.title), ignored: false, kids: [], p: {}, parent: null, el: document.documentElement };
    byId.set(root.id, root);
    function add(parent, node) { node.id = next++; node.parent = parent.id; byId.set(node.id, node); parent.kids.push(node.id); return node; }
    function walk(el, parent, depth) {
      if (depth > 60 || byId.size > 20000) return;
      for (var i = 0; i < el.childNodes.length; i++) {
        var c = el.childNodes[i];
        if (c.nodeType === 3) {
          var tx = A.clean(c.nodeValue);
          if (tx) add(parent, { role: 'StaticText', name: tx, ignored: false, kids: [], p: {} });
          continue;
        }
        if (c.nodeType !== 1) continue;
        if (/^(SCRIPT|STYLE|NOSCRIPT|TEMPLATE|HEAD)$/.test(c.tagName)) continue;
        if (A.isOurs(c) || c.id === '__a11y_toolbar_host') continue;
        if (hidden(c)) continue;
        var role = roleOf(c);
        if (role === 'none' || role === 'presentation') role = 'generic';
        var p = {};
        if (role === 'heading') p.level = parseInt(c.getAttribute('aria-level') || (c.tagName.match(/^H([1-6])$/) || [0, 2])[1], 10);
        if (c.required || c.getAttribute('aria-required') === 'true') p.required = true;
        if (role === 'checkbox' || role === 'radio' || role === 'switch') {
          var ac = c.getAttribute('aria-checked');
          p.checked = ac ? ac : (c.checked ? 'true' : 'false');
        }
        var ex = c.getAttribute('aria-expanded'); if (ex) p.expanded = ex === 'true';
        if (c.getAttribute('aria-invalid') && c.getAttribute('aria-invalid') !== 'false') p.invalid = 'true';
        if (c.disabled || c.getAttribute('aria-disabled') === 'true') p.disabled = true;
        if (c.getAttribute('aria-selected') === 'true') p.selected = true;
        var hp = c.getAttribute('aria-haspopup'); if (hp && hp !== 'false') p.haspopup = hp;
        var name = role === 'generic' || role === 'paragraph' || role === 'list' || role === 'listitem' || role === 'row' ? '' : A.accName(c, role);
        var node = add(parent, { role: role, name: name, ignored: false, kids: [], p: p, el: c });
        if (role === 'image' || /^(INPUT|SELECT|TEXTAREA|IMG)$/.test(c.tagName)) continue;
        walk(c, node, depth + 1);
      }
    }
    if (document.body) walk(document.body, root, 0);
    A.ax = { byId: byId, root: root.id };
    return byId.size;
  };
})();
