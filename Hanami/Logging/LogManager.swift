import Foundation

public nonisolated final class LogManager: @unchecked Sendable {

    public static let shared = LogManager()

    public static let maxBytesPerModule: Int64 = 128 * 1024

    private static let appGroupIdentifier = AppGroup.identifier
    private static let logsDirectoryName = "Logs"
    private static let truncationHeadroom: Int64 = 32 * 1024

    private let queue = DispatchQueue(label: "com.tsubuzaki.SakuraRSS.LogManager", qos: .utility)
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var knownFileSizes: [URL: Int64] = [:]

    public let directoryURL: URL? = {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: LogManager.appGroupIdentifier
        ) else { return nil }
        let directory = container.appendingPathComponent(LogManager.logsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    public func write(module: String, message: String) {
        let date = Date()
        queue.async { [weak self] in
            guard let self, let url = self.fileURL(for: module) else { return }
            let line = "[\(self.timestampFormatter.string(from: date))] \(message)\n"
            self.appendData(Data(line.utf8), to: url)
        }
    }

    public func availableModules() -> [String] {
        guard let directory = directoryURL else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return contents
            .filter { $0.pathExtension == "log" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func fileURL(for module: String) -> URL? {
        guard let directory = directoryURL else { return nil }
        return directory.appendingPathComponent("\(sanitizeFileName(module)).log")
    }

    public func size(for module: String) -> Int64 {
        guard let url = fileURL(for: module),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else { return 0 }
        return size
    }

    public func totalSize() -> Int64 {
        guard let directory = directoryURL else { return 0 }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return contents.reduce(into: Int64(0)) { total, url in
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
    }

    public func clearAll() {
        guard let directory = directoryURL else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.pathExtension == "log" {
            try? FileManager.default.removeItem(at: url)
        }
        queue.async { [weak self] in
            self?.knownFileSizes.removeAll()
        }
    }

    public func contents(for module: String) -> String {
        guard let url = fileURL(for: module),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private func appendData(_ data: Data, to url: URL) {
        let size: Int64
        if let knownSize = knownFileSizes[url] {
            size = knownSize
        } else {
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            size = (attributes?[.size] as? Int64) ?? -1
        }
        var baseSize = size
        if size >= 0, let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                knownFileSizes[url] = nil
                return
            }
        } else {
            try? data.write(to: url, options: .atomic)
            baseSize = 0
        }
        let newSize = baseSize + Int64(data.count)
        knownFileSizes[url] = newSize
        if newSize > Self.maxBytesPerModule + Self.truncationHeadroom {
            truncate(url: url)
        }
    }

    private func truncate(url: URL) {
        knownFileSizes[url] = nil
        guard let data = try? Data(contentsOf: url),
              data.count > Self.maxBytesPerModule else { return }
        let earliestKeptOffset = data.count - Int(Self.maxBytesPerModule)
        let lineStart = data[earliestKeptOffset...].firstIndex(of: UInt8(ascii: "\n"))
            .map { data.index(after: $0) } ?? earliestKeptOffset
        let kept = data[lineStart...]
        try? Data(kept).write(to: url, options: .atomic)
        knownFileSizes[url] = Int64(kept.count)
    }

    private func sanitizeFileName(_ module: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        var result = ""
        for scalar in module.unicodeScalars {
            if forbidden.contains(scalar) {
                result.append("_")
            } else {
                result.append(Character(scalar))
            }
        }
        return result
    }
}
