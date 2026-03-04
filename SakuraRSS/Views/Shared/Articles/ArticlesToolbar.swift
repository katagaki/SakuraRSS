import SwiftUI

struct ArticlesToolbar: View {

    var onMarkAllRead: () -> Void
    @State private var isShowingMarkAllReadConfirmation = false

    var body: some View {
        Button {
            isShowingMarkAllReadConfirmation = true
        } label: {
            Image(systemName: "envelope.open")
                .font(.title2)
                .padding(8)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding()
        .popover(isPresented: $isShowingMarkAllReadConfirmation) {
            VStack(spacing: 12) {
                Text("Articles.MarkAllRead.Confirm")
                    .font(.body)
                Button {
                    onMarkAllRead()
                    isShowingMarkAllReadConfirmation = false
                } label: {
                    Text("Articles.MarkAllRead")
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
