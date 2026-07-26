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
}
