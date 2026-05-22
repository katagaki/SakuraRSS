import AVFoundation
import Foundation
import Hanami

extension NewYouTubePlaybackController {

    func loadMediaSelectionOptions(for item: AVPlayerItem) async {
        let asset = item.asset
        let audible = try? await asset.loadMediaSelectionGroup(for: .audible)
        let legible = try? await asset.loadMediaSelectionGroup(for: .legible)

        audioGroup = audible
        subtitleGroup = legible
        audioOptions = audible?.options ?? []
        subtitleOptions = legible?.options ?? []
        // swiftlint:disable:next line_length
        log("YT Playback", "Media options audio=\(audioOptions.count) [\(audioOptions.map(\.displayName).joined(separator: ", "))] subtitles=\(subtitleOptions.count) [\(subtitleOptions.map(\.displayName).joined(separator: ", "))]")

        if let audible {
            if let originalOption = await preferredOriginalAudioOption(in: audible) {
                item.select(originalOption, in: audible)
                currentAudioOption = originalOption
            } else {
                currentAudioOption = item.currentMediaSelection.selectedMediaOption(in: audible)
            }
        }
        if let legible {
            currentSubtitleOption = item.currentMediaSelection.selectedMediaOption(in: legible)
        }
    }

    /// Finds the audio option that represents the video's original audio track.
    /// Checks the explicit `isOriginalContent` characteristic first, then falls
    /// back to a title match in the option's common metadata (YouTube
    /// renditions are named like "English (United States) original" via the
    /// HLS NAME attribute, which surfaces as the option's title metadata.
    /// `displayName` returns the localized language name and is not reliable).
    func preferredOriginalAudioOption(
        in group: AVMediaSelectionGroup
    ) async -> AVMediaSelectionOption? {
        if let original = group.options.first(where: {
            $0.hasMediaCharacteristic(.isOriginalContent)
        }) {
            return original
        }
        for option in group.options {
            if option.displayName.lowercased().contains("original") {
                return option
            }
            let title = await audioOptionTitle(option)
            if title.lowercased().contains("original") {
                return option
            }
        }
        return nil
    }

    func audioOptionTitle(_ option: AVMediaSelectionOption) async -> String {
        let titles = AVMetadataItem.metadataItems(
            from: option.commonMetadata,
            withKey: AVMetadataKey.commonKeyTitle,
            keySpace: .common
        )
        var values: [String] = []
        for item in titles {
            if let value = try? await item.load(.stringValue) {
                values.append(value)
            }
        }
        return values.joined(separator: " ")
    }
}
