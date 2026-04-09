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
- **Framework:** `Speech` (new API surface in iOS 26)
- **On-device:** Fully on-device processing, no network required
- **Presets:** `.dictation` and `.conversation` — the `.conversation` preset is ideal for podcasts as it handles multi-speaker dialogue
- **API style:** Modern async/await with `AsyncSequence` for streaming results
- **Language support:** All languages supported by on-device Siri dictation
- **Authorization:** Still requires `NSSpeechRecognitionUsageDescription` in Info.plist and user permission

### Advantages
- **Zero app size impact** — uses system models already on device
- **No dependencies** — first-party Apple framework
- **Perfect platform fit** — the app already targets iOS 26.0+
- **Consistent with existing patterns** — uses async/await like the rest of the codebase
- **Privacy** — fully on-device, no data leaves the device
- **Free** — no API costs or licensing concerns

### Concerns
- **Duration limits:** `SFSpeechRecognizer` historically had a ~1 minute limit per request. The new `SpeechTranscriber` API may lift or relax this, but it needs to be verified. Workaround: segment audio into chunks and transcribe sequentially.
- **Accuracy:** Good for clear speech; may struggle with heavy accents, overlapping speakers, or background music
- **iOS 26 only:** Not available on older OS versions (but SakuraRSS already targets iOS 26.0+)
- **Processing speed:** Unclear how fast it processes pre-recorded audio files vs. real-time

### Integration Sketch
```swift
import Speech

func transcribeEpisode(audioURL: URL) async throws -> String {
    let analyzer = SpeechAnalyzer()
    let transcriber = SpeechTranscriber(preset: .conversation)
    
    // Process audio file
    let result = try await transcriber.transcribe(audioFrom: audioURL)
    return result.transcription.formattedString
}
```

### Verdict
**Best first choice.** Zero cost, zero dependencies, aligns with the app's existing Apple-framework-first approach. Should be the primary implementation target, with WhisperKit as a fallback if accuracy or duration limits are insufficient.

---

## Option 2: WhisperKit (by Argmax) — Strong Alternative

### Overview
WhisperKit is a Swift package that runs OpenAI's Whisper speech recognition models on-device using CoreML and Apple's Neural Engine.

### Key Details
- **Repository:** https://github.com/argmaxinc/WhisperKit
- **License:** MIT
- **Integration:** Swift Package Manager
- **Models:** Compiled to CoreML format, runs on Neural Engine (ANE)
- **Accuracy:** State-of-the-art; Whisper large-v3-turbo offers excellent accuracy across many languages

### Model Sizes and Performance

| Model | Size (approx.) | Speed | Accuracy | Recommended For |
|-------|----------------|-------|----------|-----------------|
| tiny | ~75 MB | Fastest | Lower | Quick previews, low-end devices |
| base | ~140 MB | Fast | Moderate | Balanced use |
| small | ~460 MB | Moderate | Good | General transcription |
| large-v3-turbo | ~1.5 GB | Slower | Excellent | High-quality transcription |

- On modern iPhones (A17+), the `small` model can transcribe roughly **10-20x real-time** (a 1-hour podcast in ~3-6 minutes)
- The `large-v3-turbo` model is slower but still practical for background processing

### Advantages
- **No duration limits** — can transcribe arbitrarily long audio
- **Excellent accuracy** — state-of-the-art Whisper models, especially for English
- **Multi-language support** — 99+ languages
- **Streaming support** — can provide progressive results
- **Timestamps** — word-level and segment-level timestamps available
- **Active development** — well-maintained, backed by Argmax (Apple ecosystem-focused company)

### Concerns
- **App size:** Models must be bundled or downloaded on first use. Even the `tiny` model adds ~75 MB. Recommendation: download models on-demand rather than bundling.
- **Memory usage:** Larger models require significant RAM (small ~1 GB, large-v3-turbo ~3+ GB). Could be problematic on older devices.
- **Battery:** Intensive Neural Engine usage; transcribing a long podcast will consume noticeable battery
- **Dependency:** Adds a third-party dependency to the project
- **Model hosting:** If downloading on-demand, need to host models or use Argmax's default hosting

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
**Best choice if Apple's SpeechAnalyzer proves insufficient.** Offers superior accuracy and no duration limits, at the cost of app size and a third-party dependency. Model downloading on-demand would mitigate the size concern.

---

## Option 3: whisper.cpp / SwiftWhisper — Viable but Less Ergonomic

### Overview
whisper.cpp is a C/C++ port of OpenAI's Whisper by Georgi Gerganov. SwiftWhisper provides a Swift wrapper around it.

### Key Details
- **Repository:** https://github.com/ggerganov/whisper.cpp
- **Swift wrapper:** SwiftWhisper (https://github.com/exPHAT/SwiftWhisper)
- **License:** MIT
- **CoreML support:** Yes, can use CoreML-optimized encoder models
- **Performance:** Comparable to WhisperKit when using CoreML acceleration

### Advantages
- Uses the same Whisper models, so accuracy is equivalent
- Slightly more control over inference parameters
- Lower-level access if needed

### Concerns
- **Integration complexity:** C++ interop is more fragile than pure Swift
- **Less Swift-idiomatic:** SwiftWhisper wrapper abstracts some complexity but is less polished than WhisperKit
- **Maintenance:** WhisperKit is more actively maintained for Apple platforms specifically
- **Build complexity:** Requires C++ compilation, which can cause build issues

### Verdict
**Not recommended over WhisperKit.** WhisperKit provides the same underlying model quality with a much better Swift developer experience.

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

## Recommended Implementation Plan

### Phase 1: SpeechAnalyzer/SpeechTranscriber (Primary)
1. **Add transcription to Article model:** New `transcription: String?` field in the database
2. **Create `PodcastTranscriber` service:** Async service using `SpeechTranscriber` with `.conversation` preset
3. **Add UI:** "Transcribe" button in `PodcastEpisodeView+Actions.swift`, following the existing summarize/translate pattern
4. **Cache results:** Store transcripts in `DatabaseManager` using the existing caching pattern
5. **Test duration limits:** Verify how the new API handles long-form audio; if limited, implement audio chunking

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

## Conclusion

On-device podcast transcription is **feasible and well-suited** for SakuraRSS. The recommended approach is:

1. **Start with `SpeechAnalyzer`/`SpeechTranscriber`** (iOS 26) — zero cost, zero dependencies, fully on-device
2. **Fall back to WhisperKit** if Apple's API has prohibitive duration limits or insufficient accuracy
3. **Leverage existing patterns** — the codebase already has well-established patterns for async processing, caching, and progressive UI updates that map directly to a transcription feature

The feature would also unlock a powerful pipeline: **audio → transcript → AI summary**, enabling meaningful podcast summaries that currently aren't possible (since the existing summarizer only works on RSS feed text descriptions, not actual episode audio content).
