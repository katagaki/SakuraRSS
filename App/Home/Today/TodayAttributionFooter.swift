import SwiftUI

struct TodayAttributionFooter: View {

    private static let attributedText: AttributedString = {
        let prefix = String(localized: "Today.WeatherAttribution.Prefix", table: "Home")
        let linkLabel = String(localized: "Today.WeatherAttribution.Link", table: "Home")
        let markdown = "\(prefix) [\(linkLabel)](https://developer.apple.com/weatherkit/data-source-attribution/)"
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }()

    var body: some View {
        VStack(spacing: 16) {
            Divider()
            Text(Self.attributedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
}
