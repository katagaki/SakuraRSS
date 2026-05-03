import SwiftUI

struct AfternoonBriefView: View {

    @Binding var hasSummary: Bool
    var isVisible: Binding<Bool>?

    var body: some View {
        SummaryCard(
            kind: .afternoonBrief,
            hasSummary: $hasSummary,
            isVisible: isVisible
        )
    }
}
