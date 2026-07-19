import Foundation
import FoundationModels
import NaturalLanguage

extension HeadlineSummarizer {

    // MARK: - Headline Translation

    /// Detects each headline's language and runs a translation pass on
    /// anything that isn't in the app's display language. The model
    /// frequently ignores in-prompt language directives when the source
    /// articles are in a different language, so this is a deterministic
    /// safety net.
    static func translateHeadlinesIfNeeded(
        _ events: [ResolvedEvent]
    ) async -> [ResolvedEvent] {
        let target = displayLanguage
        return await withTaskGroup(of: (Int, ResolvedEvent).self) { group in
            for (index, event) in events.enumerated() {
                group.addTask {
                    guard let detected = detectLanguage(of: event.headline),
                          !languagesMatch(detected, target) else {
                        return (index, event)
                    }
                    log(
                        logModule,
                        // swiftlint:disable:next line_length
                        "translating headline (detected=\(detected.minimalIdentifier) -> \(target.minimalIdentifier)): \(event.headline)"
                    )
                    if let translated = await translate(headline: event.headline, into: target),
                       !translated.isEmpty {
                        return (
                            index,
                            ResolvedEvent(
                                headline: translated,
                                articleIDs: event.articleIDs,
                                isMajorWorldEvent: event.isMajorWorldEvent
                            )
                        )
                    }
                    return (index, event)
                }
            }
            var indexed: [(Int, ResolvedEvent)] = []
            for await item in group { indexed.append(item) }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// The language the app is actually running in (the user's per-app
    /// language when set, otherwise the best match between the device
    /// languages and the app's localizations). This matches the language
    /// of the localized prompt, so detection and instructions agree.
    nonisolated static var displayLanguage: Locale.Language {
        if let preferred = Bundle.main.preferredLocalizations.first,
           preferred != "Base" {
            return Locale.Language(identifier: preferred)
        }
        return Locale.current.language
    }

    /// Compares language codes, and scripts only when both sides specify
    /// one. NLLanguageRecognizer reports Chinese as `zh-Hans`/`zh-Hant`
    /// while a bare target of `zh` has no script, so a plain identifier
    /// comparison would flag every Chinese headline as foreign.
    nonisolated static func languagesMatch(
        _ first: Locale.Language,
        _ second: Locale.Language
    ) -> Bool {
        guard let firstCode = first.languageCode,
              let secondCode = second.languageCode else { return false }
        guard firstCode == secondCode else { return false }
        guard let firstScript = first.script,
              let secondScript = second.script else { return true }
        return firstScript == secondScript
    }

    nonisolated private static func detectLanguage(of text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else { return nil }
        return Locale.Language(identifier: dominant.rawValue)
    }

    private static func translate(
        headline: String,
        into target: Locale.Language
    ) async -> String? {
        let langName = Locale(identifier: "en")
            .localizedString(forIdentifier: target.minimalIdentifier) ?? "English"
        let instructions = "Translate the user's text into \(langName). "
            + "Output only the translated text. Keep proper nouns. Do not add commentary."
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: headline)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            log(logModule, "translation failed: \(error.localizedDescription)")
            return nil
        }
    }
}
