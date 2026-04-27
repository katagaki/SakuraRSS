import Foundation

enum ReadabilityScript {

    static let messageHandlerName = "sakuraReadability"

    /// Loads `Readability.js` from the bundle so it can be injected at document start.
    static var bundledLibrary: String {
        guard let url = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return source
    }

    /// Runs Readability against the loaded document and replaces it with a clean reader layout.
    static let runScript = """
    (function() {
      if (window.__sakuraReadabilityApplied) { return; }
      function done(payload) {
        try {
          window.webkit.messageHandlers.sakuraReadability.postMessage(payload);
        } catch (e) {}
      }
      function escapeText(value) {
        if (value == null) { return ''; }
        return String(value)
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;');
      }
      try {
        if (typeof Readability !== 'function') {
          done({ ok: false, reason: 'unavailable' });
          return;
        }
        var clone = document.cloneNode(true);
        var parsed = new Readability(clone).parse();
        if (!parsed || !parsed.content) {
          done({ ok: false, reason: 'noContent' });
          return;
        }
        window.__sakuraReadabilityApplied = true;
        var titleHTML = parsed.title ? '<h1 class="reader-title">' + escapeText(parsed.title) + '</h1>' : '';
        var bylineHTML = parsed.byline ? '<p class="reader-byline">' + escapeText(parsed.byline) + '</p>' : '';
        var html = '<!DOCTYPE html><html><head><meta charset="utf-8">'
          + '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">'
          + '<style>'
          + ':root { color-scheme: light dark; }'
          + 'body { font-family: -apple-system, system-ui, sans-serif; margin: 0;'
          + '       padding: 16px 20px 40px; font-size: 17px; line-height: 1.6;'
          + '       -webkit-text-size-adjust: 100%; word-wrap: break-word; }'
          + 'img, video, iframe, svg { max-width: 100%; height: auto; }'
          + 'pre { white-space: pre-wrap; word-break: break-word;'
          + '      background: rgba(127,127,127,0.12); padding: 12px; border-radius: 8px; }'
          + 'code { background: rgba(127,127,127,0.12); padding: 2px 4px; border-radius: 4px; }'
          + 'pre code { background: transparent; padding: 0; }'
          + 'blockquote { margin: 0; padding-left: 1em;'
          + '             border-left: 3px solid rgba(127,127,127,0.4); color: inherit; opacity: 0.85; }'
          + 'figure { margin: 1em 0; }'
          + 'figcaption { font-size: 0.85em; opacity: 0.75; }'
          + 'a { color: #d96380; }'
          + 'h1, h2, h3 { line-height: 1.3; }'
          + 'h1.reader-title { font-size: 1.5em; margin: 0.4em 0 0.2em; }'
          + '.reader-byline { color: gray; font-size: 0.9em; margin: 0 0 1.2em; }'
          + 'table { max-width: 100%; border-collapse: collapse; }'
          + 'td, th { border: 1px solid rgba(127,127,127,0.3); padding: 6px 8px; }'
          + '</style></head><body>'
          + titleHTML + bylineHTML + parsed.content
          + '</body></html>';
        document.open();
        document.write(html);
        document.close();
        done({ ok: true });
      } catch (e) {
        done({ ok: false, reason: 'error', error: String(e) });
      }
    })();
    """
}
