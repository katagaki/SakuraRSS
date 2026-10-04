import SwiftUI
import UIKit

enum HomeLayout {
    @MainActor static var usesPhoneTopBar: Bool {
        #if os(visionOS)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    @MainActor static var usesPadLayout: Bool {
        #if os(visionOS)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    @MainActor static var showsTodayWeather: Bool {
        usesPhoneTopBar || usesPadLayout
    }

    static let padTodayReadableWidth: CGFloat = 720
}
