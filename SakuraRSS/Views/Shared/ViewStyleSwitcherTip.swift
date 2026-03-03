import TipKit

struct ViewStyleSwitcherTip: Tip {

    @Parameter
    static var hasCompletedOnboarding: Bool = false

    var title: Text {
        Text("Tip.ViewStyleSwitcher.Title")
    }

    var message: Text? {
        Text("Tip.ViewStyleSwitcher.Message")
    }

    var rules: [Rule] {
        #Rule(Self.$hasCompletedOnboarding) { $0 }
    }
}
