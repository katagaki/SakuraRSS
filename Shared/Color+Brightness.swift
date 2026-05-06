import SwiftUI

extension Color {

    /// Returns a darker shade by mixing toward black by `amount` (0...1).
    func darken(by amount: Double = 0.2) -> Color {
        mix(with: .black, by: amount)
    }

    /// Returns a lighter shade by mixing toward white by `amount` (0...1).
    func lighten(by amount: Double = 0.2) -> Color {
        mix(with: .white, by: amount)
    }
}
