import Foundation

struct StandardFeedPipelineOptions: Sendable {
    let updateTitle: Bool
    let skipImageFetch: Bool
    let skipImagePreload: Bool
    let runNLP: Bool
    var contentOnly: Bool = false
}
