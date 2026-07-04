import Intents
import Observation

@MainActor
@Observable
final class FocusStatusAuthorization {

    private(set) var status: INFocusStatusAuthorizationStatus

    init() {
        status = INFocusStatusCenter.default.authorizationStatus
    }

    var isDenied: Bool {
        status == .denied || status == .restricted
    }

    func requestIfNeeded() async {
        refresh()
        guard status == .notDetermined else { return }
        status = await withCheckedContinuation { continuation in
            INFocusStatusCenter.default.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus)
            }
        }
    }

    func refresh() {
        status = INFocusStatusCenter.default.authorizationStatus
    }
}
