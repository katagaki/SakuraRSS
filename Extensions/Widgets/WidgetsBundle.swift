import WidgetKit
import SwiftUI
import Hanami

@main
struct SakuraRSSWidgetBundle: WidgetBundle {
    var body: some Widget {
        AllArticlesWidget()
        SingleFeedWidget()
        ListWidget()
    }
}
