import Hanami
import SwiftUI

struct BrowsingSettingsPane: View {

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .items25
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent = false
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead = false
    @AppStorage(LinkOpenMode.storageKey) private var linkOpenMode: LinkOpenMode = .inAppViewer
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode = false
    @AppStorage(UnreadBadgeMode.storageKey) private var unreadBadgeMode: UnreadBadgeMode = .none

    private var showsDockBadge: Binding<Bool> {
        Binding {
            unreadBadgeMode == .homeScreenOnly
        } set: { isOn in
            unreadBadgeMode = isOn ? .homeScreenOnly : .none
        }
    }

    var body: some View {
        SettingsForm {
            Group {
                LabeledContent(SettingsText.settings("UnreadBadgeMode")) {
                    Toggle(String(localized: "Settings.DockBadge", table: "Mac"), isOn: showsDockBadge)
                }
            }
            SettingsGroupSpacer()
            Group {
                LabeledContent(SettingsText.settings("Section.Feeds")) {
                    Toggle(SettingsText.settings("HideViewedContent"), isOn: $hideViewedContent)
                        .disabled(doomscrollingMode)
                }
                SettingsPicker(SettingsText.settings("BatchingMode"), selection: $batchingMode) {
                    Text(SettingsText.settings("Batching.Day1")).tag(BatchingMode.day1)
                    Text(SettingsText.settings("Batching.Day3")).tag(BatchingMode.day3)
                    Text(SettingsText.settings("Batching.Week1")).tag(BatchingMode.week1)
                    Divider()
                    Text(SettingsText.settings("Batching.Items25")).tag(BatchingMode.items25)
                    Text(SettingsText.settings("Batching.Items50")).tag(BatchingMode.items50)
                    Text(SettingsText.settings("Batching.Items100")).tag(BatchingMode.items100)
                    Divider()
                    Text(SettingsText.settings("Batching.Off")).tag(BatchingMode.off)
                }
                .disabled(doomscrollingMode)
                LabeledContent {
                    SettingsNote(text: SettingsText.settings("Batching.Footer"))
                } label: {
                    Text(verbatim: "")
                }
            }
            SettingsGroupSpacer()
            Group {
                LabeledContent(SettingsText.settings("Section.Scrolling")) {
                    Toggle(SettingsText.settings("ScrollMarkAsRead"), isOn: $scrollMarkAsRead)
                        .disabled(doomscrollingMode)
                }
                LabeledContent(SettingsText.settings("Section.Doomscrolling")) {
                    Toggle(SettingsText.settings("Doomscrolling.Enable"), isOn: $doomscrollingMode)
                }
            }
            SettingsGroupSpacer()
            Group {
                SettingsPicker(SettingsText.settings("LinkOpenMode"), selection: $linkOpenMode) {
                    Text(SettingsText.settings("LinkOpenMode.Browser")).tag(LinkOpenMode.browser)
                    Text(SettingsText.settings("LinkOpenMode.InAppViewer")).tag(LinkOpenMode.inAppViewer)
                }
            }
        }
    }
}
