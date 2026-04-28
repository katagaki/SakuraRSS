import SwiftUI

struct ArticlesToolbar: View {

    var onMarkAllRead: () -> Void
    @State private var isShowingMarkAllReadConfirmation = false

    var body: some View {
        ActionButton(
            systemImage: "envelope.open",
            accessibilityLabel: String(localized: "MarkAllRead", table: "Articles")
        ) {
            isShowingMarkAllReadConfirmation = true
        }
        .padding()
        .popover(isPresented: $isShowingMarkAllReadConfirmation) {
            VStack(spacing: 12) {
                Text(String(localized: "MarkAllRead.Confirm", table: "Articles"))
                    .font(.body)
                Button {
                    onMarkAllRead()
                    isShowingMarkAllReadConfirmation = false
                } label: {
                    Text(String(localized: "MarkAllRead", table: "Articles"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .presentationCompactAdaptation(.popover)
        }
    }
}

extension View {
    /// Attaches the floating Mark All Read button when `show` is true.
    @ViewBuilder
    func markAllReadToolbar(
        show: Bool,
        onMarkAllRead: @escaping () -> Void
    ) -> some View {
        if show {
            self.safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
                ArticlesToolbar(onMarkAllRead: onMarkAllRead)
            }
        } else {
            self
        }
    }
}
