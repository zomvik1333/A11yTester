/* Module 3. Screen reader checks, built on the accessibility tree the browser gives to NVDA and JAWS. */
(function () {
  var A = window.__a11y;
  var CONTROL = { button: 'Button', link: 'Link', textbox: 'Edit', searchbox: 'Edit', combobox: 'Combo box', listbox: 'List box', checkbox: 'Check box', radio: 'Radio button', 'switch': 'Switch', menuitem: 'Menu item', menuitemcheckbox: 'Menu item', menuitemradio: 'Menu item', tab: 'Tab', slider: 'Slider', spinbutton: 'Spin button', treeitem: 'Tree item', option: 'Option', PopUpButton: 'Button', ToggleButton: 'Toggle button' };
  var FIELD = { textbox: 1, searchbox: 1, combobox: 1, listbox: 1, slider: 1, spinbutton: 1 };
  var LANDMARK = { main: 'Main region', navigation: 'Navigation region', banner: 'Banner region', contentinfo: 'Content info region', complementary: 'Complementary region', search: 'Search region', form: 'Form region', region: 'Region' };
  var NAME_FROM_CONTENT = { link: 1, button: 1, heading: 1, menuitem: 1, tab: 1, option: 1, columnheader: 1, rowheader: 1, cell: 1, gridcell: 1, checkbox: 1, radio: 1, 'switch': 1, treeitem: 1, PopUpButton: 1, ToggleButton: 1, LabelText: 1, legend: 1 };
  var SKIP_ROLES = { generic: 1, none: 1, presentation: 1, InlineTextBox: 1, LineBreak: 1, paragraph: 1, Section: 1, group: 1, LayoutTable: 1, LayoutTableRow: 1, LayoutTableCell: 1, Div: 1, Pre: 1, Abbr: 1, Mark: 1, Ruby: 1, Canvas: 1, superscript: 1, subscript: 1, emphasis: 1, strong: 1, time: 1, code: 1, ListMarker: 1, rowgroup: 1, row: 1, ignored: 1, Iframe: 0 };

  function val(o) { return o && o.value != null ? o.value : ''; }

  A.setAx = function (msg) {
    var nodes = (msg && msg.result && msg.result.nodes) || [];
    var byId = new Map();
    nodes.forEach(function (n) {
      var p = {};
      (n.properties || []).forEach(function (pp) { p[pp.name] = pp.value ? pp.value.value : undefined; });
      byId.set(n.nodeId, { id: n.nodeId, role: val(n.role), name: A.clean(val(n.name)), ignored: !!n.ignored, b: n.backendDOMNodeId, kids: n.childIds || [], p: p, parent: n.parentId });
    });
    A.ax = { byId: byId, root: nodes.length ? nodes[0].nodeId : null };
    var want = [];
    byId.forEach(function (n) {
      if (n.ignored || !n.b) return;
      if (CONTROL[n.role] || n.role === 'image' || n.role === 'img') want.push(n.b);
    });
    return want.slice(0, 1500);
  };

  function ancestorRole(n, set) {
    var cur = A.ax.byId.get(n.parent), d = 0;
    while (cur && d < 12) { if (!cur.ignored && set[cur.role]) return true; cur = A.ax.byId.get(cur.parent); d++; }
    return false;
  }

  function lineFor(n) {
    var r = n.role, name = n.name, p = n.p, bits = [];
    if (r === 'RootWebArea' || r === 'WebArea') return 'Page title, ' + (name || 'no title');
    if (r === 'StaticText') { if (ancestorRole(n, NAME_FROM_CONTENT)) return null; return name || null; }
    if (r === 'heading') return 'Heading level ' + (p.level || '?') + ', ' + (name || '(empty heading)');
    if (r === 'image' || r === 'img') return 'Graphic, ' + (name || '(NO DESCRIPTION)');
    if (LANDMARK[r]) return LANDMARK[r] + (name ? ', ' + name : '');
    if (r === 'list') return 'List with ' + n.kids.filter(function (k) { var c = A.ax.byId.get(k); return c && c.role === 'listitem'; }).length + ' items';
    if (r === 'table' || r === 'grid' || r === 'treegrid') return 'Table' + (name ? ', ' + name : '');
    if (r === 'columnheader' || r === 'rowheader') return (r === 'columnheader' ? 'Column header, ' : 'Row header, ') + (name || '(empty)');
    if (r === 'cell' || r === 'gridcell') return name || null;
    if (r === 'dialog' || r === 'alertdialog') return 'Dialog, ' + (name || '(no name)');
    if (r === 'alert' || r === 'status') return (r === 'alert' ? 'Alert' : 'Status') + (name ? ', ' + name : '');
    if (CONTROL[r]) {
      bits.push(CONTROL[r]);
      bits.push(name || '(NO NAME)');
      if (p.required) bits.push('required');
      if (p.invalid && p.invalid !== 'false') bits.push('invalid entry');
      if (p.checked === 'true' || p.checked === true) bits.push('checked');
      else if (p.checked === 'false' || p.checked === false) bits.push('not checked');
      if (p.expanded === true) bits.push('expanded'); else if (p.expanded === false) bits.push('collapsed');
      if (p.selected === true && r === 'tab') bits.push('selected');
      if (p.disabled) bits.push('unavailable');
      if (p.haspopup && p.haspopup !== 'false') bits.push('has popup');
      return bits.join(', ');
    }
    return null;
  }

  A.transcript = function () {
    if (!A.ax || A.ax.root == null) return [];
    var lines = [], stack = [A.ax.root], guard = 0;
    while (stack.length && guard++ < 20000) {
      var id = stack.pop(), n = A.ax.byId.get(id);
      if (!n) continue;
      if (!n.ignored && !SKIP_ROLES[n.role]) {
        var l = lineFor(n);
        if (l) lines.push(A.short(l, 160));
      }
      for (var i = n.kids.length - 1; i >= 0; i--) stack.push(n.kids[i]);
    }
    var out = [];
    lines.forEach(function (l) { if (out[out.length - 1] !== l) out.push(l); });
    return out.slice(0, 1500);
  };

  function el(n) {
    if (!n) return null;
    if (n.el) return n.el;
    return n.b ? document.querySelector('[data-a11y-ax="' + n.b + '"]') : null;
  }
  function norm(t) { return A.clean(t).toLowerCase().replace(/[^a-z0-9 ]/g, ''); }

  A.srChecks = function () {
    var F = [];
    if (!A.ax) return F;
    var unnamed = 0, noLabel = 0, place = 0, req = 0, lin = 0, imgs = 0, badAlt = 0;
    var vague = {};
    var headings = [];
    var landmarks = {};
    A.ax.byId.forEach(function (n) {
      if (n.ignored) return;
      if (n.role === 'heading') headings.push(n);
      if (LANDMARK[n.role]) landmarks[n.role] = true;
      var e = el(n);
      if (!e || !A.visible(e)) return;
      if (CONTROL[n.role]) {
        if (!n.name) {
          if (FIELD[n.role]) { if (noLabel++ < 5) F.push(A.finding('sr-no-label', 'High', 'confirmed', { name: A.describe(e) }, e, A.selector(e) + ' has no accessible name. Use <label for> or aria-label.')); }
          else if (unnamed++ < 5) F.push(A.finding('sr-unnamed', 'High', 'confirmed', { role: CONTROL[n.role].toLowerCase(), name: A.describe(e) }, e, A.selector(e) + ' has no accessible name. Add visible text or aria-label.'));
          return;
        }
        if (FIELD[n.role] || n.role === 'checkbox' || n.role === 'radio') {
          var ph = e.getAttribute('placeholder');
          var hasLabel = (e.labels && e.labels.length) || e.getAttribute('aria-label') || e.getAttribute('aria-labelledby') || e.getAttribute('title');
          if (ph && !hasLabel && norm(n.name) === norm(ph) && place++ < 3) {
            F.push(A.finding('sr-placeholder', 'Medium', 'confirmed', { name: n.name }, e, A.selector(e) + ' uses only a placeholder for its label. Add a visible <label for>.'));
          }
          var labelText = e.labels && e.labels.length ? e.labels[0].innerText : '';
          var looksReq = /\*|required/i.test(labelText || '') || /\*\s*$/.test(n.name);
          if (looksReq && !n.p.required && !e.required && e.getAttribute('aria-required') !== 'true' && req++ < 5) {
            F.push(A.finding('sr-required', 'Medium', 'confirmed', { name: A.short(n.name.replace(/\*/g, ''), 40) }, e, A.selector(e) + ' looks required but has no required or aria-required="true".'));
          }
        }
        if (n.role === 'link' || n.role === 'button' || n.role === 'menuitem' || n.role === 'tab') {
          var vt = A.clean(e.innerText || (e.tagName === 'INPUT' ? e.value : ''));
          if (vt && vt.length >= 2 && vt.length <= 60 && /[a-z]{2}/i.test(vt) && norm(n.name).indexOf(norm(vt)) < 0 && lin++ < 4) {
            F.push(A.finding('sr-label-in-name', 'Medium', 'confirmed', { visible: A.short(vt, 40), spoken: A.short(n.name, 40) }, e,
              A.selector(e) + ' accessible name "' + A.short(n.name, 40) + '" does not include its visible text "' + A.short(vt, 40) + '".'));
          }
          if (/^(click here|here|more|read more|learn more|view|details|view details|link|go|open|click|this|select|edit)$/i.test(n.name.replace(/[.>\u00bb]+$/, ''))) {
            var key = n.name.toLowerCase();
            vague[key] = vague[key] || { name: n.name, els: [], hrefs: new Set() };
            vague[key].els.push(e);
            vague[key].hrefs.add(e.getAttribute('href') || e.outerHTML.slice(0, 80));
          }
        }
      }
      if (n.role === 'image' || n.role === 'img') {
        if (!n.name) { if (imgs++ < 5) F.push(A.finding('sr-img-noalt', 'High', 'confirmed', {}, e, A.selector(e) + ' needs alt text, or alt="" if it is decorative.')); }
        else if ((/\.(png|jpe?g|gif|svg|webp|bmp)$/i.test(n.name) || /^(image|img|photo|picture|graphic|icon|spacer|logo|untitled|banner)$/i.test(n.name)) && badAlt++ < 5) {
          F.push(A.finding('sr-img-badalt', 'Medium', 'confirmed', { alt: n.name }, e, A.selector(e) + ' has alt="' + n.name + '". Describe what the image shows.'));
        }
      }
    });
    Object.keys(vague).forEach(function (k) {
      var v = vague[k];
      if (v.els.length >= 2 && v.hrefs.size >= 2) F.push(A.finding('sr-vague', 'Low', 'confirmed', { name: v.name, count: v.els.length }, v.els.slice(0, 4), 'Make each link name unique, or add aria-label like "View details for {item}".'));
    });

    // Headings
    var levels = headings.map(function (h) { return parseInt(h.p.level, 10) || 0; });
    if (levels.indexOf(1) < 0) F.push(A.finding('sr-no-h1', 'Medium', 'confirmed', {}, [], 'Add one <h1> naming the screen.'));
    for (var i = 1; i < levels.length; i++) {
      if (levels[i] > levels[i - 1] + 1) {
        F.push(A.finding('sr-heading-skip', 'Low', 'confirmed', { from: levels[i - 1], to: levels[i], text: A.short(headings[i].name, 40) }, [], 'Heading levels jump from h' + levels[i - 1] + ' to h' + levels[i] + '.'));
        break;
      }
    }
    var fake = [];
    var bodyFont = parseFloat(getComputedStyle(document.body).fontSize) || 16;
    var cands = document.body.querySelectorAll('div,span,p,b,strong,label,td,legend');
    for (var c = 0; c < cands.length && fake.length < 4; c++) {
      var e = cands[c];
      if (!A.visible(e)) continue;
      var t = A.clean(Array.prototype.filter.call(e.childNodes, function (x) { return x.nodeType === 3; }).map(function (x) { return x.nodeValue; }).join(' '));
      if (t.length < 3 || t.length > 60 || !/[A-Za-z]{3}/.test(t)) continue;
      if (e.closest('h1,h2,h3,h4,h5,h6,[role=heading],a,button,label,th,legend,caption,summary,[role=button],[role=link],[role=tab],[role=menuitem],nav,[role=navigation],header,footer,li,dt,option,select')) continue;
      var s = getComputedStyle(e);
      var weight = parseInt(s.fontWeight, 10) || (s.fontWeight === 'bold' ? 700 : 400);
      var size = parseFloat(s.fontSize) || bodyFont;
      var caps = t === t.toUpperCase() && /[A-Z]{3}/.test(t);
      if (s.display.indexOf('inline') === 0 && e.parentElement && A.clean(e.parentElement.innerText).length > t.length + 5) continue;
      if ((weight >= 600 && (caps || size >= bodyFont * 1.2)) || size >= bodyFont * 1.5) fake.push(e);
    }
    if (fake.length) F.push(A.finding('sr-fake-heading', 'Low', 'check', { text: fake.slice(0, 3).map(function (e) { return '"' + A.short(e.innerText, 30) + '"'; }).join(', ') }, fake,
      'Code section titles as headings, e.g. <h2>, instead of bold text. ' + A.selector(fake[0])));

    // Landmarks
    var missing = [];
    if (!landmarks.main) missing.push('main content');
    if (!landmarks.navigation && document.querySelectorAll('a[href]').length > 5) missing.push('menu');
    if (!landmarks.banner) missing.push('header');
    if (missing.length) F.push(A.finding('sr-landmarks', landmarks.main ? 'Low' : 'Medium', 'confirmed', { regions: missing.join(', ') }, [], 'Use <header>, <nav>, <main> and <footer> instead of plain <div> wrappers.'));

    // Tables without headers
    var tbls = Array.prototype.filter.call(document.querySelectorAll('table,[role=grid],[role=table]'), function (t) {
      if (!A.visible(t) || /^(presentation|none)$/.test(t.getAttribute('role') || '')) return false;
      var rows = t.querySelectorAll('tr,[role=row]');
      if (rows.length < 2) return false;
      var cols = Math.max.apply(null, Array.prototype.map.call(rows, function (r) { return r.children.length; }));
      if (cols < 2) return false;
      return !t.querySelector('th,[role=columnheader],[role=rowheader]');
    });
    tbls.slice(0, 3).forEach(function (t) {
      var cap = t.querySelector('caption');
      F.push(A.finding('sr-table-headers', 'Medium', 'confirmed', { table: cap ? '"' + A.short(cap.innerText, 40) + '"' : 'on this screen' }, t, A.selector(t) + ' has no <th> header cells. Mark the header row with <th scope="col">.'));
    });

    // Reading order versus visual order
    var blocks = [];
    A.textElements().forEach(function (e) {
      if (blocks.length > 800 || !A.visible(e)) return;
      var r = A.textRect(e); if (!r) return;
      if (getComputedStyle(e).position === 'fixed') return;
      blocks.push({ e: e, r: r });
    });
    var inv = [];
    for (var b = 1; b < blocks.length && inv.length < 2; b++) {
      var pa = blocks[b - 1], cu = blocks[b];
      var ox = Math.min(pa.r.right, cu.r.right) - Math.max(pa.r.left, cu.r.left);
      var narrow = Math.min(pa.r.right - pa.r.left, cu.r.right - cu.r.left);
      if (cu.r.bottom < pa.r.top - 40 && ox > narrow * 0.5) {
        var pc = pa.e.closest('[role=dialog],dialog,nav,header'), cc = cu.e.closest('[role=dialog],dialog,nav,header');
        if (pc !== cc) continue;
        inv.push([pa.e, cu.e]);
      }
    }
    if (inv.length) F.push(A.finding('sr-reading-order', 'Medium', 'check', { a: A.short(inv[0][0].innerText, 40), b: A.short(inv[0][1].innerText, 40) }, inv[0],
      'Source order differs from visual order near ' + A.selector(inv[0][1]) + '. Check CSS order, flex-direction reverse or absolute positioning.'));

    if (!A.clean(document.title)) F.push(A.finding('sr-no-title', 'Medium', 'confirmed', {}, [], 'Set a unique <title> for this screen.'));
    if (!document.documentElement.getAttribute('lang')) F.push(A.finding('sr-no-lang', 'Medium', 'confirmed', {}, [], 'Add lang="en" to the <html> element.'));

    var hidFocus = Array.prototype.filter.call(document.querySelectorAll('[aria-hidden=true] a[href],[aria-hidden=true] button,[aria-hidden=true] input,[aria-hidden=true] select,[aria-hidden=true] textarea,[aria-hidden=true] [tabindex]:not([tabindex^="-"])'), function (e) { return A.visible(e) && !e.disabled; });
    hidFocus.slice(0, 3).forEach(function (e) {
      F.push(A.finding('sr-hidden-focusable', 'Medium', 'confirmed', { name: A.describe(e) }, e, A.selector(e) + ' is inside aria-hidden="true" but can still receive focus.'));
    });

    // Target size (2.5.8)
    var targets = A.interactive().filter(function (e) { return !/^(INPUT)$/.test(e.tagName) || /^(checkbox|radio|button|submit|reset|image)$/i.test(e.type); });
    var rects = targets.map(function (e) { return e.getBoundingClientRect(); });
    var small = [];
    targets.forEach(function (e, idx) {
      var r = rects[idx];
      if (r.width >= 24 && r.height >= 24) return;
      if (e.tagName === 'A' && e.parentElement && A.clean(e.parentElement.innerText).length > A.clean(e.innerText).length + 15) return;
      if (e.closest('[role=grid],table')) return;
      var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      var crowded = rects.some(function (o, j) {
        if (j === idx) return false;
        var dx = Math.max(o.left - cx, 0, cx - o.right), dy = Math.max(o.top - cy, 0, cy - o.bottom);
        return Math.sqrt(dx * dx + dy * dy) < 12;
      });
      if (crowded) small.push(e);
    });
    if (small.length) {
      var e0 = small[0], r0 = e0.getBoundingClientRect();
      F.push(A.finding('vis-target-size', 'Low', 'confirmed', { name: A.describe(e0), w: Math.round(r0.width), h: Math.round(r0.height), count: small.length }, small.slice(0, 5),
        small.length + ' click target(s) under 24 by 24 px with neighbours too close, e.g. ' + A.selector(e0) + '.'));
    }

    // Instructions that rely on color, shape or position
    var txt = document.body.innerText || '';
    var m = txt.match(/[^.\n]{0,60}\b(click|press|select|tap|use|see|fields?)\b[^.\n]{0,30}\b(red|green|blue|yellow|orange|grey|gray|round|square|circle|on the (left|right)|to the (left|right)|below in red|in red)\b[^.\n]{0,40}/i);
    if (m) F.push(A.finding('vis-sensory', 'Low', 'check', { quote: A.short(m[0], 90) }, [], 'Instruction text refers to color, shape or position only.'));
    return F;
  };
})();
