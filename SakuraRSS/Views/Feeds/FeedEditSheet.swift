import PhotosUI
import SwiftUI

struct FeedEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let feed: Feed

    @State private var name: String
    @State private var url: String
    @State var iconURLInput: String
    @State private var openMode: FeedOpenMode
    @State private var articleSource: ArticleSource
    @State var selectedPhoto: PhotosPickerItem?
    @State var customIconImage: UIImage?
    @State var currentFavicon: UIImage?
    @State var isFetchingIcon = false
    @State var showIconFetchError = false
    @State var useDefaultIcon: Bool
    @State private var showPetalBuilder = false

    init(feed: Feed) {
        self.feed = feed
        let defaultURL: String = (feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed)
            ? feed.siteURL : feed.url
        let existingIconURL = feed.customIconURL
        let defaultIconURLInput = (
            existingIconURL == "photo" || existingIconURL == "none"
        ) ? "" : (existingIconURL ?? "")
        let defaultUseDefaultIcon = existingIconURL == "none"
        let defaultOpenMode: FeedOpenMode = {
            let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)")
            return raw.flatMap(FeedOpenMode.init(rawValue:)) ?? .inAppViewer
        }()
        let defaultArticleSource: ArticleSource = {
            let raw = UserDefaults.standard.string(forKey: "articleSource-\(feed.id)")
            return raw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
        }()

        _name = State(initialValue: feed.title)
        _url = State(initialValue: defaultURL)
        _iconURLInput = State(initialValue: defaultIconURLInput)
        _useDefaultIcon = State(initialValue: defaultUseDefaultIcon)
        _openMode = State(initialValue: defaultOpenMode)
        _articleSource = State(initialValue: defaultArticleSource)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(String(localized: "FeedEdit.Name", table: "Feeds"))
                        TextField(String(localized: "FeedEdit.Name", table: "Feeds"), text: $name)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                            .labelsHidden()
                    }
                    if feed.isXFeed || feed.isInstagramFeed || feed.isYouTubePlaylistFeed {
                        HStack {
                            Text(String(localized: "FeedEdit.URL", table: "Feeds"))
                            Spacer()
                            Text(feed.siteURL)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else if !PetalRecipe.isPetalFeedURL(feed.url) {
                        HStack {
                            Text(String(localized: "FeedEdit.URL", table: "Feeds"))
                            TextField(String(localized: "FeedEdit.URL", table: "Feeds"), text: $url)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .labelsHidden()
                        }
                    }
                }

                if PetalRecipe.isPetalFeedURL(feed.url) {
                    Section {
                        if let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) {
                            HStack {
                                Text(String(localized: "FeedEdit.SourceURL", table: "Petal"))
                                Spacer()
                                Text(recipe.siteURL)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Button {
                            showPetalBuilder = true
                        } label: {
                            Label(String(localized: "FeedEdit.EditRecipe", table: "Petal"), systemImage: "wand.and.stars")
                        }
                    } header: {
                        Text(String(localized: "FeedEdit.Header", table: "Petal"))
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
                        Text(String(localized: "FeedEdit.IconURL", table: "Feeds"))
                        TextField(String(localized: "FeedEdit.IconURLPlaceholder", table: "Feeds"), text: $iconURLInput)
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
                            Text(String(localized: "FeedEdit.ChooseFromPhotos", table: "Feeds"))
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
                            Text(String(localized: "FeedEdit.FetchIconFromFeed", table: "Feeds"))
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
                            Text(String(localized: "FeedEdit.DeleteIcon", table: "Feeds"))
                        }
                    }
                } header: {
                    Text(String(localized: "FeedEdit.Icon", table: "Feeds"))
                }

                if !feed.isXFeed && !feed.isInstagramFeed && !feed.isYouTubePlaylistFeed {
                    Section {
                        Picker(String(localized: "FeedEdit.OpenIn", table: "Feeds"), selection: $openMode) {
                            Text(String(localized: "FeedEdit.OpenIn.InAppViewer", table: "Feeds"))
                                .tag(FeedOpenMode.inAppViewer)
                            Divider()
                            Text(String(localized: "FeedEdit.OpenIn.Browser", table: "Feeds"))
                                .tag(FeedOpenMode.browser)
                            Text(String(localized: "FeedEdit.OpenIn.InAppBrowser", table: "Feeds"))
                                .tag(FeedOpenMode.inAppBrowser)
                            Text(String(localized: "FeedEdit.OpenIn.InAppBrowserReader", table: "Feeds"))
                                .tag(FeedOpenMode.inAppBrowserReader)
                            Divider()
                            Text(String(localized: "FeedEdit.OpenIn.ClearThisPage", table: "Feeds"))
                                .tag(FeedOpenMode.clearThisPage)
                            Text(String(localized: "FeedEdit.OpenIn.ArchivePh", table: "Feeds"))
                                .tag(FeedOpenMode.archivePh)
                        }
                        if !feed.isVideoFeed && !feed.isPodcast {
                            Picker(String(localized: "FeedEdit.ArticleSource", table: "Feeds"), selection: $articleSource) {
                                Text(String(localized: "FeedEdit.ArticleSource.Automatic", table: "Feeds"))
                                    .tag(ArticleSource.automatic)
                                Text(String(localized: "FeedEdit.ArticleSource.FetchText", table: "Feeds"))
                                    .tag(ArticleSource.fetchText)
                                Text(String(localized: "FeedEdit.ArticleSource.ExtractText", table: "Feeds"))
                                    .tag(ArticleSource.extractText)
                                Text(String(localized: "FeedEdit.ArticleSource.FeedText", table: "Feeds"))
                                    .tag(ArticleSource.feedText)
                            }
                        }
                    } header: {
                        Text(String(localized: "FeedEdit.Behavior", table: "Feeds"))
                    }
                }
            }
            .navigationTitle(String(localized: "FeedEdit.Title", table: "Feeds"))
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
                        customIconImage = image.trimmed()
                        iconURLInput = ""
                        useDefaultIcon = false
                    }
                }
            }
            .alert(String(localized: "FeedEdit.IconFetchError", table: "Feeds"), isPresented: $showIconFetchError) {
                Button("Shared.OK", role: .cancel) { }
            }
        }
        .sheet(isPresented: $showPetalBuilder) {
            if let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) {
                PetalBuilderView(mode: .edit(feed: feed, recipe: recipe))
                    .environment(feedManager)
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
