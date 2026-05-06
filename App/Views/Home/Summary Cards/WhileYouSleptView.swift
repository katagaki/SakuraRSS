import SwiftUI

struct WhileYouSleptView: View {

    @Binding var hasSummary: Bool
    var flatStyle: Bool = false
    var isVisible: Binding<Bool>?
    var refreshTrigger: Int = 0

    var body: some View {
        SummarySection(
            kind: .whileYouSlept,
            hasSummary: $hasSummary,
            flatStyle: flatStyle,
            isVisible: isVisible,
            refreshTrigger: refreshTrigger
        )
    }
}
