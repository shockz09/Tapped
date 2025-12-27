import Cocoa
import Combine

/// Manages Accessibility permission state and requests
final class PermissionManager: ObservableObject {
    @Published private(set) var isAuthorized = false

    private var timer: Timer?

    init() {
        checkAuthorization()
        startPolling()
    }

    /// Check current authorization status without prompting
    func checkAuthorization() {
        isAuthorized = AXIsProcessTrusted()
    }

    /// Request authorization - shows system prompt and opens System Preferences
    func requestAuthorization() {
        // This will show the system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Also open System Preferences directly to the Accessibility pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Start polling for permission changes (macOS doesn't provide callbacks)
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkAuthorization()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
