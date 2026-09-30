import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const scriptRoot = new URL('../../App/YouTube Player/', import.meta.url);
function script(file, name) {
    const source = readFileSync(new URL(file, scriptRoot), 'utf8');
    const body = source.split(`static let ${name} = """`)[1].split('"""')[0];
    return body.replaceAll('\\(pipMessageHandlerName)', 'ytPiP');
}
const policy = script('YouTubePlayerScripts+Policy.swift', 'playbackPolicy');
const context = vm.createContext({ URLSearchParams });
vm.runInContext('window = globalThis;', context);
vm.runInContext(policy, context);
vm.runInContext(`var ytcfg = {
    data_: {}, d() { return this.data_; },
    set(key, value) {
        if (arguments.length > 1) this.data_[key] = value;
        else Object.assign(this.data_, key);
        return 42;
    }
};`, context);
const config = {
    EXPERIMENT_FLAGS: { unrelated: true },
    WEB_PLAYER_CONTEXT_CONFIGS: {
        watch: { serializedExperimentFlags: 'unrelated=hello%20world&uniplayer_block_pip=true' }
    }
};
context.input = config;
assert.equal(vm.runInContext('ytcfg.set(input)', context), 42);
let flags = new URLSearchParams(config.WEB_PLAYER_CONTEXT_CONFIGS.watch.serializedExperimentFlags);
assert.equal(flags.get('unrelated'), 'hello world');
assert.equal(flags.get('mweb_allow_background_playback'), 'true');
assert.equal(flags.get('uniplayer_block_pip'), 'false');
assert.equal(config.EXPERIMENT_FLAGS.unrelated, true);
vm.runInContext(`ytcfg.set('WEB_PLAYER_CONTEXT_CONFIGS', {
    next: {serializedExperimentFlags: 'html5_picture_in_picture_blocking_ontimeupdate=true'}
});`, context);
assert.equal(vm.runInContext(`new URLSearchParams(ytcfg.d().WEB_PLAYER_CONTEXT_CONFIGS.next
    .serializedExperimentFlags).get('html5_picture_in_picture_blocking_ontimeupdate')`, context), 'false');
if (process.argv[2]) {
    const html = readFileSync(process.argv[2], 'utf8');
    const start = html.indexOf('var ytcfg=');
    const end = html.indexOf('</script>', start);
    const inline = html.slice(start, end);
    // Replay only the configuration bootstrap and JSON setter, never load media or remote code.
    const setter = inline.indexOf('ytcfg.set(');
    const jsonStart = setter + 'ytcfg.set('.length;
    let configEnd = jsonStart;
    for (; configEnd < inline.length; configEnd++) {
        if (inline.slice(configEnd, configEnd + 2) !== ');') continue;
        try { JSON.parse(inline.slice(jsonStart, configEnd)); break; } catch {}
    }
    vm.runInContext(inline.slice(0, configEnd + 2), context);
    const contexts = vm.runInContext('ytcfg.d().WEB_PLAYER_CONTEXT_CONFIGS', context);
    assert.ok(Object.keys(contexts).length > 0);
    for (const playerConfig of Object.values(contexts)) {
        flags = new URLSearchParams(playerConfig.serializedExperimentFlags);
        assert.equal(flags.get('mweb_allow_background_playback'), 'true');
        assert.equal(flags.get('uniplayer_block_pip'), 'false');
    }
    console.log('Downloaded iOS configuration bootstrap passed');
}

class Video extends EventTarget {
    paused = true;
    ended = false;
    webkitPresentationMode = 'inline';
    play() { this.paused = false; this.dispatchEvent(new Event('play')); return Promise.resolve(); }
    pause() { this.paused = true; this.dispatchEvent(new Event('pause')); }
}
const video = new Video();
const document = new EventTarget();
document.visibilityState = 'visible';
document.querySelectorAll = () => [video];
document.querySelector = () => video;
let playerState = 2;
let playerCalls = 0;
document.getElementById = () => ({
    getPlayerState: () => playerState,
    playVideo() { playerCalls++; playerState = 1; video.play(); },
    pauseVideo() { playerCalls++; playerState = 2; video.pause(); }
});
const handlers = {};
const messages = [];
let timerCount = 0;
let observerTarget;
const playbackContext = vm.createContext({
    document, HTMLMediaElement: Video, HTMLVideoElement: Video, EventTarget,
    navigator: { mediaSession: { setActionHandler(action, handler) { handlers[action] = handler; } } },
    MutationObserver: class { observe(target) { observerTarget = target; } },
    setTimeout() { timerCount++; },
    webkit: { messageHandlers: { ytPiP: { postMessage(message) { messages.push(message); } } } }
});
vm.runInContext('window = globalThis;', playbackContext);
const originalAdd = EventTarget.prototype.addEventListener;
vm.runInContext(script('YouTubePlayerScripts.swift', 'mediaIsolationBootstrap'), playbackContext);
assert.equal(observerTarget, document, 'observer works before documentElement exists');
assert.equal(EventTarget.prototype.addEventListener, originalAdd);
vm.runInContext(script('YouTubePlayerScripts+MediaSession.swift', 'mediaSessionUserActionBridge'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+PiP.swift', 'pipEventBridge'), playbackContext);
video.webkitPresentationMode = 'picture-in-picture';
video.dispatchEvent(new Event('webkitpresentationmodechanged'));
video.dispatchEvent(new Event('enterpictureinpicture'));
assert.deepEqual(messages, ['enter']);
video.play();
assert.equal(playerState, 1);
video.pause();
assert.equal(playerState, 2);
handlers.play({ action: 'play' });
handlers.pause({ action: 'pause' });
assert.equal(video.paused, true, 'immediate user pause is never suppressed');
assert.equal(playbackContext.__yt.userPaused, true);
assert.equal(playerCalls, 4, 'one player synchronization per transition');
video.webkitPresentationMode = 'fullscreen';
video.dispatchEvent(new Event('webkitpresentationmodechanged'));
video.dispatchEvent(new Event('leavepictureinpicture'));
assert.deepEqual(messages, ['enter', 'leave']);
assert.equal(playbackContext.__yt.exitedPiPRecently, true);
vm.runInContext(script('YouTubePlayerScripts+UserActivity.swift', 'inactivitySuppressor'), playbackContext);
assert.equal(timerCount, 0, 'initialization and playback transitions do not schedule timers');
let visibilityEvents = 0;
document.addEventListener('visibilitychange', () => visibilityEvents++);
document.visibilityState = 'hidden';
document.dispatchEvent(new Event('visibilitychange'));
assert.equal(visibilityEvents, 1);
assert.equal(playbackContext.__yt.realVisibilityState(), 'hidden');
vm.runInContext(`__yt.setPiPActionHandler(() => 'native');
    navigator.mediaSession.setActionHandler('enterpictureinpicture', () => 'page');`, playbackContext);
assert.equal(handlers.enterpictureinpicture(), 'native');
vm.runInContext(`navigator.mediaSession.setActionHandler('pause', () => { window.pauseCalls = 1; });`,
    playbackContext);
handlers.pause({ action: 'pause' });
assert.equal(playbackContext.pauseCalls, 1);
assert.equal(playbackContext.__yt.userPaused, true);
console.log('Policy, PiP, Media Session, lifecycle and idle-timer checks passed');
