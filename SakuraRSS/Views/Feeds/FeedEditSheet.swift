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
    @State var useDefaultIcon = false

    init(feed: Feed) {
        self.feed = feed
        _name = State(initialValue: feed.title)
        _url = State(initialValue: feed.url)
        let existingIconURL = feed.customIconURL
        _iconURLInput = State(initialValue: (existingIconURL == "photo" || existingIconURL == "none") ? "" : (existingIconURL ?? ""))
        _useDefaultIcon = State(initialValue: existingIconURL == "none")
        let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)")
        _openMode = State(initialValue: raw.flatMap(FeedOpenMode.init(rawValue:)) ?? .inAppViewer)
        let sourceRaw = UserDefaults.standard.string(forKey: "articleSource-\(feed.id)")
        _articleSource = State(initialValue: sourceRaw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic)
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
                    if !feed.isVideoFeed && !feed.isPodcast {
                        Picker(String(localized: "FeedEdit.ArticleSource"), selection: $articleSource) {
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
                        customIconImage = image.trimmed()
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
        } else {
            finalCustomIconURL = nil
        }

        if let customIconImage, !useDefaultIcon {
            await FaviconCache.shared.setCustomFavicon(customIconImage, feedID: feed.id)
        } else if useDefaultIcon && feed.customIconURL != nil && feed.customIconURL != "none" {
            await FaviconCache.shared.removeCustomFavicon(feedID: feed.id)
        }

        feedManager.updateFeedDetails(feed, title: name, url: url,
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
