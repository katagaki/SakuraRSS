// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "EnhancedNavigation",
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "EnhancedNavigation", targets: ["EnhancedNavigation"])
    ],
    targets: [
        .target(
            name: "EnhancedNavigation",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        )
    ]
)
