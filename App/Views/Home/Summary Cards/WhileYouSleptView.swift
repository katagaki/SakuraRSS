import SwiftUI

struct WhileYouSleptView: View {

    @Binding var hasSummary: Bool
    var flatStyle: Bool = false
    var isVisible: Binding<Bool>?

    var body: some View {
        SummaryCard(
            kind: .whileYouSlept,
            hasSummary: $hasSummary,
            flatStyle: flatStyle,
            isVisible: isVisible
        )
    }
}
