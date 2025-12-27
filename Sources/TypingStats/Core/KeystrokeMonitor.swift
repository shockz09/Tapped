import Cocoa
import Combine
import os

/// Monitors global keystrokes using CGEventTap
final class KeystrokeMonitor: ObservableObject {
    @Published private(set) var keystrokeCount: UInt64 = 0
    @Published private(set) var wordCount: UInt64 = 0
    @Published private(set) var isRunning = false

    // Word separator keycodes
    private static let wordSeparators: Set<Int64> = [49, 36, 76, 48]  // space, enter, return, tab

    // Keys to ignore for word counting (don't affect word state)
    private static let ignoredKeys: Set<Int64> = [
        51,  // delete (backspace)
        117, // forward delete
        123, 124, 125, 126  // arrows: left, right, down, up
    ]

    // Word counting state
    private var lastWasSeparator = true

    // Pending counts (accumulated on callback thread, flushed periodically)
    private var pendingKeystrokes: UInt64 = 0
    private var pendingWords: UInt64 = 0

    // Fast lock for callback thread
    private var lock = os_unfair_lock()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoopThread: Thread?
    private var backgroundRunLoop: CFRunLoop?
    private var flushTimer: Timer?

    deinit {
        stop()
    }

    /// Start monitoring keystrokes
    func start() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard eventTap == nil else { return }

        // Event mask for keyDown events only
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Create the event tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()

                if type == .keyDown {
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)

                    // Ignore navigation/editing keys for word counting
                    let isIgnored = KeystrokeMonitor.ignoredKeys.contains(keycode)
                    let isSeparator = KeystrokeMonitor.wordSeparators.contains(keycode)

                    // Thread-safe accumulate (no main queue dispatch per key!)
                    os_unfair_lock_lock(&monitor.lock)
                    monitor.pendingKeystrokes += 1
                    if !isIgnored && !isSeparator && monitor.lastWasSeparator {
                        monitor.pendingWords += 1
                    }
                    if !isIgnored {
                        monitor.lastWasSeparator = isSeparator
                    }
                    os_unfair_lock_unlock(&monitor.lock)
                }

                // Handle tap being disabled by system
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }

                return Unmanaged.passUnretained(event)
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
            os_unfair_lock_lock(&self.lock)
            self.backgroundRunLoop = runLoop
            os_unfair_lock_unlock(&self.lock)

            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)

            // Keep the run loop running
            CFRunLoopRun()
        }
        runLoopThread?.name = "KeystrokeMonitor"
        runLoopThread?.start()

        // Start flush timer on main queue (100ms interval)
        DispatchQueue.main.async {
            self.isRunning = true
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.flushPendingCounts()
            }
        }
    }

    /// Flush accumulated counts to published properties
    private func flushPendingCounts() {
        os_unfair_lock_lock(&lock)
        let keys = pendingKeystrokes
        let words = pendingWords
        pendingKeystrokes = 0
        pendingWords = 0
        os_unfair_lock_unlock(&lock)

        if keys > 0 || words > 0 {
            keystrokeCount += keys
            wordCount += words
        }
    }

    /// Stop monitoring keystrokes
    func stop() {
        // Stop timer first
        flushTimer?.invalidate()
        flushTimer = nil

        // Flush any remaining counts
        flushPendingCounts()

        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard let eventTap = eventTap else { return }

        CGEvent.tapEnable(tap: eventTap, enable: false)

        // Stop the background run loop
        if let runLoop = backgroundRunLoop {
            CFRunLoopStop(runLoop)
        }

        if let thread = runLoopThread, !thread.isCancelled {
            thread.cancel()
        }

        self.eventTap = nil
        self.runLoopSource = nil
        self.runLoopThread = nil
        self.backgroundRunLoop = nil

        DispatchQueue.main.async {
            self.isRunning = false
        }
    }
}
