extension PetalElementPickerWebView {

    /// JS that highlights tapped elements and bridges selection to Swift.
    static let injectionJS = #"""
    (function () {
      var style = document.createElement('style');
      style.textContent =
        '*, *::before, *::after {' +
        '  -webkit-tap-highlight-color: transparent !important;' +
        '  -webkit-touch-callout: none !important;' +
        '  -webkit-user-select: none !important;' +
        '  user-select: none !important;' +
        '  pointer-events: auto !important;' +
        '}' +
        '.petal-tap { outline: 3px solid rgba(255,59,48,0.8) !important; outline-offset: 1px !important; }';
      document.head.appendChild(style);

      document.addEventListener('contextmenu', function (e) {
        e.preventDefault();
      }, true);

      function cssEscape(v) {
        return (typeof CSS !== 'undefined' && CSS.escape)
          ? CSS.escape(v) : v.replace(/([^\w-])/g, '\\$1');
      }

      function compact(el) {
        var tag = el.tagName.toLowerCase();
        var id = el.getAttribute('id');
        if (id) return '#' + cssEscape(id);
        var cls = null;
        el.classList.forEach(function (c) {
          if (!cls && c.indexOf('petal-') !== 0) cls = c;
        });
        return cls ? tag + '.' + cls : tag;
      }

      function isInvisibleOverlay(el) {
        if (!el || el === document.body || el === document.documentElement) return true;
        var textContent = (el.textContent || '').trim();
        var innerText = (el.innerText || '').trim();
        if (textContent.length > 0 && innerText.length === 0) return true;
        if (!textContent && !el.querySelector('img, svg, video, canvas, picture')) {
          return true;
        }
        return false;
      }

      function pickThroughOverlays(x, y, startEl) {
        if (!isInvisibleOverlay(startEl)) return startEl;
        var stack = document.elementsFromPoint(x, y);
        for (var i = 0; i < stack.length; i++) {
          if (!isInvisibleOverlay(stack[i])) return stack[i];
        }
        return startEl;
      }

      function summarize(el) {
        var text = (el.innerText || el.textContent || '').trim()
          .replace(/\s+/g, ' ').substring(0, 80);
        return {
          selector: compact(el),
          text: text,
          tag: el.tagName.toLowerCase()
        };
      }

      function ancestorsOf(el) {
        var out = [];
        var cur = el.parentElement;
        while (cur && cur !== document.body && cur !== document.documentElement) {
          out.push(summarize(cur));
          cur = cur.parentElement;
        }
        return out;
      }

      function visibleChildren(el) {
        var out = [];
        var kids = el.children;
        for (var i = 0; i < kids.length; i++) {
          if (!isInvisibleOverlay(kids[i])) out.push(kids[i]);
        }
        return out;
      }

      var selected = null;

      function select(el) {
        if (!el || el === document.body || el === document.documentElement) return;
        if (selected) selected.classList.remove('petal-tap');
        selected = el;
        el.classList.add('petal-tap');
        try {
          el.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' });
        } catch (_) { /* older WebKit */ }
        window.webkit.messageHandlers.elementPicked.postMessage({
          selected: summarize(el),
          ancestors: ancestorsOf(el),
          children: visibleChildren(el).map(summarize)
        });
      }

      document.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();
        var el = pickThroughOverlays(e.clientX, e.clientY, e.target);
        select(el);
      }, true);

      window.petalSelectAncestor = function (levelsUp) {
        if (!selected) return;
        var el = selected;
        for (var i = 0; i < levelsUp; i++) {
          if (!el.parentElement) return;
          el = el.parentElement;
        }
        if (el === document.body || el === document.documentElement) return;
        select(el);
      };

      window.petalSelectChild = function (index) {
        if (!selected) return;
        var kids = visibleChildren(selected);
        if (index < 0 || index >= kids.length) return;
        select(kids[index]);
      };
    })();
    """#
}
