import Foundation
import os
import Testing
@testable import InstagramFetch

@Suite(.serialized)
@MainActor
struct InstagramFetchTests {
    private let username = "sdp_ftc"
    private let bootstrap = InstagramProfileBootstrap(
        dtsgToken: "session+token&value", lsdToken: "lsd+token", displayName: "みぃ", profileImageURL: "profile.jpg"
    )

    @Test
    func profileBootstrapUsesNamedModulesAndValidatesTheAccount() throws {
        let html = """
        <meta property="og:title" content="みぃ(@sdp_ftc) • Instagram写真と動画">
        <meta property="og:image" content="https://example.com/profile.jpg">
        <script data-sjs type="application/json">{"require":[{"__bbox":{"define":[
        ["DTSGInitialData",[],{"token":"session-token"},0],["LSD",[],{"token":"lsd-token"},0]
        ]}}]}</script>
        """
        let result = try #require(InstagramProvider.parseProfileHTML(html, username: username))
        #expect(result.displayName == "みぃ")
        #expect(result.profileImageURL == "https://example.com/profile.jpg")
        #expect(result.dtsgToken == "session-token")
        #expect(result.lsdToken == "lsd-token")
        #expect(InstagramProvider.parseProfileHTML(html, username: "another_account") == nil)
        #expect(InstagramProvider.parseProfileHTML("<title>Login</title>", username: username) == nil)
    }

    @Test
    func carouselAndVideoPostsPreserveMediaAndPermalinks() throws {
        var carousel = makePost(identifier: "3998986014107877070", code: "Dd_QJegp77O", product: "feed")
        carousel["carousel_media"] = [imageItem("small.jpg", "large.jpg"), imageItem("second.jpg", "second-large.jpg")]
        let video = makePost(identifier: "123", code: "video", product: "feed", mediaType: 2)
        let reel = makePost(identifier: "456", code: "reel", product: "clips", mediaType: 2)
        let parsed = try parse([carousel, video, reel, carousel], prefix: "for (;;);")
        let result = try #require(parsed)
        #expect(result.posts.count == 3)
        #expect(result.displayName == "みぃ")
        #expect(result.posts[0].url == "https://www.instagram.com/p/Dd_QJegp77O/")
        #expect(result.posts[0].carouselImageURLs == ["large.jpg", "second-large.jpg"])
        #expect(result.posts[0].imageURL == "large.jpg")
        #expect(result.posts[0].text == "cos\n千恋万花/常陸茉子")
        #expect(result.posts[0].publishedDate == Date(timeIntervalSince1970: 1790936382))
        #expect(result.posts[1].url == "https://www.instagram.com/p/video/")
        #expect(result.posts[2].url == "https://www.instagram.com/reel/reel/")
    }

