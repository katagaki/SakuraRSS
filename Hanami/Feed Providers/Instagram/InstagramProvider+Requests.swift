import Foundation

extension InstagramProvider {
    private static var activeRequest: Task<Data, Error>?
    private static var activeRequestID: UUID?
    private static var lastRequestCompletedAt: Date?
    private static var nextRequestAllowedAt: Date?

    static func performRequest(_ request: URLRequest, session: URLSession) async throws -> Data {
        let previousRequest = activeRequest
        let requestID = UUID()
        let task = Task {
            if let previousRequest { _ = await previousRequest.result }
            try Task.checkCancellation()
            if let nextRequestAllowedAt, nextRequestAllowedAt > Date() {
                throw InstagramFetchError.rateLimited(until: nextRequestAllowedAt)
            }
            if let lastRequestCompletedAt {
                let interval = TimeInterval.random(in: 5...8)
                let remaining = interval - Date().timeIntervalSince(lastRequestCompletedAt)
                if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
            }
            try Task.checkCancellation()
            defer { lastRequestCompletedAt = Date() }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw InstagramFetchError.invalidResponse
            }
            log("InstagramProvider", "Request status=\(response.statusCode) path=\(request.url?.path ?? "")")
            if response.statusCode == 429 {
                let deadline = retryDeadline(response: response, now: Date())
                nextRequestAllowedAt = deadline
                throw InstagramFetchError.rateLimited(until: deadline)
            }
            guard response.statusCode == 200 else {
                throw InstagramFetchError.httpStatus(response.statusCode)
            }
            return data
        }
        activeRequest = task
        activeRequestID = requestID
        defer {
            if activeRequestID == requestID {
                activeRequest = nil
                activeRequestID = nil
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func retryDeadline(response: HTTPURLResponse, now: Date) -> Date {
        let defaultDeadline = now.addingTimeInterval(15 * 60)
        guard let retryAfter = response.value(forHTTPHeaderField: "Retry-After") else {
            return defaultDeadline
        }
        if let seconds = TimeInterval(retryAfter) {
            return max(defaultDeadline, now.addingTimeInterval(seconds))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return max(defaultDeadline, formatter.date(from: retryAfter) ?? defaultDeadline)
    }
}
