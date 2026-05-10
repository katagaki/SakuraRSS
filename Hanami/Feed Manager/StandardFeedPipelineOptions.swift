import Foundation

public struct StandardFeedPipelineOptions: Sendable {
    public let updateTitle: Bool
    public let skipImageFetch: Bool
    public let skipImagePreload: Bool
    public let runNLP: Bool
    public var contentOnly: Bool = false
}
