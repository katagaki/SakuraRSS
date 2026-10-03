import SwiftUI
import UIKit

enum HomeLayout {
    @MainActor static var usesPhoneTopBar: Bool {
        #if targetEnvironment(macCatalyst) || os(visionOS)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    @MainActor static var usesPadTodayLayout: Bool {
        #if targetEnvironment(macCatalyst) || os(visionOS)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    @MainActor static var showsTodayWeather: Bool {
        usesPhoneTopBar || usesPadTodayLayout
    }

    static let padTodayReadableWidth: CGFloat = 720
}
