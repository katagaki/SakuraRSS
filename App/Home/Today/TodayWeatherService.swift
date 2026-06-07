import Foundation
@preconcurrency import CoreLocation
import WeatherKit
import SwiftUI
import Hanami

struct TodayWeather: Equatable, Codable, Sendable {
    var temperatureCelsius: Double
    var apparentTemperatureCelsius: Double
    var symbolName: String
    var conditionDescription: String
    var highCelsius: Double
    var lowCelsius: Double
    var regionName: String
    var hourly: [TodayWeatherHour]
    var alert: TodayWeatherAlert?
    var fetchedAt: Date
}

struct TodayWeatherHour: Equatable, Codable, Sendable, Identifiable {
    var date: Date
    var temperatureCelsius: Double
    var symbolName: String
    var precipitationChance: Double
    var id: Date { date }
}

struct TodayWeatherAlert: Equatable, Codable, Sendable {
    var summary: String
    var source: String
    var detailsURL: URL?
}

private enum WeatherFetchError: Error {
    case locationUnavailable
}

struct TodayWeatherLocation: Equatable, Codable, Sendable {
    var name: String
    var latitude: Double?
    var longitude: Double?

    var isCurrent: Bool { latitude == nil || longitude == nil }
}

@MainActor
@Observable
final class TodayWeatherService {

    static let shared = TodayWeatherService()

    static let dailyLocationChangeLimit: Int = 3

    static let cacheKey = "Today.Weather.Cache"
    static let locationKey = "Today.Weather.Location"
    static let changeCountKey = "Today.Weather.LocationChangeCount"
    static let changeResetDateKey = "Today.Weather.LocationChangeResetDate"
    static let cacheLifetime: TimeInterval = 60 * 60

    var weather: TodayWeather?
    var isFetching: Bool = false
    var lastError: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationChangesToday: Int = 0

    var remainingLocationChanges: Int {
        max(0, Self.dailyLocationChangeLimit - locationChangesToday)
    }

    var canChangeLocation: Bool {
        locationChangesToday < Self.dailyLocationChangeLimit
    }

