import SwiftUI

struct BrowserOmniboxSuggestionList: View {

    let suggestions: [BrowserSuggestion]
    let selectedSuggestionID: String?
    let apply: (BrowserSuggestion) -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            ViewThatFits(in: .vertical) {
                rows
                ScrollView {
                    rows
                }
                .defaultScrollAnchor(.top)
            }
            .onChange(of: selectedSuggestionID) {
                if let selectedSuggestionID {
                    scrollProxy.scrollTo(selectedSuggestionID)
                }
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(BrowserSuggestion.Section.allCases, id: \.rawValue) { section in
                let sectionSuggestions = suggestions.filter { $0.section == section }
                if !sectionSuggestions.isEmpty {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                    ForEach(sectionSuggestions) { suggestion in
                        BrowserSuggestionRow(suggestion: suggestion) { apply(suggestion) }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(
                                suggestion.id == selectedSuggestionID ? Color.accentColor.opacity(0.15) : .clear
                            )
                            .accessibilityAddTraits(suggestion.id == selectedSuggestionID ? .isSelected : [])
                            .id(suggestion.id)
                    }
                }
            }
        }
        .padding(.bottom, 12)
    }
}
