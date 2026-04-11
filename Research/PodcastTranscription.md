# On-Device Podcast Transcription Research

## Overview

This document investigates the feasibility of adding on-device podcast transcription to SakuraRSS. The goal is to enable users to generate text transcripts of podcast episodes directly on their device, without sending audio to external servers.

## Current State of SakuraRSS

- **Target:** iOS 26.0+, Swift/SwiftUI
- **Podcast support:** Full playback via `AVPlayer` with `AudioPlayer` singleton, remote commands, Now Playing integration
- **AI features:** Apple Intelligence summarization (FoundationModels) and translation already integrated
- **Data model:** `Article` has `audioURL: String?`, `duration: Int?`, and `isPodcastEpisode` computed property
- **Caching pattern:** Database-backed caching for summaries and translations via `DatabaseManager`

---

## Option 1: SpeechAnalyzer / SpeechTranscriber (iOS 26+) — Recommended

### Overview
Apple introduced `SpeechAnalyzer` and `SpeechTranscriber` in iOS 26 as successors to `SFSpeechRecognizer`. These provide modern, Swift-native APIs for on-device speech recognition and transcription.

### Key Details
- **Framework:** `Speech` (new API surface in iOS 26, introduced at WWDC 2025)
- **On-device:** Fully on-device processing, no network required. Model runs out-of-process (in a system daemon), so it does **not** count against the app's memory budget
- **Presets:** `.offlineTranscription`, `.dictation`, and `.conversation` — `.offlineTranscription` or `.conversation` are ideal for podcasts
- **API style:** Modern async/await with `AsyncSequence` for streaming results via `analyzeSequence(from: fileURL)`
- **Language support:** 40+ locales (English, German, French, Spanish, Japanese, Korean, Chinese, Portuguese, Russian, and many more). Full list via `SpeechTranscriber.supportedLocales`
- **Authorization:** Still requires `NSSpeechRecognitionUsageDescription` in Info.plist and user permission
- **Hardware requirement:** `SpeechTranscriber` requires Apple Intelligence-capable hardware (A17 Pro / iPhone 15 Pro or later). For older devices, Apple provides `DictationTranscriber` as a fallback (same capabilities as old `SFSpeechRecognizer`)

### Benchmarks
- **Speed:** Benchmarked at 2.2x faster than Whisper Large V3 Turbo on a 7 GB video file. A 7:31 audio clip took ~9 seconds (vs ~40 seconds for Whisper). Estimated ~5-10 minutes for a 1-hour podcast on modern hardware.
- **Accuracy:** Word Error Rate (WER) of ~8%, Character Error Rate (CER) of ~3%. Lower than Whisper large-v3-turbo (~2.2% WER) but adequate for search, indexing, and general reading.

### Advantages
- **Zero app size impact** — uses system models already on device
- **No dependencies** — first-party Apple framework
- **No memory pressure** — model runs out-of-process in a system daemon
- **No duration limits** — unlike `SFSpeechRecognizer`, designed for long-form content (lectures, meetings, podcasts)
- **Perfect platform fit** — the app already targets iOS 26.0+
- **Consistent with existing patterns** — uses async/await like the rest of the codebase
- **Privacy** — fully on-device, no data leaves the device
- **Free** — no API costs or licensing concerns

### Concerns
- **Accuracy trade-off:** ~8% WER is noticeably lower than Whisper's ~2.2% WER. For podcasts with technical jargon or heavy accents, this gap may be significant
- **Hardware requirement:** Full `SpeechTranscriber` requires A17 Pro (iPhone 15 Pro+). Older devices fall back to `DictationTranscriber` which has the legacy 1-minute limit
- **No custom vocabulary:** Cannot add domain-specific terms (unlike legacy `SFSpeechRecognizer`)
- **No speaker diarization:** Does not identify or label individual speakers

### Integration Sketch
```swift
import Speech

func transcribeEpisode(audioURL: URL) async throws -> String {
    let analyzer = SpeechAnalyzer()
    let transcriber = SpeechTranscriber(preset: .offlineTranscription)
    
    var fullText = ""
    for try await result in analyzer.analyzeSequence(from: audioURL) {
        let transcription = transcriber.process(result)
        fullText += transcription.formattedString
    }
    return fullText
}
```

### Verdict
**Best first choice.** Zero cost, zero dependencies, no memory pressure (out-of-process), and faster than Whisper. Aligns with the app's existing Apple-framework-first approach. The ~8% WER is acceptable for most podcast content. Should be the primary implementation target, with WhisperKit as a fallback for users who need higher accuracy.

