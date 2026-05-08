import Foundation

struct DiscoverEntityData {
    let sections: [DiscoverEntitySection]
    let topics: [(name: String, count: Int)]
    let people: [(name: String, count: Int)]

    nonisolated static var empty: DiscoverEntityData {
        DiscoverEntityData(sections: [], topics: [], people: [])
    }
}
