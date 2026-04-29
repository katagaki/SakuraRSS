nonisolated func log(_ module: String, _ message: String) {
    #if DEBUG
    debugPrint("[\(module)] \(message)")
    #endif
}
