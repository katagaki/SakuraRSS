import SwiftUI
import Hanami

struct TodayWeatherAlertBanner: View {

    let alert: TodayWeatherAlert
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = alert.detailsURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.summary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !alert.source.isEmpty {
                        Text(alert.source)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if alert.detailsURL != nil {
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(alert.detailsURL != nil)
    }
}