    var isCurrentLocationAvailable: Bool {
        switch locationAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .notDetermined:
            return true
        default:
            return false
        }
    }

    private let weatherService = WeatherService.shared
    private let locationDelegate = LocationDelegate()
    private var locationManager: CLLocationManager?
    private var pendingResolution: CheckedContinuation<CLLocation?, Never>?

    private init() {
        weather = Self.loadCache()
        loadLocationChangeCount()
        if let weather {
            let age = Int(Date().timeIntervalSince(weather.fetchedAt))
            log("Weather", "loaded cached snapshot (\(weather.regionName)) aged \(age)s on init")
        } else {
            log("Weather", "no cached snapshot on init")
        }
    }

    // MARK: - Persisted Location

    var savedLocation: TodayWeatherLocation? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.locationKey),
                  let decoded = try? JSONDecoder().decode(TodayWeatherLocation.self, from: data) else {
                return nil
            }
            return decoded
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.locationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.locationKey)
            }
        }
    }

    // MARK: - Public Actions

    @discardableResult
    func setLocation(_ location: TodayWeatherLocation) async -> Bool {
        if let saved = savedLocation, saved == location {
            log("Weather", "setLocation: \(location.name) unchanged, skipping")
            return false
        }
        loadLocationChangeCount()
        guard canChangeLocation else {
            log("Weather", "setLocation: \(location.name) blocked, daily limit reached "
                + "(\(locationChangesToday)/\(Self.dailyLocationChangeLimit))")
            return false
        }
        log("Weather", "setLocation: \(location.name) (current=\(location.isCurrent)); invalidating cache")
        savedLocation = location
        recordLocationChange()
        invalidateCache()
        await refresh(force: true)
        return true
    }

    func refreshIfNeeded() async {
        if let weather {
            let age = Int(Date().timeIntervalSince(weather.fetchedAt))
            if age < Int(Self.cacheLifetime) {
                log("Weather",
                    "cache hit (refreshIfNeeded): region=\(weather.regionName) "
                    + "temp=\(Int(weather.temperatureCelsius.rounded()))°C "
                    + "age=\(age)s/\(Int(Self.cacheLifetime))s, skipping fetch")
                return
            }
            log("Weather", "cache stale (age=\(age)s ≥ \(Int(Self.cacheLifetime))s); refreshing from API")
        } else {
            log("Weather", "no cache; fetching from API (refreshIfNeeded)")
        }
        await refresh(force: false)
    }

    func refresh(force: Bool) async {
        guard !isFetching else {
            log("Weather", "refresh skipped: already in flight")
            return
        }
        if !force, isCacheFresh() { return }
        isFetching = true
        defer { isFetching = false }

        let fetchStart = Date()
        log("Weather", "fetching from WeatherKit API (force=\(force))")

        do {
            let resolved = try await resolveLocation()
            log("Weather", String(
                format: "resolved location lat=%.4f lon=%.4f savedName=%@",
                resolved.location.coordinate.latitude,
                resolved.location.coordinate.longitude,
                resolved.regionName ?? "<nil>"
            ))
            let weatherData = try await weatherService.weather(for: resolved.location)
            let regionName = await resolveRegionName(saved: resolved.regionName, location: resolved.location)
            let snapshot = Self.makeSnapshot(from: weatherData, regionName: regionName)
            self.weather = snapshot
            Self.saveCache(snapshot)
            self.lastError = nil
            let elapsed = Int(Date().timeIntervalSince(fetchStart) * 1000)
            log("Weather",
                "API fetch ok in \(elapsed)ms: region=\(snapshot.regionName) "
                + "temp=\(Int(snapshot.temperatureCelsius.rounded()))°C "
                + "symbol=\(snapshot.symbolName) "
                + "hours=\(snapshot.hourly.count) alert=\(snapshot.alert != nil)")
        } catch is WeatherFetchError {
            self.lastError = nil
            log("Weather", "location unavailable; awaiting permission or saved location")
        } catch {
            self.lastError = error.localizedDescription
            log("Weather", "API fetch failed: \(error.localizedDescription)")
        }
    }

    private func isCacheFresh() -> Bool {
        guard let weather else { return false }
        let age = Int(Date().timeIntervalSince(weather.fetchedAt))
        guard age < Int(Self.cacheLifetime) else { return false }
        log("Weather",
            "cache hit (refresh non-forced): region=\(weather.regionName) "
            + "age=\(age)s/\(Int(Self.cacheLifetime))s, skipping fetch")
        return true
    }

    private func resolveRegionName(saved: String?, location: CLLocation) async -> String {
        if let saved, !saved.isEmpty { return saved }
        return await reverseGeocode(location) ?? ""
    }

    // MARK: - Location Resolution

    private struct ResolvedLocation {
        let location: CLLocation
        let regionName: String?
    }

    private func resolveLocation() async throws -> ResolvedLocation {
        if let saved = savedLocation, !saved.isCurrent,
           let lat = saved.latitude, let lon = saved.longitude {
            return ResolvedLocation(
                location: CLLocation(latitude: lat, longitude: lon),
                regionName: saved.name
            )
        }
        guard let location = await currentLocation() else {
            throw WeatherFetchError.locationUnavailable
        }
        return ResolvedLocation(location: location, regionName: nil)
    }

    private func currentLocation() async -> CLLocation? {
        let manager = ensureLocationManager()
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return await withCheckedContinuation { continuation in
                self.pendingResolution = continuation
            }
        case .authorizedAlways, .authorizedWhenInUse:
            if let location = manager.location {
                return location
            }
            return await waitForLocation(using: manager)
        default:
            return nil
        }
    }

    func refreshAuthorizationStatus() {
        let manager = ensureLocationManager()
        locationAuthorizationStatus = manager.authorizationStatus
    }

    private func ensureLocationManager() -> CLLocationManager {
        if let locationManager { return locationManager }
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = locationDelegate
        locationDelegate.didUpdate = { [weak self] location in
            Task { @MainActor in
                self?.deliver(location: location)
            }
        }
        locationDelegate.didFail = { [weak self] in
            Task { @MainActor in
                self?.deliver(location: nil)
            }
        }
        locationDelegate.didChangeAuthorization = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.locationAuthorizationStatus = status
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    if self.pendingResolution != nil,
                       let manager = self.locationManager {
                        manager.requestLocation()
                    } else if self.weather == nil, !self.isFetching {
                        await self.refresh(force: true)
                    }
                case .denied, .restricted:
                    self.deliver(location: nil)
                default:
                    break
                }
            }
        }
        locationManager = manager
        locationAuthorizationStatus = manager.authorizationStatus
        return manager
    }

    private func waitForLocation(using manager: CLLocationManager) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.pendingResolution = continuation
            manager.requestLocation()
        }
    }

    private func deliver(location: CLLocation?) {
        let continuation = pendingResolution
        pendingResolution = nil
        continuation?.resume(returning: location)
    }

}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    var didUpdate: ((CLLocation) -> Void)?
    var didFail: (() -> Void)?
    var didChangeAuthorization: ((CLAuthorizationStatus) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        didUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        didFail?()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        didChangeAuthorization?(manager.authorizationStatus)
    }
}
