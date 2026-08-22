import FoundationModels

@MainActor
enum AppleIntelligenceAvailability {

    private static var cached: Bool?

    static var isAvailable: Bool {
        if let cached {
            return cached
        }
        let value = SystemLanguageModel.default.availability == .available
        cached = value
        return value
    }
}
