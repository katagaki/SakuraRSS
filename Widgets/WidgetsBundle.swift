import WidgetKit
import SwiftUI

@main
struct SakuraRSSWidgetBundle: WidgetBundle {
    var body: some Widget {
        AllArticlesWidget()
        SingleFeedWidget()
        ListWidget()
    }
}
