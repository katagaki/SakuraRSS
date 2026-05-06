import SwiftUI
import UIKit

extension Color {

    static let lime = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.90, blue: 0.30, alpha: 1)
            : UIColor(red: 0.50, green: 0.78, blue: 0.10, alpha: 1)
    })

    static let magenta = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.35, blue: 0.70, alpha: 1)
            : UIColor(red: 0.85, green: 0.15, blue: 0.55, alpha: 1)
    })

    static let slate = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.68, blue: 0.75, alpha: 1)
            : UIColor(red: 0.40, green: 0.48, blue: 0.55, alpha: 1)
    })

    static let beige = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.88, green: 0.78, blue: 0.62, alpha: 1)
            : UIColor(red: 0.78, green: 0.68, blue: 0.50, alpha: 1)
    })
}
