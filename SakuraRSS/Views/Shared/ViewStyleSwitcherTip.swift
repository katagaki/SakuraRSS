import TipKit

struct ViewStyleSwitcherTip: Tip {

    @Parameter
    static var hasCompletedOnboarding: Bool = false

    var title: Text {
        Text(String(localized: "Tip.ViewStyleSwitcher.Title", table: "Onboarding"))
    }

    var message: Text? {
        Text(String(localized: "Tip.ViewStyleSwitcher.Message", table: "Onboarding"))
    }

    var rules: [Rule] {
        #Rule(Self.$hasCompletedOnboarding) { $0 }
    }
}
