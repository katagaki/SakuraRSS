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

                Section {
                    if let icon = customIconImage ?? currentFavicon {
                        HStack {
                            Spacer()
                            FaviconImage(icon, size: 64,
                                         cornerRadius: feed.isPodcast ? 16 : (feed.isVideoFeed ? 0 : 8),
                                         circle: feed.isVideoFeed && !feed.isPodcast,
                                         skipInset: feed.isVideoFeed || feed.isPodcast
                                            || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain))
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
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
                    Text("FeedEdit.OpenFeedsIn")
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
                        customIconImage = image
                        iconURLInput = ""
                    }
                }
            }
        }
    }

    private func loadCurrentFavicon() async -> UIImage? {
        if let customURL = feed.customIconURL {
            if customURL == "photo" {
                return await FaviconCache.shared.customFavicon(feedID: feed.id)
            }
            if let url = URL(string: customURL),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
    }

    private func save() {
        let finalCustomIconURL: String?

        if customIconImage != nil {
            finalCustomIconURL = "photo"
        } else if !iconURLInput.isEmpty {
            finalCustomIconURL = iconURLInput
        } else {
            finalCustomIconURL = nil
        }

        if let customIconImage {
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
}
