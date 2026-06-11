import SwiftUI
import Hanami

struct BookmarkFolderHeaderView: View {

    @Environment(FeedManager.self) var feedManager
    let folder: BookmarkFolder

    @State private var isEditingFolder: Bool = false
    @State private var isShowingDeleteDialog: Bool = false

    private let iconSize: CGFloat = 64
    private let iconCornerRadius: CGFloat = 14
    private let buttonHeight: CGFloat = 36

    @Namespace private var namespace
    @Namespace private var editNamespace

    var body: some View {
        VStack(spacing: 8) {
            BorderedIcon(
                systemImage: folder.icon,
                background: ListIcon.gradient(forRawValue: folder.icon),
                size: iconSize,
                iconSizeFactor: 0.45,
                cornerRadius: iconCornerRadius
            )
            .padding(.bottom, 4)

            Text(folder.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            actionButtons
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .sheet(isPresented: $isEditingFolder) {
            BookmarkFolderEditSheet(folder: folder)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .navigationTransition(.zoom(sourceID: folder.id, in: editNamespace))
        }
        .confirmationDialog(
            String(localized: "FolderMenu.Delete.Title", table: "Articles"),
            isPresented: $isShowingDeleteDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "FolderMenu.Delete.DeleteBookmarks", table: "Articles"),
                   role: .destructive) {
                feedManager.deleteBookmarkFolder(folder, removeBookmarks: true)
            }
            Button(String(localized: "FolderMenu.Delete.KeepBookmarks", table: "Articles")) {
                feedManager.deleteBookmarkFolder(folder, removeBookmarks: false)
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "FolderMenu.Delete.Message.\(folder.name)", table: "Articles"))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        CompatibleGlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Button {
                    isEditingFolder = true
                } label: {
                    Text(String(localized: "FolderHeader.Edit", table: "Articles"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: buttonHeight)
                        .matchedTransitionSource(id: folder.id, in: editNamespace)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .compatibleGlassEffectID("FolderEdit", in: namespace)

                Button(role: .destructive) {
                    isShowingDeleteDialog = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: buttonHeight, height: buttonHeight)
                }
                .compatibleGlassButtonStyle()
                .buttonBorderShape(.circle)
                .tint(.red)
                .accessibilityLabel(String(localized: "FolderMenu.Delete", table: "Articles"))
                .compatibleGlassEffectID("FolderDelete", in: namespace)

                Spacer(minLength: 0)
            }
        }
    }
}
