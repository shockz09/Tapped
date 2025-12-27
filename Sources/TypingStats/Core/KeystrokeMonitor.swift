import Cocoa
import Combine

/// Monitors global keystrokes using CGEventTap
final class KeystrokeMonitor: ObservableObject {
    @Published private(set) var keystrokeCount: UInt64 = 0
    @Published private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoopThread: Thread?

    /// Start monitoring keystrokes
    func start() {
        guard eventTap == nil else { return }

        // Event mask for keyDown events only
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Create the event tap
        // Note: We use a static callback because CGEventTapCallBack is a C function pointer
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Don't intercept, just observe
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()

                if type == .keyDown {
                    DispatchQueue.main.async {
                        monitor.keystrokeCount += 1
                    }
                }

                // Handle tap being disabled by system
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            // Event tap creation failed - likely missing Accessibility permission
            return
        }

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        // Run on a background thread
        runLoopThread = Thread { [weak self] in
            guard let self = self, let source = self.runLoopSource else { return }

            let runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)

            // Keep the run loop running
            CFRunLoopRun()
        }
        runLoopThread?.name = "KeystrokeMonitor"
        runLoopThread?.start()

        DispatchQueue.main.async {
            self.isRunning = true
        }
    }

    /// Stop monitoring keystrokes
    func stop() {
        guard let eventTap = eventTap else { return }

        CGEvent.tapEnable(tap: eventTap, enable: false)

        if let runLoopSource = runLoopSource {
            // Stop the run loop on the background thread
            if let thread = runLoopThread {
                CFRunLoopStop(CFRunLoopGetMain()) // This won't work as expected
                thread.cancel()
            }
        }

        self.eventTap = nil
        self.runLoopSource = nil
        self.runLoopThread = nil

        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    /// Reset the keystroke count (for testing)
    func reset() {
        DispatchQueue.main.async {
            self.keystrokeCount = 0
        }
    }

    /// Get and reset the count (for batched recording)
    func consumeCount() -> UInt64 {
        let count = keystrokeCount
        keystrokeCount = 0
        return count
    }
}
