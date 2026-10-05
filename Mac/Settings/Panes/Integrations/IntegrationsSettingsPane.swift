import Hanami
import SwiftUI

/// Laid out like Safari's Websites settings: the integrations listed on the
/// left, the selected one's settings on the right.
struct IntegrationsSettingsPane: View {

    @State private var selection: Integration = .webFeeds

    private var listSelection: Binding<Integration?> {
        Binding(get: { selection }, set: { if let newSelection = $0 { selection = newSelection } })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            List(Integration.allCases, selection: listSelection) { integration in
                Label {
                    Text(integration.title)
                } icon: {
                    IntegrationIcon(integration: integration, size: 20)
                }
                .tag(integration)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.fill.quinary, in: .rect(cornerRadius: 10))
            .frame(width: 210)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        IntegrationIcon(integration: selection, size: 32)
                        Text(selection.title)
                            .font(.title3.bold())
                    }
                    IntegrationDetail(integration: selection)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(.fill.quinary, in: .rect(cornerRadius: 10))
        }
        .toggleStyle(.checkbox)
        .padding(20)
        .frame(width: 780, height: 460)
    }
}

private struct IntegrationDetail: View {

    let integration: Integration

    var body: some View {
        switch integration {
        case .webFeeds: WebFeedsIntegrationSettings()
        case .podcasts: PodcastIntegrationSettings()
        case .instagram: InstagramIntegrationSettings()
        case .substack: SubstackIntegrationSettings()
        case .x: XIntegrationSettings()
        case .youtube: YouTubeIntegrationSettings()
        }
    }
}
