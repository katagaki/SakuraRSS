import SwiftUI

struct HideReadContentToggle: View {

    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(String(localized: "HideReadContent", table: "Articles"), systemImage: "eye.slash")
        }
    }
}
