import Foundation
import FoundationModels
import NaturalLanguage

extension HeadlineSummarizer {

    // MARK: - Headline Translation

    /// Detects each headline's language and runs a translation pass on
    /// anything that isn't in the user's locale. The model frequently
    /// ignores in-prompt language directives when the source articles are
    /// in a different language, so this is a deterministic safety net.
    static func translateHeadlinesIfNeeded(
        _ events: [ResolvedEvent]
    ) async -> [ResolvedEvent] {
        let target = userLanguageCode
        return await withTaskGroup(of: (Int, ResolvedEvent).self) { group in
            for (index, event) in events.enumerated() {
                group.addTask {
                    let detected = detectLanguage(of: event.headline)
                    if detected == nil || detected == target {
                        return (index, event)
                    }
                    log(
                        logModule,
                        "translating headline (detected=\(detected ?? "?") -> \(target)): \(event.headline)"
                    )
                    if let translated = await translate(headline: event.headline),
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

    nonisolated private static func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    private static func translate(headline: String) async -> String? {
        let langName = Locale(identifier: "en")
            .localizedString(forLanguageCode: userLanguageCode) ?? "English"
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

    private static var userLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
}
