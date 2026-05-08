import SwiftUI

// swiftlint:disable:next type_name
struct iPadSidebarSheetsBindings {
    let pendingFeedURL: Binding<String?>
    let showingAddFeed: Binding<Bool>
    let showingOnboarding: Binding<Bool>
    let showYouTubeSafari: Binding<Bool>
    let pendingYouTubeSafariURL: Binding<URL?>
    let showingWeatherLocationPicker: Binding<Bool>
    let feedToDelete: Binding<Feed?>
    let listToEdit: Binding<FeedList?>
    let listForRules: Binding<FeedList?>
    let listToDelete: Binding<FeedList?>
    let onboardingCompleted: Binding<Bool>
}
