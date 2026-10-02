import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const scriptRoot = new URL('../../App/YouTube Player/', import.meta.url);
function script(file, name) {
    const source = readFileSync(new URL(file, scriptRoot), 'utf8');
    const body = source.split(`static let ${name} = """`)[1].split('"""')[0];
    return body.replaceAll('\\(pipMessageHandlerName)', 'ytPiP')
        .replaceAll('\\(playbackMessageHandlerName)', 'ytPlayback');
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

const mediaEvents = [];
const handlers = {};
const interruptions = [];
const messages = [];
const windowEvents = new EventTarget();
const observers = [];
let timerCount = 0;
let nextTimer = 0;
const pendingTimers = new Map();
class Document extends EventTarget {
    nativeVisibility = 'visible';
    get visibilityState() { return this.nativeVisibility; }
    set visibilityState(value) { this.nativeVisibility = value; }
    get hidden() { return this.nativeVisibility !== 'visible'; }
    get pictureInPictureElement() { return null; }
    hasFocus() { return this.nativeVisibility === 'visible'; }
    dispatchEvent(event) {
        const captured = new Event(event.type);
        Object.defineProperty(captured, 'target', { value: this });
        let propagationStopped = false;
        captured.stopImmediatePropagation = function() {
            propagationStopped = true;
            Event.prototype.stopImmediatePropagation.call(this);
        };
        windowEvents.dispatchEvent(captured);
        if (propagationStopped) return true;
        return super.dispatchEvent(event);
    }
}
const document = new Document();
document.visibilityState = 'visible';
class MediaElement extends EventTarget {
    paused = true;
    ended = false;
    readyState = 4;
    currentTime = 0;
    streamReady = false;
    play() {
        if (this.paused) {
            this.paused = false;
            mediaEvents.push(() => this.dispatchEvent(new Event('play')));
            mediaEvents.push(() => {
                if (!this.paused) this.dispatchEvent(new Event('playing'));
            });
        }
        return Promise.resolve();
    }
    pause() {
        if (!this.paused) {
            this.paused = true;
            this.streamReady = false;
            mediaEvents.push(() => this.dispatchEvent(new Event('pause')));
        }
    }
}
class Video extends MediaElement {
    nativePresentationMode = 'inline';
    get webkitPresentationMode() { return this.nativePresentationMode; }
    attributes = new Set();
    hasAttribute(name) { return this.attributes.has(name); }
    removeAttribute(name) { this.attributes.delete(name); }
    webkitSetPresentationMode(mode) {
        this.nativePresentationMode = mode;
        this.dispatchEvent(new Event('webkitpresentationmodechanged'));
    }
    dispatchEvent(event) {
        const captured = new Event(event.type);
        Object.defineProperty(captured, 'target', { value: this });
        let propagationStopped = false;
        captured.stopImmediatePropagation = function() {
            propagationStopped = true;
            Event.prototype.stopImmediatePropagation.call(this);
        };
        windowEvents.dispatchEvent(captured);
        if (propagationStopped) return true;
        document.dispatchEvent(captured);
        if (propagationStopped) return true;
        return super.dispatchEvent(event);
    }
}
const video = new Video();
const nativePlay = MediaElement.prototype.play;
const nativePause = MediaElement.prototype.pause;
const nativePresentation = Video.prototype.webkitSetPresentationMode;
class MediaSession {
    state = 'none';
    get playbackState() { return this.state; }
    set playbackState(value) {
        this.state = value;
        if (value === 'playing' && document.visibilityState === 'hidden') {
            interruptions.push(() => handlers.pause({ action: 'pause' }));
        }
    }
    setActionHandler(action, handler) { handlers[action] = handler; }
}
const mediaSession = new MediaSession();
let playerPlayCalls = 0;
let playerPauseCalls = 0;
let controllerSuspended = false;
const player = {
    state: 2,
    getPlayerState() { return this.state; },
    playVideo() {
        playerPlayCalls++;
        controllerSuspended = false;
        video.streamReady = true;
        this.state = 1;
        video.play().catch(() => {});
        mediaSession.playbackState = 'playing';
    },
    pauseVideo() {
        playerPauseCalls++;
        this.state = 2;
        nativePause.call(video);
        mediaSession.playbackState = 'paused';
    }
};
video.addEventListener('play', () => { if (!controllerSuspended) player.state = 1; });
video.addEventListener('playing', () => { if (!controllerSuspended) video.streamReady = true; });
video.addEventListener('pause', () => { player.state = 2; });
document.querySelectorAll = () => [video];
document.querySelector = () => video;
document.getElementById = () => player;
const playbackContext = vm.createContext({
    document, Document, HTMLMediaElement: MediaElement, HTMLVideoElement: Video, EventTarget, DOMException,
    navigator: { mediaSession },
    addEventListener: windowEvents.addEventListener.bind(windowEvents),
    MutationObserver: class { constructor(callback) { this.callback = callback; } observe(target) {
        observers.push({ target, callback: this.callback });
    } },
    setTimeout(callback) {
        timerCount++;
        const timer = ++nextTimer;
        pendingTimers.set(timer, callback);
        return timer;
    },
    clearTimeout(timer) { pendingTimers.delete(timer); },
    webkit: { messageHandlers: {
        ytPiP: { postMessage(message) { messages.push(message); } }
    } }
});
vm.runInContext('window = globalThis;', playbackContext);
const originalAdd = EventTarget.prototype.addEventListener;
vm.runInContext(script('YouTubePlayerScripts.swift', 'mediaIsolationBootstrap'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+Diagnostics.swift', 'playbackDiagnostics'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+PiP.swift', 'pipEventBridge'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+Environment.swift', 'pageEnvironmentMask'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+Ownership.swift', 'playbackOwnership'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+MediaSessionState.swift', 'mediaSessionPlaybackStateBridge'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+MediaSession.swift', 'mediaSessionUserActionBridge'), playbackContext);
vm.runInContext(script('YouTubePlayerScripts+Autoplay.swift', 'autoplayArmer'), playbackContext);
let pageVisibilityEvents = 0;
let pagePiPEvents = 0;
document.addEventListener('visibilitychange', () => pageVisibilityEvents++);
video.addEventListener('webkitpresentationmodechanged', () => pagePiPEvents++);
assert.equal(observers[0].target, document, 'discovery works before documentElement exists');
assert.equal(EventTarget.prototype.addEventListener, originalAdd);
let pageMediaEvents = 0;
for (const eventType of ['play', 'playing', 'pause']) {
    windowEvents.addEventListener(eventType, () => pageMediaEvents++);
}
function flushMediaEvents() {
    let remainingEvents = 100;
    while (mediaEvents.length) {
        assert.ok(remainingEvents-- > 0, 'playback must settle without an event feedback loop');
        mediaEvents.shift()();
    }
}
let pageCommands = 0;
for (const action of ['play', 'pause', 'stop']) {
    mediaSession.setActionHandler(action, () => pageCommands++);
}
handlers.play();
flushMediaEvents();
assert.equal(video.paused, false);
assert.equal(mediaSession.playbackState, 'none', 'inline playback also uses native video state');
document.nativeVisibility = 'hidden';
document.dispatchEvent(new Event('visibilitychange'));
assert.equal(document.visibilityState, 'visible', 'page sees the foreground state');
assert.equal(document.hidden, false);
assert.equal(document.hasFocus(), true);
assert.equal(playbackContext.__yt.realVisibilityState(), 'hidden', 'app retains the native visibility');
assert.equal(pageVisibilityEvents, 0, 'page does not receive background visibility events');
mediaSession.playbackState = 'playing';
video.pause();
flushMediaEvents();
assert.equal(interruptions.length, 0, 'inline backgrounding cannot activate a competing DOM media session');
assert.equal(video.paused, false, 'page pause is blocked while backgrounded');
player.pauseVideo();
flushMediaEvents();
assert.equal(video.paused, false);
assert.equal(player.state, 1, 'blocked page pause must not leave the stream controller paused');
assert.equal(playerPauseCalls, 0, 'page player pause cannot bypass the native media guard');
assert.equal(playbackContext.__yt.userPaused, false, 'blocked page pause must not change user intent');
handlers.pause();
flushMediaEvents();
assert.equal(video.paused, true);
await assert.rejects(video.play(), { name: 'AbortError' });
assert.equal(video.paused, true, 'page cannot undo a user pause');
handlers.play();
flushMediaEvents();
assert.equal(video.paused, false, 'system resume bypasses the page play guard');
playbackContext.__yt.backgroundResumeEligible = true;
nativePause.call(video);
flushMediaEvents();
await Promise.resolve();
flushMediaEvents();
assert.equal(video.paused, false, 'first native inline background interruption resumes once');
assert.equal(playbackContext.__yt.backgroundResumeEligible, false);
playbackContext.__yt.backgroundResumeEligible = true;
handlers.pause();
flushMediaEvents();
await Promise.resolve();
assert.equal(video.paused, true, 'explicit background pause remains paused');
assert.equal(playbackContext.__yt.backgroundResumeEligible, false);
handlers.play();
flushMediaEvents();
handlers.stop();
flushMediaEvents();
assert.equal(video.paused, true, 'system stop remains authoritative');
assert.equal(pageCommands, 0, 'system commands never invoke page-owned callbacks');

handlers.play();
flushMediaEvents();
const inlinePageMediaEvents = pageMediaEvents;
assert.ok(inlinePageMediaEvents > 0, 'inline page listeners retain normal media events');
nativePresentation.call(video, 'picture-in-picture');
video.dispatchEvent(new Event('enterpictureinpicture'));
assert.deepEqual(messages, ['enter']);
assert.equal(video.webkitPresentationMode, 'inline', 'page cannot observe the native PiP mode');
assert.equal(playbackContext.__yt.realPresentationMode(video), 'picture-in-picture');
assert.equal(pagePiPEvents, 0, 'page does not receive the PiP presentation event');
video.webkitSetPresentationMode('inline');
assert.equal(playbackContext.__yt.realPresentationMode(video), 'picture-in-picture', 'page cannot close native PiP');
player.pauseVideo = function() {
    playerPauseCalls++;
    nativePause.call(video);
};
video.disablePictureInPicture = true;
assert.equal(video.disablePictureInPicture, false);
video.attributes.add('disablepictureinpicture');
observers.find(observer => observer.target === video).callback();
assert.equal(video.hasAttribute('disablepictureinpicture'), false);
video.addEventListener('play', () => video.pause());
for (let attempt = 0; attempt < 3; attempt++) {
    nativePlay.call(video);
    player.pauseVideo();
    video.pause();
    assert.equal(video.paused, false, 'page cannot pause before the native resume event arrives');
    flushMediaEvents();
    await Promise.resolve();
    assert.equal(video.paused, false, 'native PiP resume survives a counteracting page pause');
    assert.equal(video.streamReady, true, 'the stream consumer receives playing on every PiP resume');
    player.pauseVideo();
    flushMediaEvents();
    assert.equal(video.paused, false, 'page player API cannot stop resumed native PiP');
    nativePause.call(video);
    flushMediaEvents();
    assert.equal(video.paused, true, 'immediate native PiP pause is respected');
    assert.equal(playbackContext.__yt.userPaused, true);
    assert.equal(player.state, 2, 'the stream controller observes the real pause');
}
assert.equal(playerPlayCalls, 0, 'native PiP playback does not invoke the page play command');
assert.equal(playerPauseCalls, 0, 'native PiP events never call the page player API');
assert.ok(pageMediaEvents > inlinePageMediaEvents, 'PiP preserves normal media event delivery');

nativePause.call(video);
flushMediaEvents();
nativePlay.call(video);
flushMediaEvents();
await Promise.resolve();
assert.equal(video.paused, false);
assert.equal(video.streamReady, true, 'normal stream events remain available after PiP resume');
assert.equal(playerPlayCalls, 0, 'PiP resume does not issue a second page play command');
assert.equal(pendingTimers.size, 0, 'PiP resume does not schedule a recovery timer');

const sessionSource = readFileSync(new URL('../../App/Core/YouTube Player Session/YouTubePlayerSession.swift', import.meta.url), 'utf8');
const playSource = sessionSource.split('func play() {')[1].split('let script = """')[1].split('"""')[0];
const savedPause = playbackContext.__yt.pauseVideo;
let sessionPauseCalls = 0;
playbackContext.__yt.pauseVideo = function(media) {
    sessionPauseCalls++;
    return savedPause(media);
};
video.readyState = 0;
video.paused = false;
assert.equal(await vm.runInContext(`(async function() {${playSource}})()`, playbackContext), true);
assert.equal(sessionPauseCalls, 0, 'remote play does not pause a PiP video with transient missing media');
video.readyState = 4;
nativePause.call(video);
flushMediaEvents();

playbackContext.__yt.armAutoplay(12000);
assert.equal(playbackContext.__yt.userPaused, true, 'autoplay cannot clear a PiP pause');
assert.equal(vm.runInContext(script('YouTubePlayerScripts+Autoplay.swift', 'nativeAutoplayKick'), playbackContext),
    'done', 'native autoplay does not cycle the PiP media element');
playbackContext.__yt.expectingPiPExit = true;
playbackContext.__yt.exitPiP(video);
assert.equal(playbackContext.__yt.realPresentationMode(video), 'inline', 'app retains original PiP exit API');
assert.deepEqual(messages, ['enter', 'leave']);
assert.equal(mediaSession.playbackState, 'none', 'PiP exit does not restore page session ownership');
playbackContext.__yt.enterPiP(video);
assert.equal(playbackContext.__yt.realPresentationMode(video), 'picture-in-picture', 'app retains original PiP entry API');
video.readyState = 0;
video.paused = false;
video.pause();
assert.equal(video.paused, false, 'buffering cannot let the page pause native PiP');
playbackContext.__yt.expectingPiPExit = true;
playbackContext.__yt.exitPiP(video);

// A non-player media element and source replacement retain their normal lifecycle.
const audio = new MediaElement();
await audio.play();
audio.pause();
flushMediaEvents();
assert.equal(audio.paused, true);
playbackContext.__yt.userPaused = false;
video.readyState = 0;
video.paused = false;
video.pause();
flushMediaEvents();
assert.equal(video.paused, true, 'source replacement pauses are not blocked');
video.readyState = 4;
video.ended = true;
video.paused = false;
video.pause();
flushMediaEvents();
assert.equal(video.paused, true, 'ended media can transition to the next source');
vm.runInContext(`__yt.setPiPActionHandler(() => 'native');
    navigator.mediaSession.setActionHandler('enterpictureinpicture', () => 'page');`, playbackContext);
assert.equal(handlers.enterpictureinpicture(), 'native');
assert.equal(pendingTimers.size, 0, 'ownership protection leaves no active retry timer');
assert.ok(timerCount < 20, 'PiP playback does not create a timer loop');
let visibilityEvents = 0;
document.addEventListener('visibilitychange', () => visibilityEvents++);
document.dispatchEvent(new Event('visibilitychange'));
assert.equal(visibilityEvents, 0);
const autoplayVideo = new EventTarget();
autoplayVideo.muted = true;
let autoplayUnmuteCalls = 0;
const autoplayContext = vm.createContext({
    document: {
        querySelectorAll() { return [autoplayVideo]; },
        getElementById() { return { unMute() { autoplayUnmuteCalls++; } }; }
    },
    __yt: {
        armAutoplay() {},
        logState() {},
        addListener(target, type, listener, options) { target.addEventListener(type, listener, options); },
        onMutation(callback) { callback(); }
    }
});
vm.runInContext('window = globalThis;', autoplayContext);
vm.runInContext(script('YouTubePlayerScripts+Autoplay.swift', 'initialAutoplayKick'), autoplayContext);
autoplayVideo.dispatchEvent(new Event('playing'));
assert.equal(autoplayVideo.muted, false);
assert.equal(autoplayUnmuteCalls, 1, 'initial autoplay unmutes the player once');
autoplayVideo.muted = true;
autoplayVideo.dispatchEvent(new Event('playing'));
assert.equal(autoplayUnmuteCalls, 1, 'resume must not issue another page unmute command');
assert.equal(autoplayVideo.muted, true, 'resume preserves a subsequent user mute');
console.log('Policy, inline backgrounding, native controls, PiP ownership, lifecycle and initial autoplay checks passed');
