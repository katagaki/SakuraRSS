import Foundation

extension Dependency {
    static let braveMediaBackgrounding = Dependency(
        id: "brave-media-backgrounding",
        name: "Brave iOS media backgrounding",
        license: "Mozilla Public License Version 2.0",
        licenseText: """
        Copyright (c) 2026 The Brave Authors. All rights reserved.

        Source:
        https://github.com/brave/brave-core/blob/9877355bd3e9/ios/browser/web/media/resources/media_backgrounding.ts

        \(adblockResources.licenseText)
        """
    )
}
