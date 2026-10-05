import SwiftUI

struct YouTubeVideoOverlays: View {

    let isAd: Bool
    let isAdSkippable: Bool
    let isPiP: Bool
    let onSkipAd: () -> Void
    let onReturnFromPiP: () -> Void

    var body: some View {
        ZStack {
            if isPiP {
                Color.black
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "pip").font(.largeTitle)
                            Text(String(localized: "YouTube.PiP.Active", table: "Integrations"))
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .onTapGesture(perform: onReturnFromPiP)
            } else if isAd {
                VStack {
                    Spacer()
                    HStack {
                        Text(String(localized: "YouTube.Ad.Label", table: "Integrations"))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: .capsule)
                        Spacer()
                        if isAdSkippable {
                            Button(String(localized: "YouTube.Ad.Skip", table: "Integrations"), action: onSkipAd)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }
}
