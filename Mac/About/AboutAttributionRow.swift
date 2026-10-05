import SwiftUI

/// A project's name and license that expands to its license text when
/// clicked anywhere, not only on the chevron as a disclosure group is.
struct AboutAttributionRow: View {

    let dependency: Dependency
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(dependency.name)
                    Spacer()
                    Text(dependency.license)
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if isExpanded {
                Text(dependency.licenseText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
                    .padding(.vertical, 4)
            }
        }
    }
}
