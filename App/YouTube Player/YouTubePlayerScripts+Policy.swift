import Foundation

extension YouTubePlayerScripts {
    static let playbackPolicy = """
    (function() {
        var overrides = {
            mweb_allow_background_playback: true,
            uniplayer_block_pip: false,
            html5_picture_in_picture_blocking_onresize: false,
            html5_picture_in_picture_blocking_ontimeupdate: false,
            html5_picture_in_picture_blocking_document_fullscreen: false,
            html5_picture_in_picture_blocking_standard_api: false
        };
        function patchConfig(config) {
            if (!config || typeof config !== 'object') return;
            if (config.EXPERIMENT_FLAGS) Object.assign(config.EXPERIMENT_FLAGS, overrides);
            var contexts = config.WEB_PLAYER_CONTEXT_CONFIGS;
            if (!contexts) return;
            Object.values(contexts).forEach(function(context) {
                if (!context || typeof context !== 'object') return;
                var flags = new URLSearchParams(context.serializedExperimentFlags || '');
                Object.keys(overrides).forEach(function(name) {
                    flags.set(name, String(overrides[name]));
                });
                context.serializedExperimentFlags = flags.toString();
            });
        }
        var installed = new WeakSet();
        function install(config) {
            if (!config || typeof config.set !== 'function' || installed.has(config)) return;
            installed.add(config);
            var originalSet = config.set;
            config.set = function(key, value) {
                var incoming = arguments.length > 1 ? { [key]: value } : key;
                patchConfig(incoming);
                return originalSet.apply(this, arguments);
            };
            if (typeof config.d === 'function') patchConfig(config.d());
        }
        // The mobile page assigns ytcfg immediately before its first synchronous set().
        var currentConfig = window.ytcfg;
        Object.defineProperty(window, 'ytcfg', {
            configurable: true,
            enumerable: true,
            get: function() { return currentConfig; },
            set: function(config) { currentConfig = config; install(config); }
        });
        install(currentConfig);
    })();
    """
}
