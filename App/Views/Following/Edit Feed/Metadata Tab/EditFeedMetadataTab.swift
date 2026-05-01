import PhotosUI
import SwiftUI

struct EditFeedMetadataTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedID: Int64

    @State var name: String = ""
    @State var url: String = ""
    @State var iconURLInput: String = ""
    @State var useDefaultIcon: Bool = false
    @State var selectedPhoto: PhotosPickerItem?
    @State var customIconImage: UIImage?
    @State var currentFavicon: UIImage?
    @State var isFetchingIcon = false
    @State var showIconFetchError = false
    @State var showPetalBuilder = false
    @State private var hasInitialized = false

    var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        Group {
            if let feed {
                metadataList(for: feed)
            } else {
                Color.clear
            }
        }
        .onAppear { initializeStateIfNeeded() }
        .task(id: feedID) {
            currentFavicon = await loadCurrentFavicon()
        }
        .onChange(of: selectedPhoto) {
            Task {
                if let selectedPhoto,
                   let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    customIconImage = image.trimmed()
                    iconURLInput = ""
                    useDefaultIcon = false
                    commitNameAndIcon()
                }
            }
        }
        .alert(String(localized: "FeedEdit.IconFetchError", table: "Feeds"),
               isPresented: $showIconFetchError) {
            Button("Shared.OK", role: .cancel) { }
        }
        .sheet(isPresented: $showPetalBuilder) {
            if let feed, let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) {
                PetalBuilderView(mode: .edit(feed: feed, recipe: recipe))
                    .environment(feedManager)
            }
        }
    }

    @ViewBuilder
    private func metadataList(for feed: Feed) -> some View {
        Form {
            nameSection(for: feed)
            petalSection(for: feed)
            iconSection(for: feed)
            muteSection(for: feed)
        }
    }

    @ViewBuilder
    private func muteSection(for feed: Feed) -> some View {
        Section {
            Toggle(String(localized: "FeedMenu.Mute", table: "Feeds"),
                   isOn: Binding(
                    get: { feed.isMuted },
                    set: { _ in feedManager.toggleMuted(feed) }
                   ))
        }
    }

    func initializeStateIfNeeded() {
        guard !hasInitialized, let feed else { return }
        hasInitialized = true
        name = feed.title
        url = (feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed)
            ? feed.siteURL : feed.fetchURL
        let existingIconURL = feed.customIconURL
        iconURLInput = (existingIconURL == "photo" || existingIconURL == "none")
            ? "" : (existingIconURL ?? "")
        useDefaultIcon = existingIconURL == "none"
    }

    func commitNameAndIcon() {
        guard hasInitialized, let feed else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let effectiveName = trimmedName.isEmpty ? feed.title : trimmedName
        let effectiveURL = computedURLToSave(for: feed)
        let finalIconURL = computeFinalIconURL(for: feed)

        guard effectiveName != feed.title
                || effectiveURL != feed.url
                || finalIconURL != feed.customIconURL
                || customIconImage != nil else { return }

        Task {
            if let customIconImage, !useDefaultIcon {
                await FaviconCache.shared.setCustomFavicon(
                    customIconImage, feedID: feed.id, skipTrimming: true
                )
            } else if useDefaultIcon && feed.customIconURL != nil && feed.customIconURL != "none" {
                await FaviconCache.shared.removeCustomFavicon(feedID: feed.id)
            }
            await MainActor.run {
                feedManager.updateFeedDetails(
                    feed, title: effectiveName, url: effectiveURL,
                    customIconURL: finalIconURL
                )
            }
        }
    }

    private func computedURLToSave(for feed: Feed) -> String {
        if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
            return feed.url
        } else if feed.isSubstackFeed {
            return SubstackAuth.wrap(url)
        } else {
            return url
        }
    }

    private func computeFinalIconURL(for feed: Feed) -> String? {
        if useDefaultIcon { return "none" }
        if customIconImage != nil { return "photo" }
        if !iconURLInput.isEmpty { return iconURLInput }
        if feed.customIconURL == "photo" { return "photo" }
        return nil
    }
}
