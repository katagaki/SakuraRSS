import Foundation

extension YouTubePlayerStyles {

    static func injectionScript(css: String) -> String {
        // Escape characters that would break out of the JS template literal.
        let safeCSS = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return """
        (function() {
            function log(msg) {
                try {
                    window.webkit.messageHandlers.ytDebug.postMessage(String(msg));
                } catch (e) {}
            }
            try {
                var cssText = `\(safeCSS)`;
                log('inject script start, head=' + !!document.head + ' doc=' + !!document.documentElement);
                function inject() {
                    if (document.getElementById('app-yt-style')) return;
                    var parent = document.head || document.documentElement;
                    if (!parent) { log('inject: no parent'); return; }
                    var s = document.createElement('style');
                    s.id = 'app-yt-style';
                    s.textContent = cssText;
                    parent.appendChild(s);
                    log('inject: appended style len=' + cssText.length + ' parent=' + parent.tagName);
                }
                inject();
                var observer = new MutationObserver(inject);
                if (document.documentElement) {
                    observer.observe(document.documentElement, { childList: true, subtree: true });
                    log('observer attached');
                } else {
                    log('no documentElement for observer');
                }
            } catch (e) {
                log('inject error: ' + e.message + ' stack=' + (e.stack || ''));
            }
        })();
        """
    }
}
