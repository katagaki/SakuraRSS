import Foundation
@preconcurrency import CoreLocation
import MapKit

extension TodayWeatherService {
    func reverseGeocode(_ location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let mapItems = try? await request.mapItems
        guard let mapItem = mapItems?.first else { return nil }
        return mapItem.name ?? mapItem.address?.shortAddress
    }
}
