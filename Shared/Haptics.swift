import Foundation
#if canImport(UIKit) && !os(visionOS)
import UIKit
#endif

enum Haptics {
    enum ImpactStyle {
        case light, medium, heavy, soft, rigid
    }

    enum NotificationType {
        case success, warning, error
    }

    static func impact(_ style: ImpactStyle = .light) {
        #if canImport(UIKit) && !os(visionOS)
        let mapped: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: mapped = .light
        case .medium: mapped = .medium
        case .heavy: mapped = .heavy
        case .soft: mapped = .soft
        case .rigid: mapped = .rigid
        }
        UIImpactFeedbackGenerator(style: mapped).impactOccurred()
        #endif
    }

    static func notify(_ type: NotificationType) {
        #if canImport(UIKit) && !os(visionOS)
        let mapped: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success: mapped = .success
        case .warning: mapped = .warning
        case .error: mapped = .error
        }
        UINotificationFeedbackGenerator().notificationOccurred(mapped)
        #endif
    }
}
