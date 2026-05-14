import Foundation

public nonisolated final class LogManager: @unchecked Sendable {

    public static let shared = LogManager()

    public static let maxBytesPerModule: Int64 = 128 * 1024

    private static let appGroupIdentifier = "group.com.tsubuzaki.SakuraRSS"
    private static let logsDirectoryName = "Logs"
    private static let truncationHeadroom: Int64 = 32 * 1024

    private let queue = DispatchQueue(label: "com.tsubuzaki.SakuraRSS.LogManager", qos: .utility)
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public var directoryURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else { return nil }
        let directory = container.appendingPathComponent(Self.logsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public func write(module: String, message: String) {
        guard let url = fileURL(for: module) else { return }
        let timestamp = timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        queue.async { [weak self] in
            self?.appendData(data, to: url)
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

    public func contents(for module: String) -> String {
        guard let url = fileURL(for: module),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private func appendData(_ data: Data, to url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url, options: .atomic)
        } else if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                return
            }
        }
        truncateIfNeeded(url: url)
    }

    private func truncateIfNeeded(url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes?[.size] as? Int64,
              size > Self.maxBytesPerModule + Self.truncationHeadroom,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var keptLines = Array(lines)
        var bytes = Int64(data.count)
        while bytes > Self.maxBytesPerModule, keptLines.count > 1 {
            let dropped = keptLines.removeFirst()
            bytes -= Int64(dropped.utf8.count + 1)
        }
        let rewritten = keptLines.joined(separator: "\n")
        try? rewritten.data(using: .utf8)?.write(to: url, options: .atomic)
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
