import Foundation

extension YouTubePlayerScripts {
    static let pageEnvironmentMask = """
    (function() {
        function mask(target, name, value) {
            try {
                Object.defineProperty(target, name, {
                    configurable: true,
                    get: function() { return value; }
                });
            } catch (error) {
                window.__yt.log('environment mask failed ' + name);
            }
        }
        mask(document, 'visibilityState', 'visible');
        mask(document, 'hidden', false);
        mask(document, 'webkitVisibilityState', 'visible');
        mask(document, 'webkitHidden', false);
        mask(document, 'pictureInPictureElement', null);
        mask(HTMLVideoElement.prototype, 'webkitPresentationMode', 'inline');
        try {
            Object.defineProperty(document, 'hasFocus', {
                configurable: true,
                value: function() { return true; }
            });
        } catch (error) {
            window.__yt.log('environment mask failed hasFocus');
        }
        ['visibilitychange', 'webkitvisibilitychange', 'webkitpresentationmodechanged',
            'enterpictureinpicture', 'leavepictureinpicture'].forEach(function(type) {
            window.addEventListener(type, function(event) {
                if (type.indexOf('pictureinpicture') !== -1
                    || type === 'webkitpresentationmodechanged') {
                    if (!(event.target instanceof HTMLVideoElement)) return;
                }
                event.stopImmediatePropagation();
            }, true);
        });
    })();
    """
}
