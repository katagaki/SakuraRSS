import Foundation

extension InstagramProvider {
    func buildPostsRequest(
        username: String, bootstrap: InstagramProfileBootstrap, cookies: InstagramCookies
    ) throws -> URLRequest {
        guard let url = URL(string: "https://www.instagram.com/graphql/query") else {
            throw URLError(.badURL)
        }
        let queryName = "PolarisProfilePostsQuery"
        let variables: [String: Any] = [
            "username": username,
            "data": [
                "count": Self.targetPostCount,
                "include_reel_media_seen_timestamp": true,
                "include_relationship_info": true,
                "latest_besties_reel_media": true,
                "latest_reel_media": true
            ],
            "__relay_internal__pv__PolarisMultiCaptionCarouselEnabledrelayprovider": true,
            "__relay_internal__pv__PolarisShortDramaEnabledrelayprovider": false,
            "__relay_internal__pv__PolarisReelsRecoDebugOverlayEnabledrelayprovider": false
        ]
        let variablesData = try JSONSerialization.data(withJSONObject: variables)
        guard let variablesJSON = String(data: variablesData, encoding: .utf8) else {
            throw InstagramFetchError.invalidResponse
        }
        let parameters = [
            "__a": "1", "__d": "www", "__user": "0", "__comet_req": "7",
            "fb_dtsg": bootstrap.dtsgToken,
            "lsd": bootstrap.lsdToken,
            "fb_api_caller_class": "RelayModern",
            "fb_api_req_friendly_name": queryName,
            "doc_id": "28991540097136703",
            "variables": variablesJSON
        ]
        var components = URLComponents()
        components.queryItems = parameters.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let body = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") else {
            throw InstagramFetchError.invalidResponse
        }
        var request = buildRequest(url: url, cookies: cookies, referer: "https://www.instagram.com/\(username)/")
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(queryName, forHTTPHeaderField: "x-fb-friendly-name")
        request.setValue(bootstrap.lsdToken, forHTTPHeaderField: "x-fb-lsd")
        request.httpBody = Data(body.utf8)
        return request
    }
}
