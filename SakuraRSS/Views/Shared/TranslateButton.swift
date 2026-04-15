import SwiftUI

struct TranslateButton: View {

    var hasTranslation: Bool
    var isTranslating: Bool
    @Binding var showingTranslation: Bool
    var onTranslate: () -> Void

    var body: some View {
        if hasTranslation && !isTranslating {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation.toggle()
                }
            } label: {
                Label(
                    showingTranslation
                        ? String(localized: "Article.ShowOriginal", table: "Articles")
                        : String(localized: "Article.ShowTranslation", table: "Articles"),
                    systemImage: showingTranslation
                        ? "doc.plaintext" : "translate"
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        } else {
            Button {
                onTranslate()
            } label: {
                Label(
                    String(localized: "Article.Translate", table: "Articles"),
                    systemImage: "translate"
                )
                .opacity(isTranslating ? 0 : 1)
                .overlay {
                    if isTranslating {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .disabled(isTranslating)
            .animation(.smooth.speed(2.0), value: isTranslating)
        }
    }
}
