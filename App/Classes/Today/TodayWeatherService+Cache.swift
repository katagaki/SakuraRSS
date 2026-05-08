import Foundation

extension TodayWeatherService {

    // MARK: - Cache

    static func loadCache() -> TodayWeather? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(TodayWeather.self, from: data) else {
            return nil
        }
        return decoded
    }

    static func saveCache(_ snapshot: TodayWeather) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    func invalidateCache() {
        weather = nil
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
    }

    // MARK: - Daily Change Limit

    func loadLocationChangeCount() {
        let now = Date()
        if let stored = UserDefaults.standard.object(forKey: Self.changeResetDateKey) as? Date,
           Calendar.current.isDate(stored, inSameDayAs: now) {
            locationChangesToday = UserDefaults.standard.integer(forKey: Self.changeCountKey)
        } else {
            locationChangesToday = 0
            UserDefaults.standard.removeObject(forKey: Self.changeCountKey)
            UserDefaults.standard.removeObject(forKey: Self.changeResetDateKey)
        }
    }

    func recordLocationChange() {
        let now = Date()
        if let stored = UserDefaults.standard.object(forKey: Self.changeResetDateKey) as? Date,
           Calendar.current.isDate(stored, inSameDayAs: now) {
            locationChangesToday += 1
        } else {
            locationChangesToday = 1
            UserDefaults.standard.set(now, forKey: Self.changeResetDateKey)
        }
        UserDefaults.standard.set(locationChangesToday, forKey: Self.changeCountKey)
    }
}
