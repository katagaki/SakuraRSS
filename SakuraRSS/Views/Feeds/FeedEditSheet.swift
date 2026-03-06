import PhotosUI
import SwiftUI

struct FeedEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let feed: Feed

    @State private var name: String
    @State private var url: String
    @State private var iconURLInput: String
    @State private var openMode: FeedOpenMode
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var customIconImage: UIImage?
    @State private var currentFavicon: UIImage?
    @State private var isFetchingIcon = false
    @State private var showIconFetchError = false
    @State private var useDefaultIcon = false

    init(feed: Feed) {
        self.feed = feed
        _name = State(initialValue: feed.title)
        _url = State(initialValue: feed.url)
        let existingIconURL = feed.customIconURL
        _iconURLInput = State(initialValue: existingIconURL == "photo" ? "" : (existingIconURL ?? ""))
        let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)")
        _openMode = State(initialValue: raw.flatMap(FeedOpenMode.init(rawValue:)) ?? .inAppViewer)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("FeedEdit.Name")
                        TextField(String(localized: "FeedEdit.Name"), text: $name)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                            .labelsHidden()
                    }
                    if feed.isXFeed {
                        HStack {
                            Text("FeedEdit.URL")
                            Spacer()
                            Text(feed.siteURL)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        HStack {
                            Text("FeedEdit.URL")
                            TextField(String(localized: "FeedEdit.URL"), text: $url)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .labelsHidden()
                        }
                    }
                }

                Section {
                    if useDefaultIcon {
                        HStack {
                            Spacer()
                            InitialsAvatarView(
                                name.isEmpty ? feed.title : name,
                                size: 64,
                                circle: feed.isXFeed || (feed.isVideoFeed && !feed.isPodcast),
                                cornerRadius: iconCornerRadius(size: 64)
                            )
                            Spacer()
                        }
                    } else if let icon = customIconImage ?? currentFavicon {
                        HStack {
                            Spacer()
                            FaviconImage(icon, size: 64,
                                         cornerRadius: iconCornerRadius(size: 64),
                                         circle: feed.isXFeed || (feed.isVideoFeed && !feed.isPodcast),
                                         skipInset: feed.isVideoFeed || feed.isPodcast || feed.isXFeed
                                            || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain))
                            Spacer()
                        }
                    }

                    HStack {
                        Text("FeedEdit.IconURL")
                        TextField(String(localized: "FeedEdit.IconURLPlaceholder"), text: $iconURLInput)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .labelsHidden()
                            .onSubmit {
                                Task {
                                    await fetchIconFromURL()
                                }
                            }
                        if isFetchingIcon {
                            ProgressView()
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Text("FeedEdit.ChooseFromPhotos")
                            Spacer()
                            if customIconImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Button {
                        Task {
                            await fetchIconFromFeed()
                        }
                    } label: {
                        HStack {
                            Text("FeedEdit.FetchIconFromFeed")
                            Spacer()
                            if isFetchingIcon {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isFetchingIcon)

                    if !useDefaultIcon && (feed.customIconURL != nil || currentFavicon != nil) {
                        Button(role: .destructive) {
                            useDefaultIcon = true
                            customIconImage = nil
                            selectedPhoto = nil
                            iconURLInput = ""
                        } label: {
                            Text("FeedEdit.DeleteIcon")
                        }
                    }
                } header: {
                    Text("FeedEdit.Icon")
                }

                Section {
                    Picker(String(localized: "FeedEdit.OpenIn"), selection: $openMode) {
                        Text("FeedEdit.OpenIn.InAppViewer")
                            .tag(FeedOpenMode.inAppViewer)
                        Text("FeedEdit.OpenIn.InAppBrowser")
                            .tag(FeedOpenMode.inAppBrowser)
                        Text("FeedEdit.OpenIn.Browser")
                            .tag(FeedOpenMode.browser)
                    }
                } header: {
                    Text("FeedEdit.Behavior")
                }
            }
            .navigationTitle(String(localized: "FeedEdit.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
            .task {
                currentFavicon = await loadCurrentFavicon()
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let selectedPhoto,
                       let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        customIconImage = await image.trimmed()
                        iconURLInput = ""
                        useDefaultIcon = false
                    }
                }
            }
            .alert(String(localized: "FeedEdit.IconFetchError"), isPresented: $showIconFetchError) {
                Button(String(localized: "Shared.OK"), role: .cancel) { }
            }
        }
    }

    private func loadCurrentFavicon() async -> UIImage? {
        if let customURL = feed.customIconURL {
            if customURL == "photo" {
                return await FaviconCache.shared.customFavicon(feedID: feed.id)
            }
            // Check if already cached for this feed
            if let cached = await FaviconCache.shared.customFavicon(feedID: feed.id) {
                return cached
            }
            // Download, cache locally, then return
            if let url = URL(string: customURL),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                await FaviconCache.shared.setCustomFavicon(image, feedID: feed.id)
                return image
            }
        }
        return await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
    }

    private func save() {
        let iconURLChanged = !iconURLInput.isEmpty && iconURLInput != feed.customIconURL
        if customIconImage == nil && iconURLChanged {
            Task {
                if await fetchIconFromURL() {
                    commitSave()
                }
            }
        } else {
            commitSave()
        }
    }

    private func commitSave() {
        let finalCustomIconURL: String?

        if useDefaultIcon {
            finalCustomIconURL = nil
        } else if customIconImage != nil {
            finalCustomIconURL = "photo"
        } else if !iconURLInput.isEmpty {
            finalCustomIconURL = iconURLInput
        } else {
            finalCustomIconURL = nil
        }

        if let customIconImage, !useDefaultIcon {
            Task {
                await FaviconCache.shared.setCustomFavicon(customIconImage, feedID: feed.id)
            }
        } else if finalCustomIconURL == nil && feed.customIconURL != nil {
            Task {
                await FaviconCache.shared.removeCustomFavicon(feedID: feed.id)
            }
        }

        feedManager.updateFeedDetails(feed, title: name, url: url,
                                      customIconURL: finalCustomIconURL)
        UserDefaults.standard.set(openMode.rawValue, forKey: "openMode-\(feed.id)")
        dismiss()
    }

    private func iconCornerRadius(size: CGFloat) -> CGFloat {
        if feed.isPodcast { return size / 4 }
        if feed.isVideoFeed { return 0 }
        return size / 8
    }

    private func fetchIconFromFeed() async {
        isFetchingIcon = true
        defer { isFetchingIcon = false }
        await FaviconCache.shared.refreshFavicons(for: [(domain: feed.domain, siteURL: feed.siteURL)])
        if let image = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL) {
            customIconImage = nil
            currentFavicon = image
            selectedPhoto = nil
            iconURLInput = ""
            useDefaultIcon = false
        }
    }

    @discardableResult
    private func fetchIconFromURL() async -> Bool {
        let input = iconURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: input), url.scheme != nil else {
            showIconFetchError = true
            return false
        }
        isFetchingIcon = true
        defer { isFetchingIcon = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                customIconImage = await image.trimmed()
                selectedPhoto = nil
                useDefaultIcon = false
                return true
            }
        } catch {
            // Icon fetch failed — show error below
        }
        showIconFetchError = true
        return false
    }
}
