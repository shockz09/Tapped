import SwiftUI

struct HistoryView: View {
    let stats: [DailyStats]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Keystroke History")
                .font(.headline)
                .padding()

            Divider()

            // Stats list
            if stats.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No history yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(stats) { stat in
                    HStack {
                        Text(DateHelpers.displayString(from: stat.id))
                            .frame(width: 80, alignment: .leading)

                        Spacer()

                        Text(formatNumber(stat.totalKeystrokes))
                            .monospacedDigit()
                            .fontWeight(.medium)

                        // Visual bar
                        GeometryReader { geo in
                            let maxCount = stats.map(\.totalKeystrokes).max() ?? 1
                            let width = CGFloat(stat.totalKeystrokes) / CGFloat(maxCount) * geo.size.width

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor.opacity(0.6))
                                .frame(width: max(width, 2), height: 16)
                        }
                        .frame(width: 100)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 350, height: 400)
    }

    private func formatNumber(_ number: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

final class HistoryWindowController {
    private var window: NSWindow?
    private var hostingController: NSHostingController<HistoryView>?
    private var closeObserver: NSObjectProtocol?

    deinit {
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func show(stats: [DailyStats]) {
        // Update existing window if open
        if let existingWindow = window {
            hostingController?.rootView = HistoryView(stats: stats)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window
        let historyView = HistoryView(stats: stats)
        let hosting = NSHostingController(rootView: historyView)
        hostingController = hosting

        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Typing Stats History"
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.setContentSize(NSSize(width: 350, height: 400))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Clear old observer if any
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Track window close to clear references
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
            self?.hostingController = nil
        }

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }
        window?.close()
        window = nil
        hostingController = nil
    }
}
