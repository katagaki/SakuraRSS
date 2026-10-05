import CryptoKit
import DeviceCheck
import Foundation

public actor SakuraCloud {

    public static let shared = SakuraCloud()

    var attesting: Task<String, Error>?

    /// Simulator has no App Attest, so debug builds there talk unsigned to `npm run dev` in
    /// ../SakuraCloud, which only accepts that on localhost with `SKIP_APP_ATTEST`.
    #if DEBUG && targetEnvironment(simulator)
    static let skipsAppAttest = true
    private static let fallbackURL = {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = 8787
        return components.string ?? ""
    }()
    #else
    static let skipsAppAttest = false
    private static let fallbackURL = ""
    #endif

    static let requestTimeout: TimeInterval = 15

    nonisolated static var baseURL: URL? {
        let trimmed = SakuraCloudAddress.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = trimmed.isEmpty ? fallbackURL : trimmed
        return address.isEmpty ? nil : URL(string: address)
    }

    public nonisolated static var isAvailable: Bool {
        baseURL != nil && (skipsAppAttest || DCAppAttestService.shared.isSupported)
    }

    /// For each candidate, in order, the probability that the block belongs to the content.
    public func classify(
        title: String, site: String, blocks: [String], candidates: [Int]
    ) async throws -> [Double] {
        let body = try JSONSerialization.data(withJSONObject: [
            "title": title,
            "site": site,
            "blocks": blocks,
            "candidates": candidates
        ] as [String: Any])
        let data = try await send(.classify, body: body)
        guard let answer = try? JSONDecoder().decode(ClassifyAnswer.self, from: data),
              answer.probabilities.count == candidates.count else {
            throw SakuraCloudError.noResponse
        }
        return answer.probabilities
    }

    /// A key the Worker no longer knows, as after a reinstall or restore, is dropped and
    /// replaced once.
    func send(_ endpoint: SakuraCloudEndpoint, body: Data) async throws -> Data {
        do {
            return try await sendOnce(endpoint, body: body)
        } catch SakuraCloudError.server(401, _) {
            SakuraCloudKeychain.write(nil, account: SakuraCloudKeychain.keyIDAccount)
            return try await sendOnce(endpoint, body: body)
        } catch let error as DCError where error.code == .invalidKey {
            SakuraCloudKeychain.write(nil, account: SakuraCloudKeychain.keyIDAccount)
            return try await sendOnce(endpoint, body: body)
        }
    }

    private func sendOnce(_ endpoint: SakuraCloudEndpoint, body: Data) async throws -> Data {
        var request = try Self.post(endpoint, body: body)
        if !Self.skipsAppAttest {
            let attestedKeyID = try await keyID()
            let assertion = try await DCAppAttestService.shared.generateAssertion(
                attestedKeyID, clientDataHash: Data(SHA256.hash(data: body))
            )
            request.setValue(attestedKeyID, forHTTPHeaderField: "X-Sakura-Key-Id")
            request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Sakura-Assertion")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SakuraCloudError.noResponse }
        switch http.statusCode {
        case 200:
            return data
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw SakuraCloudError.limitReached(retryAfter: retryAfter)
        default:
            let message = try? JSONDecoder().decode(Failure.self, from: data).error
            throw SakuraCloudError.server(http.statusCode, message)
        }
    }

    static func post(_ endpoint: SakuraCloudEndpoint, body: Data) throws -> URLRequest {
        guard let baseURL else { throw SakuraCloudError.notConfigured }
        let url = baseURL.appending(path: SakuraCloudEndpoint.version).appending(path: endpoint.rawValue)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private struct ClassifyAnswer: Decodable {
        let probabilities: [Double]
    }

    struct Failure: Decodable {
        let error: String
    }
}
