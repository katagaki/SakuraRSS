import SwiftUI
import UIKit

enum HomeLayout {
    @MainActor static var usesPhoneTopBar: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }
}
