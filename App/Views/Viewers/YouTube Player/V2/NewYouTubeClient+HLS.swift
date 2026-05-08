import Foundation

extension NewYouTubeClient {

    /// Parses an HLS master playlist into its variant and audio media entries.
    static func parseHLSMaster(
        _ text: String
    ) -> (variants: [YouTubeHLSVariant], audios: [YouTubeHLSAudioMedia]) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var variants: [YouTubeHLSVariant] = []
        var audios: [YouTubeHLSAudioMedia] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("#EXT-X-STREAM-INF:") && index + 1 < lines.count {
                let attributes = parseAttributeList(
                    String(line.dropFirst("#EXT-X-STREAM-INF:".count))
                )
                let bandwidth = Int(attributes["BANDWIDTH"] ?? "") ?? 0
                let next = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !next.isEmpty, !next.hasPrefix("#") {
                    variants.append(YouTubeHLSVariant(
                        url: next,
                        bandwidth: bandwidth,
                        resolution: attributes["RESOLUTION"],
                        codecs: attributes["CODECS"],
                        audioGroup: attributes["AUDIO"]
                    ))
                }
                index += 2
            } else if line.hasPrefix("#EXT-X-MEDIA:") {
                let attributes = parseAttributeList(String(line.dropFirst("#EXT-X-MEDIA:".count)))
                if attributes["TYPE"] == "AUDIO",
                   let uri = attributes["URI"],
                   let groupId = attributes["GROUP-ID"] {
                    audios.append(YouTubeHLSAudioMedia(
                        url: uri,
                        groupId: groupId,
                        name: attributes["NAME"],
                        isDefault: attributes["DEFAULT"] == "YES"
                    ))
                }
                index += 1
            } else {
                index += 1
            }
        }
        return (variants, audios)
    }

    static func selectAudio(
        for variant: YouTubeHLSVariant,
        from audios: [YouTubeHLSAudioMedia]
    ) -> YouTubeHLSAudioMedia? {
        guard let group = variant.audioGroup else { return nil }
        let matching = audios.filter { $0.groupId == group }
        if matching.isEmpty { return nil }
        let nonDescriptive = matching.filter {
            !($0.name ?? "").lowercased().contains("descriptive")
        }
        let pool = nonDescriptive.isEmpty ? matching : nonDescriptive
        if let original = pool.first(where: { ($0.name ?? "").lowercased().contains("original") }) {
            return original
        }
        return pool.first(where: { $0.isDefault }) ?? pool.first
    }

    static func selectBestVideo(from variants: [YouTubeHLSVariant]) -> YouTubeHLSVariant? {
        variants.max { lhs, rhs in
            let lhsH264 = (lhs.codecs ?? "").contains("avc1")
            let rhsH264 = (rhs.codecs ?? "").contains("avc1")
            if lhsH264 != rhsH264 { return !lhsH264 }
            return lhs.bandwidth < rhs.bandwidth
        }
    }

    private static func parseAttributeList(_ source: String) -> [String: String] {
        var output: [String: String] = [:]
        var key = ""
        var value = ""
        var inQuotes = false
        var readingKey = true
        for character in source {
            if readingKey {
                if character == "=" { readingKey = false } else { key.append(character) }
            } else {
                if character == "\"" {
                    inQuotes.toggle()
                } else if character == "," && !inQuotes {
                    output[key.trimmingCharacters(in: .whitespaces)] = value
                    key = ""
                    value = ""
                    readingKey = true
                } else {
                    value.append(character)
                }
            }
        }
        if !key.isEmpty {
            output[key.trimmingCharacters(in: .whitespaces)] = value
        }
        return output
    }
}
