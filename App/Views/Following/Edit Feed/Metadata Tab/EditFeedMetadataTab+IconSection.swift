import PhotosUI
import SwiftUI

extension EditFeedMetadataTab {

    @ViewBuilder
    func iconSection(for feed: Feed) -> some View {
        Section {
            iconPreview(for: feed)
            iconURLField
            photosPickerRow
            fetchIconButton
            deleteIconButton(for: feed)
        } header: {
            Text(String(localized: "FeedEdit.Icon", table: "Feeds"))
        }
    }

    @ViewBuilder
    private func iconPreview(for feed: Feed) -> some View {
        if useDefaultIcon {
            HStack {
                Spacer()
                if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                    IconImage(acronym, size: 64,
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
        } else if let icon = customIconImage ?? currentIcon {
            HStack {
                Spacer()
                IconImage(
                    icon, size: 64,
                    cornerRadius: iconCornerRadius(size: 64),
                    circle: feed.isCircleIcon,
                    skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                )
                Spacer()
            }
        }
    }

    private var iconURLField: some View {
        HStack {
            Text(String(localized: "FeedEdit.IconURL", table: "Feeds"))
            TextField(String("https://example.com/icon.png"), text: $iconURLInput)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .labelsHidden()
                .onSubmit {
                    Task {
                        if await fetchIconFromURL() {
                            commitNameAndIcon()
                        }
                    }
                }
            if isFetchingIcon {
                ProgressView()
            }
        }
    }

    private var photosPickerRow: some View {
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
    }

    private var fetchIconButton: some View {
        Button {
            Task {
                await fetchIconFromFeed()
                commitNameAndIcon()
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
    }

    @ViewBuilder
    private func deleteIconButton(for feed: Feed) -> some View {
        if !useDefaultIcon && (feed.customIconURL != nil || currentIcon != nil) {
            Button(role: .destructive) {
                useDefaultIcon = true
                customIconImage = nil
                selectedPhoto = nil
                iconURLInput = ""
                commitNameAndIcon()
            } label: {
                Text(String(localized: "FeedEdit.DeleteIcon", table: "Feeds"))
            }
        }
    }
}
