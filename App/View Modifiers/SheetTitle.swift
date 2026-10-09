import SwiftUI

extension View {

    /// A sheet's title: inline in the navigation bar on iOS, and above the
    /// content on macOS, where sheets don't show their window title.
    func sheetTitle(_ title: String) -> some View {
        #if os(macOS)
        safeAreaInset(edge: .top, spacing: 0) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 4)
        }
        #else
        navigationTitle(title)
            .inlineNavigationTitle()
        #endif
    }
}
