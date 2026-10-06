import Foundation

extension SuggestedTopic {

    var localizedTitle: String {
        switch title {
        case "Headlines": String(localized: "SuggestedFeeds.Topic.Headlines", table: "Feeds")
        case "Technology": String(localized: "SuggestedFeeds.Topic.Technology", table: "Feeds")
        case "Science": String(localized: "SuggestedFeeds.Topic.Science", table: "Feeds")
        case "Economics": String(localized: "SuggestedFeeds.Topic.Economics", table: "Feeds")
        case "Business": String(localized: "SuggestedFeeds.Topic.Business", table: "Feeds")
        case "Sports": String(localized: "SuggestedFeeds.Topic.Sports", table: "Feeds")
        case "Politics": String(localized: "SuggestedFeeds.Topic.Politics", table: "Feeds")
        case "Weather": String(localized: "SuggestedFeeds.Topic.Weather", table: "Feeds")
        case "System Status": String(localized: "SuggestedFeeds.Topic.SystemStatus", table: "Feeds")
        case "Videos": String(localized: "SuggestedFeeds.Topic.Videos", table: "Feeds")
        case "Podcasts": String(localized: "SuggestedFeeds.Topic.Podcasts", table: "Feeds")
        default: title
        }
    }
}
