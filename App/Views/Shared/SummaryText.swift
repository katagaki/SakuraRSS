import SwiftUI

struct SummaryText: View {

    let summary: String
    @State private var cached: String = ""

    var body: some View {
        Text(cached)
            .task {
                cached = ContentBlock.stripMarkdown(summary)
            }
    }
}