    @Test
    func failuresAreNotEmptyProfiles() throws {
        #expect(try parse([])?.posts.isEmpty == true)
        var missingCode = makePost(identifier: "123", code: "valid", product: "feed")
        missingCode.removeValue(forKey: "code")
        #expect(try parse([missingCode]) == nil)
        var otherAuthor = makePost(identifier: "123", code: "valid", product: "feed")
        otherAuthor["user"] = ["username": "someone_else"]
        let parsedCollaboration = try parse([otherAuthor])
        let collaborative = try #require(parsedCollaboration)
        #expect(collaborative.posts.first?.authorHandle == "someone_else")
        #expect(collaborative.displayName == "みぃ")
        let errorData = Data("{\"data\":null,\"errors\":[{\"message\":\"login_required\"}]}".utf8)
        #expect(InstagramProvider.parsePostsResponse(
            data: errorData, username: username, bootstrap: bootstrap
        ) == nil)
        #expect(InstagramProvider.parsePostsResponse(
            data: Data("<html>rate limited</html>".utf8), username: username, bootstrap: bootstrap
        ) == nil)
    }

    @Test
    func requestEncodingPreservesSessionTokensAndUsesOneBatch() throws {
        let cookies = InstagramProvider.InstagramCookies(csrfToken: "csrf", sessionID: "session", allCookies: [])
        let request = try InstagramProvider().buildPostsRequest(
            username: username, bootstrap: bootstrap, cookies: cookies
        )
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/graphql/query")
        #expect(request.value(forHTTPHeaderField: "x-fb-lsd") == bootstrap.lsdToken)
        let requestData = try #require(request.httpBody)
        let body = try #require(String(data: requestData, encoding: .utf8))
        let decoded = body.split(separator: "&").reduce(into: [String: String]()) { parameters, entry in
            let pair = entry.split(separator: "=", maxSplits: 1)
            parameters[String(pair[0])] = String(pair[1]).removingPercentEncoding
        }
        #expect(decoded["fb_dtsg"] == bootstrap.dtsgToken)
        #expect(decoded["lsd"] == bootstrap.lsdToken)
        let variablesData = try #require(decoded["variables"]?.data(using: .utf8))
        let variablesJSON = try JSONSerialization.jsonObject(with: variablesData)
        let variables = try #require(variablesJSON as? [String: Any])
        #expect(variables["username"] as? String == username)
        #expect((variables["data"] as? [String: Any])?["count"] as? Int == 50)
    }

    @Test
    func requestsAreSerializedCanceledAndBackedOffWithoutNetworkRetries() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InstagramMockProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let firstRequest = URLRequest(url: try #require(URL(string: "https://stub.invalid/first")))
        let secondRequest = URLRequest(url: try #require(URL(string: "https://stub.invalid/limited")))
        let first = Task { try await InstagramProvider.performRequest(firstRequest, session: session) }
        await Task.yield()
        let canceled = Task { try await InstagramProvider.performRequest(firstRequest, session: session) }
        canceled.cancel()
        let second = Task { try await InstagramProvider.performRequest(secondRequest, session: session) }
        _ = try await first.value
        do {
            _ = try await canceled.value
            Issue.record("Canceled request was sent")
        } catch is CancellationError {}
        do {
            _ = try await second.value
            Issue.record("429 response was accepted")
        } catch InstagramFetchError.rateLimited {}
        do {
            _ = try await InstagramProvider.performRequest(firstRequest, session: session)
            Issue.record("Cooldown did not stop a request")
        } catch InstagramFetchError.rateLimited {}
        let calls = InstagramMockProtocol.calls.withLock { $0 }
        #expect(calls.count == 2)
        #expect(calls[1].timeIntervalSince(calls[0]) >= 5)
        let now = Date(timeIntervalSince1970: 1000)
        let response = try #require(HTTPURLResponse(
            url: firstRequest.url!, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "1800"]
        ))
        #expect(InstagramProvider.retryDeadline(response: response, now: now) == now.addingTimeInterval(1800))
    }

    private func makePost(
        identifier: String, code: String, product: String, mediaType: Int = 1
    ) -> [String: Any] {
        [
            "pk": identifier, "code": code, "product_type": product, "media_type": mediaType,
            "caption": ["text": "cos\n千恋万花/常陸茉子"], "taken_at": 1790936382,
            "user": ["username": username, "full_name": "みぃ", "profile_pic_url": "profile.jpg"],
            "image_versions2": imageItem("small.jpg", "large.jpg")["image_versions2"]!
        ]
    }

    private func imageItem(_ small: String, _ large: String) -> [String: Any] {
        ["image_versions2": ["candidates": [["url": small, "width": 320], ["url": large, "width": 1080]]]]
    }

    private func parse(_ posts: [[String: Any]], prefix: String = "") throws -> InstagramProfileFetchResult? {
        let payload: [String: Any] = ["data": ["xdt_api__v1__feed__user_timeline_graphql_connection": [
            "edges": posts.map { ["node": $0] }
        ]]]
        var data = Data(prefix.utf8)
        data.append(try JSONSerialization.data(withJSONObject: payload))
        return InstagramProvider.parsePostsResponse(data: data, username: username, bootstrap: bootstrap)
    }
}

final class InstagramMockProtocol: URLProtocol, @unchecked Sendable {
    static let calls = OSAllocatedUnfairLock(initialState: [Date]())

    override static func canInit(with request: URLRequest) -> Bool { request.url?.host == "stub.invalid" }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.calls.withLock { $0.append(Date()) }
        let status = request.url?.path == "/limited" ? 429 : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("ok".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
