import PhotosUI
import SwiftUI

struct FeedEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let feed: Feed

    @State private var name: String = ""
    @State private var url: String = ""
    @State var iconURLInput: String = ""
    @State private var openMode: FeedOpenMode = .inAppViewer
    @State private var articleSource: ArticleSource = .automatic
    @State var selectedPhoto: PhotosPickerItem?
    @State var customIconImage: UIImage?
    @State var currentFavicon: UIImage?
    @State var isFetchingIcon = false
    @State var showIconFetchError = false
    @State var useDefaultIcon = false
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("FeedEdit.Name")
                        TextField("FeedEdit.Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                            .labelsHidden()
                    }
                    if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
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
                            TextField("FeedEdit.URL", text: $url)
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
                            if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                                FaviconImage(acronym, size: 64,
                                             cornerRadius: iconCornerRadius(size: 64),
                                             circle: feed.isCircleIcon,
                                             skipInset: true)
                            } else {
                                InitialsAvatarView(
                                    name.isEmpty ? feed.title : name,
                                    size: 64,
                                    circle: feed.isCircleIcon,
                                    cornerRadius: iconCornerRadius(size: 64)
                                )
                            }
                            Spacer()
                        }
                    } else if let icon = customIconImage ?? currentFavicon {
                        HStack {
                            Spacer()
                            FaviconImage(
                                icon, size: 64,
                                cornerRadius: iconCornerRadius(size: 64),
                                circle: feed.isCircleIcon,
                                skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                                    || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain)
                            )
                            Spacer()
                        }
                    }

                    HStack {
                        Text("FeedEdit.IconURL")
                        TextField("FeedEdit.IconURLPlaceholder", text: $iconURLInput)
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

                if !feed.isXFeed && !feed.isInstagramFeed && !feed.isYouTubePlaylistFeed {
                    Section {
                        Picker("FeedEdit.OpenIn", selection: $openMode) {
                            Text("FeedEdit.OpenIn.InAppViewer")
                                .tag(FeedOpenMode.inAppViewer)
                            Text("FeedEdit.OpenIn.InAppBrowser")
                                .tag(FeedOpenMode.inAppBrowser)
                            Text("FeedEdit.OpenIn.Browser")
                                .tag(FeedOpenMode.browser)
                        }
                        if !feed.isVideoFeed && !feed.isPodcast {
                            Picker("FeedEdit.ArticleSource", selection: $articleSource) {
                                Text("FeedEdit.ArticleSource.Automatic")
                                    .tag(ArticleSource.automatic)
                                Text("FeedEdit.ArticleSource.FetchText")
                                    .tag(ArticleSource.fetchText)
                                Text("FeedEdit.ArticleSource.ExtractText")
                                    .tag(ArticleSource.extractText)
                                Text("FeedEdit.ArticleSource.FeedText")
                                    .tag(ArticleSource.feedText)
                            }
                        }
                    } header: {
                        Text("FeedEdit.Behavior")
                    }
                }
            }
            .navigationTitle("FeedEdit.Title")
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
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                name = feed.title
                if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
                    url = feed.siteURL
                } else {
                    url = feed.url
                }
                let existingIconURL = feed.customIconURL
                iconURLInput = (
                    existingIconURL == "photo" || existingIconURL == "none"
                ) ? "" : (existingIconURL ?? "")
                useDefaultIcon = existingIconURL == "none"
                let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)")
                openMode = raw.flatMap(FeedOpenMode.init(rawValue:)) ?? .inAppViewer
                let sourceRaw = UserDefaults.standard.string(forKey: "articleSource-\(feed.id)")
                articleSource = sourceRaw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
            }
            .task {
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
                    }
                }
            }
            .alert("FeedEdit.IconFetchError", isPresented: $showIconFetchError) {
                Button("Shared.OK", role: .cancel) { }
            }
        }
    }

    private func save() {
        let iconURLChanged = !iconURLInput.isEmpty && iconURLInput != feed.customIconURL
        if customIconImage == nil && iconURLChanged {
            Task {
                if await fetchIconFromURL() {
                    await commitSave()
                }
            }
        } else {
            Task {
                await commitSave()
            }
        }
    }

    private func commitSave() async {
        let finalCustomIconURL: String?

        if useDefaultIcon {
            finalCustomIconURL = "none"
        } else if customIconImage != nil {
            finalCustomIconURL = "photo"
        } else if !iconURLInput.isEmpty {
            finalCustomIconURL = iconURLInput
        } else if feed.customIconURL == "photo" {
            // User made no icon changes; preserve the existing custom
            // photo (for Instagram/X feeds this is the auto-downloaded
            // profile photo).  `iconURLInput` was intentionally emptied
            // on load because "photo" is a sentinel, not a URL, so we
            // can't rely on the URL branch above to carry it through.
            finalCustomIconURL = "photo"
        } else {
            finalCustomIconURL = nil
        }

        if let customIconImage, !useDefaultIcon {
            await FaviconCache.shared.setCustomFavicon(customIconImage, feedID: feed.id)
        } else if useDefaultIcon && feed.customIconURL != nil && feed.customIconURL != "none" {
            await FaviconCache.shared.removeCustomFavicon(feedID: feed.id)
        }

        // For X, Instagram, and YouTube playlist feeds the editable "URL"
        // field shows the site URL for readability, but the database stores
        // a pseudo-feed URL (e.g. `x-profile://handle`) that encodes the
        // feed type.  Always preserve the original `feed.url` for these
        // feeds so that overwriting the title doesn't silently convert
        // them into a regular feed.
        let urlToSave: String
        if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
            urlToSave = feed.url
        } else {
            urlToSave = url
        }
        feedManager.updateFeedDetails(feed, title: name, url: urlToSave,
                                      customIconURL: finalCustomIconURL)
        UserDefaults.standard.set(openMode.rawValue, forKey: "openMode-\(feed.id)")
        if articleSource == .automatic {
            UserDefaults.standard.removeObject(forKey: "articleSource-\(feed.id)")
        } else {
            UserDefaults.standard.set(articleSource.rawValue, forKey: "articleSource-\(feed.id)")
        }
        dismiss()
    }

}
