import Foundation

/// Pages read through clearthis.page, shared by the iOS and Mac viewers.
enum ClearThisPageAddress {

    static func url(for articleURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "clearthis.page"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "u", value: articleURL.absoluteString)
        ]
        return components.url
    }

    /// Seeds `localStorage['darkSwitch']` from the system color scheme and keeps it in sync.
    static let themeScript = """
    (function() {
      function isDark() {
        return window.matchMedia
          && window.matchMedia('(prefers-color-scheme: dark)').matches;
      }
      function syncStorage() {
        try {
          if (isDark()) {
            localStorage.setItem('darkSwitch', 'dark');
          } else {
            localStorage.removeItem('darkSwitch');
          }
        } catch (e) {}
      }
      function applyBodyAttribute() {
        if (!document.body) { return; }
        if (isDark()) {
          document.body.setAttribute('data-theme', 'dark');
        } else {
          document.body.removeAttribute('data-theme');
        }
        var sw = document.getElementById('darkSwitch');
        if (sw) { sw.checked = isDark(); }
      }
      function hideToggle() {
        var topbar = document.querySelector('.topbar');
        if (topbar && topbar.parentNode) {
          topbar.parentNode.removeChild(topbar);
        }
      }
      function applyAll() {
        syncStorage();
        applyBodyAttribute();
        hideToggle();
      }
      syncStorage();
      if (document.readyState !== 'loading') {
        applyAll();
      } else {
        document.addEventListener('DOMContentLoaded', applyAll);
      }
      window.addEventListener('load', applyAll);
      if (window.matchMedia) {
        var mq = window.matchMedia('(prefers-color-scheme: dark)');
        var listener = function() { applyAll(); };
        if (mq.addEventListener) {
          mq.addEventListener('change', listener);
        } else if (mq.addListener) {
          mq.addListener(listener);
        }
      }
    })();
    """
}
