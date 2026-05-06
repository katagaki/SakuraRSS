import SwiftUI

struct AfternoonBriefView: View {

    @Binding var hasSummary: Bool
    var isVisible: Binding<Bool>?
    var refreshTrigger: Int = 0

    var body: some View {
        SummarySection(
            kind: .afternoonBrief,
            hasSummary: $hasSummary,
            isVisible: isVisible,
            refreshTrigger: refreshTrigger
        )
    }
}
