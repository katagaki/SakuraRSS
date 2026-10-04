import Hanami
import SwiftUI

struct FocusSettingsPane: View {

    let feedManager: FeedManager

    private let steps: [String.LocalizationValue] = [
        "Focus.Settings.Setup.Step1", "Focus.Settings.Setup.Step2",
        "Focus.Settings.Setup.Step3", "Focus.Settings.Setup.Step4"
    ]

    var body: some View {
        SettingsForm {
            Group {
                LabeledContent(SettingsText.settings("Section.Focus")) {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsNote(text: SettingsText.settings("Focus.Settings.Explanation"))
                        if feedManager.isFocusActive {
                            Label(SettingsText.settings("Focus.Settings.Active"), systemImage: "moon.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            SettingsGroupSpacer()
            Group {
                LabeledContent(SettingsText.settings("Focus.Settings.Setup.Title")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1).")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text(SettingsText.settings(step))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: 360, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}