### References
- [Bring advanced speech-to-text to your app with SpeechAnalyzer — WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Apple's New Transcription APIs Blow Past Whisper in Speed Tests — MacRumors](https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/)
- [How accurate is Apple's new transcription AI? — 9to5Mac](https://9to5mac.com/2025/07/03/how-accurate-is-apples-new-transcription-ai-we-tested-it-against-whisper-and-parakeet/)

---

## Option 2: WhisperKit (by Argmax) — Strong Alternative

### Overview
WhisperKit is a Swift package that runs OpenAI's Whisper speech recognition models on-device using CoreML and Apple's Neural Engine.

### Key Details
- **Repository:** https://github.com/argmaxinc/WhisperKit
- **License:** MIT
- **Integration:** Swift Package Manager (`https://github.com/argmaxinc/WhisperKit.git`, from version `0.9.0`)
- **Products:** `WhisperKit` (STT), `TTSKit` (TTS), `SpeakerKit` (speaker diarization)
- **Platform:** macOS 14.0+, iOS 18.0+. Requires Xcode 16.0+
- **Device requirement:** iPhone 15 or newer (plans to lower to iPhone 13)
- **Models:** Compiled to CoreML format, runs on Neural Engine (ANE). Downloaded from HuggingFace on first use and cached locally.

### Model Sizes and Performance

| Model | Parameters | Size (CoreML) | Accuracy | Recommended For |
|-------|-----------|---------------|----------|-----------------|
| tiny.en | 39M | ~30-75 MB | Lower | Quick previews, English only |
| base.en | 74M | ~140 MB | Moderate | Balanced, English only |
| small.en | 244M | ~460 MB | Good | General transcription |
| large-v3-turbo | 809M | ~954 MB | Excellent (~2.2% WER) | High-quality transcription |
| large-v3 | 1.55B | ~1.5 GB | Best | Highest accuracy, multilingual |

- **Speed factor:** Up to 60x real-time (1 minute of audio in 1 second on Apple Silicon)
- **Estimated 1-hour podcast:** ~1-5 minutes depending on model size
- **Streaming latency:** ~0.45 seconds per word

### Advantages
- **No duration limits** — can transcribe arbitrarily long audio
- **Excellent accuracy** — ~2.2% WER with large-v3-turbo, significantly better than SpeechAnalyzer's ~8%
- **Multi-language support** — 99+ languages
- **Streaming support** — can provide progressive results
- **Timestamps** — word-level and segment-level timestamps available
- **Speaker diarization** — available via `SpeakerKit` companion module
- **Active development** — well-maintained, backed by Argmax, ICML 2025 paper published

### Concerns
- **App size:** Models downloaded on first use (75 MB to 1.5 GB). App binary stays small but storage is consumed on-device.
- **Memory usage:** Models run **in-process** (unlike SpeechAnalyzer), so larger models consume the app's memory budget. Could be problematic on older devices.
- **Battery:** Intensive Neural Engine usage; transcribing a long podcast will consume noticeable battery (though ANE is relatively power-efficient)
- **Dependency:** Adds a third-party dependency to the project
- **Model hosting:** Uses Argmax's HuggingFace hosting by default; could also self-host

### Integration Sketch
```swift
import WhisperKit

func transcribeEpisode(audioURL: URL) async throws -> String {
    let whisperKit = try await WhisperKit(model: "openai_whisper-small")
    let results = try await whisperKit.transcribe(audioPath: audioURL.path)
    return results.map { $0.text }.joined(separator: " ")
}
```

### Verdict
**Best choice if higher accuracy is needed.** Offers significantly better WER (~2.2% vs ~8%) and speaker diarization, at the cost of in-process memory usage and a third-party dependency. Model downloading on-demand keeps the initial app binary small.

### References
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)
- [WhisperKit ICML 2025 Paper](https://arxiv.org/abs/2507.10860)
- [Apple SpeechAnalyzer and Argmax WhisperKit Comparison](https://www.argmaxinc.com/blog/apple-and-argmax)

---

## Option 3: whisper.cpp / SwiftWhisper — Viable but Less Ergonomic

### Overview
whisper.cpp is a C/C++ port of OpenAI's Whisper by Georgi Gerganov. SwiftWhisper provides a Swift wrapper around it.

### Key Details
- **Repository:** https://github.com/ggml-org/whisper.cpp
- **Swift wrapper:** SwiftWhisper (https://github.com/exPHAT/SwiftWhisper) — SPM package
- **License:** MIT (both whisper.cpp and SwiftWhisper)
- **CoreML support:** Yes, encoder runs on ANE via CoreML, decoder runs on CPU via GGML
- **Quantization:** Supports GGML quantized models (Q5_1) which reduce model size by ~60% with minimal accuracy loss
- **Audio format:** Requires 16kHz PCM audio frames

### Quantized Model Sizes (GGML Q5_1)

| Model | Unquantized | Quantized (Q5_1) |
|-------|------------|-------------------|
| tiny.en | 75 MB | ~31 MB |
| base.en | 142 MB | ~57 MB |
| small.en | 466 MB | ~190 MB |
| large-v3 | 2.9 GB | ~1.1 GB |

### Advantages
- Uses the same Whisper models, so accuracy is equivalent
- Quantized models are significantly smaller than CoreML equivalents
- Slightly more control over inference parameters
- Broader device support (does not require ANE for the full pipeline)

### Concerns
- **Integration complexity:** C++ interop is more fragile than pure Swift
- **Less Swift-idiomatic:** SwiftWhisper wrapper abstracts some complexity but is less polished than WhisperKit
- **Performance:** Generally slower than WhisperKit on Apple Silicon, as WhisperKit is optimized end-to-end for CoreML/ANE
- **Build complexity:** Requires C++ compilation; debug builds are dramatically slower (must use Release builds)
- **Memory:** The large model requires ~4.7 GB of memory

### Verdict
**Not recommended over WhisperKit.** WhisperKit provides the same underlying model quality with a much better Swift developer experience. The one advantage of whisper.cpp is quantized model support for smaller downloads, but WhisperKit's CoreML models already offer good size/performance trade-offs.

---

## Option 4: SFSpeechRecognizer (Legacy) — Fallback

### Overview
The traditional `SFSpeechRecognizer` API available since iOS 10, with on-device support since iOS 13.

### Key Details
- **On-device:** Yes (since iOS 13), requires downloading language models
- **Audio file support:** Yes, via `SFSpeechURLRecognitionRequest`
- **Duration limit:** ~1 minute per request (hard limit)
- **Authorization required:** Yes

### Workaround for Duration Limit
Audio can be segmented into ~55-second chunks with slight overlap, transcribed individually, then concatenated. This is fragile and may produce artifacts at segment boundaries.

### Verdict
**Not recommended.** The 1-minute limit makes it impractical for podcasts (typical episodes are 30-90 minutes). Use the new SpeechAnalyzer API instead since the app targets iOS 26+.

---

## Option 5: Apple Intelligence / FoundationModels — Not Applicable

The `FoundationModels` framework (Apple Intelligence) handles text-to-text tasks only (summarization, rewriting, etc.). It has **no audio transcription capability**. It cannot be used for this feature.

However, a transcription feature would complement the existing summarization pipeline nicely: transcribe audio → summarize transcript → display summary. This would enable AI-powered podcast summaries from audio content (currently, summaries only work on the RSS feed's text description).

---

## Audio File Requirement

**Both SpeechAnalyzer and WhisperKit require local audio files.** They accept a local file URL, not a remote HTTP URL. Since SakuraRSS currently streams podcast audio directly from remote URLs via `AVPlayer`, the audio must be downloaded before transcription.

### Approach 1: Temporary Download (Transcribe & Discard)
Download the episode to a temporary directory, transcribe it, cache the transcript in the database, then delete the audio file. This avoids persistent storage costs.

```swift
// Download episode audio to a temp file
let (tempURL, _) = try await URLSession.shared.download(from: remoteAudioURL)
let localURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString + ".mp3")
try FileManager.default.moveItem(at: tempURL, to: localURL)

// Transcribe from local file
let transcript = try await transcribe(from: localURL)

// Cache transcript, delete temp file
try DatabaseManager.shared.cacheArticleTranscription(transcript, for: articleID)
try FileManager.default.removeItem(at: localURL)
```

### Approach 2: Pair with Offline Listening (Issue #55)
Issue #55 already requests offline podcast downloads. If implemented, transcription becomes trivial — the local file already exists. The "Transcribe" button would only appear for downloaded episodes.

### Audio Format Compatibility
Podcast feeds use `<enclosure>` tags with `type="audio/*"` — typically MP3 or M4A. Both APIs handle these natively:
- **SpeechAnalyzer** `analyzeSequence(from:)` — supports any format AVFoundation can decode (MP3, M4A, WAV, AAC, etc.)
- **WhisperKit** `transcribe(audioPath:)` — explicitly supports `.wav`, `.mp3`, `.m4a`, `.flac`

---

## Recommended Implementation Plan

### Phase 1: SpeechAnalyzer/SpeechTranscriber (Primary)
1. **Add transcription to Article model:** New `transcription: String?` field in the database
2. **Implement audio download:** Temporary download via `URLSession.shared.download(from:)` for transcription purposes
3. **Create `PodcastTranscriber` service:** Async service using `SpeechTranscriber` with `.offlineTranscription` preset
4. **Add UI:** "Transcribe" button in `PodcastEpisodeView+Actions.swift`, following the existing summarize/translate pattern
5. **Cache results:** Store transcripts in `DatabaseManager` using the existing caching pattern
6. **Clean up:** Delete temporary audio file after transcription completes

### Phase 2: WhisperKit Fallback (If Needed)
1. **Add WhisperKit SPM dependency** only if SpeechAnalyzer proves insufficient
2. **On-demand model download:** Download the `small` model on first transcription request
3. **Model management UI:** Settings page for model selection and storage management
4. **Background processing:** Use background task API for long transcriptions

### Phase 3: Enhanced Features
1. **Transcript + Summarization pipeline:** Feed transcripts into the existing `BatchSummarizer` for AI-generated podcast summaries
2. **Search within transcripts:** Enable full-text search across transcribed episodes
3. **Timestamp navigation:** Tap on transcript text to seek to that point in the audio
4. **Speaker diarization:** Identify and label different speakers (if supported by the chosen API)

---

## Architecture Fit

The transcription feature fits naturally into the existing architecture:

```
┌─────────────────────────────────────────────────┐
│                PodcastEpisodeView               │
│  ┌──────────┐  ┌───────────┐  ┌──────────────┐ │
│  │Transcribe│  │ Summarize │  │  Translate   │ │
│  │  Button  │  │  Button   │  │   Button     │ │
│  └────┬─────┘  └─────┬─────┘  └──────┬───────┘ │
│       │               │               │         │
│  ┌────▼─────┐  ┌──────▼──────┐  ┌─────▼──────┐ │
│  │Podcast   │  │  Language   │  │Translation │ │
│  │Transcrib-│  │   Model    │  │  Session   │ │
│  │er        │  │  Session   │  │            │ │
│  └────┬─────┘  └──────┬──────┘  └─────┬──────┘ │
│       │               │               │         │
│       └───────────────┼───────────────┘         │
│                       │                         │
│              ┌────────▼────────┐                │
│              │ DatabaseManager │                │
│              │   (Caching)     │                │
│              └─────────────────┘                │
└─────────────────────────────────────────────────┘
```

### New Files Needed
- `Shared/Podcast Transcriber/PodcastTranscriber.swift` — Core transcription logic
- `SakuraRSS/Views/Shared/Podcast Episode/PodcastEpisodeView+Transcriptions.swift` — UI extension

### Modified Files
- `Shared/Models.swift` — Add transcription field to Article
- `Shared/Database Manager/DatabaseManager.swift` — Add transcription column
- `Shared/Database Manager/DatabaseManager+ArticleContent.swift` — Add cache/retrieve methods
- `SakuraRSS/Views/Shared/Podcast Episode/PodcastEpisodeView.swift` — Add transcription state
- `SakuraRSS/Views/Shared/Podcast Episode/PodcastEpisodeView+Actions.swift` — Add transcribe button

---

## Comparison Table

| Criterion | SpeechAnalyzer (iOS 26) | WhisperKit | whisper.cpp | SFSpeechRecognizer |
|-----------|------------------------|------------|-------------|-------------------|
| **Ease of integration** | Excellent (few lines) | Good (SPM) | Moderate (C interop) | Good (built-in) |
| **App size impact** | None (system-managed) | 75 MB – 1.5 GB models | 31 MB – 1.1 GB (quantized) | None |
| **1-hour podcast** | ~5-10 min | ~1-5 min | ~3-10 min | Not viable |
| **Accuracy (WER)** | ~8% | ~2.2% (large-v3-turbo) | ~2.2% (same models) | Lower than Whisper |
| **Memory model** | Out-of-process (zero) | In-process | In-process | Minimal |
| **Offline** | Yes | Yes (after download) | Yes (after download) | Yes |
| **Min hardware** | A17 Pro (iPhone 15 Pro) | iPhone 15 | Broad | Very broad |
| **Long-form audio** | Yes | Yes | Yes | No (1-min limit) |
| **Speaker diarization** | No | Yes (SpeakerKit) | No | No |
| **License** | Apple (free) | MIT | MIT | Apple (free) |

---

## Conclusion

On-device podcast transcription is **feasible and well-suited** for SakuraRSS. The recommended approach is:

1. **Start with `SpeechAnalyzer`/`SpeechTranscriber`** (iOS 26) — zero cost, zero dependencies, fully on-device
2. **Fall back to WhisperKit** if Apple's API has prohibitive duration limits or insufficient accuracy
3. **Leverage existing patterns** — the codebase already has well-established patterns for async processing, caching, and progressive UI updates that map directly to a transcription feature

The feature would also unlock a powerful pipeline: **audio → transcript → AI summary**, enabling meaningful podcast summaries that currently aren't possible (since the existing summarizer only works on RSS feed text descriptions, not actual episode audio content).
