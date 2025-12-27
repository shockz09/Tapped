import SwiftUI
import Combine
import ServiceManagement

@main
struct TypingStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemManager: StatusItemManager!
    private var repository: StatsRepository!
    private var permissionManager: PermissionManager!
    private var historyWindowController = HistoryWindowController()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize managers
        repository = StatsRepository()
        permissionManager = PermissionManager()
        statusItemManager = StatusItemManager()

        // Create status item with click handler
        statusItemManager.createStatusItem { [weak self] in
            self?.showMenu()
        }

        // Update status item when keystroke count changes
        repository.$todayStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                let count = Int(stats?.totalKeystrokes ?? 0)
                self?.statusItemManager.updateCount(count)
            }
            .store(in: &cancellables)

        // Start monitoring if already authorized
        permissionManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authorized in
                if authorized {
                    self?.repository.setupKeystrokeMonitoring()
                }
            }
            .store(in: &cancellables)

        // Hide dock icon (menubar-only app)
        NSApp.setActivationPolicy(.accessory)
    }

    private func showMenu() {
        guard let button = statusItemManager.statusItem?.button else { return }

        let menu = NSMenu()

        // Check if we have permission
        if permissionManager.isAuthorized {
            // Stats section
            let todayItem = NSMenuItem(title: "Today: \(formatNumber(repository.todayStats?.totalKeystrokes ?? 0))", action: nil, keyEquivalent: "")
            todayItem.isEnabled = false
            menu.addItem(todayItem)

            let yesterdayItem = NSMenuItem(title: "Yesterday: \(formatNumber(repository.yesterdayCount))", action: nil, keyEquivalent: "")
            yesterdayItem.isEnabled = false
            menu.addItem(yesterdayItem)

            let avg7Item = NSMenuItem(title: "7-day avg: \(formatNumber(repository.sevenDayAvg))", action: nil, keyEquivalent: "")
            avg7Item.isEnabled = false
            menu.addItem(avg7Item)

            let avg30Item = NSMenuItem(title: "30-day avg: \(formatNumber(repository.thirtyDayAvg))", action: nil, keyEquivalent: "")
            avg30Item.isEnabled = false
            menu.addItem(avg30Item)

            if repository.recordCount > 0 {
                let recordItem = NSMenuItem(title: "Record: \(formatNumber(repository.recordCount)) (\(repository.recordDate))", action: nil, keyEquivalent: "")
                recordItem.isEnabled = false
                menu.addItem(recordItem)
            }
        } else {
            let permItem = NSMenuItem(title: "Permission Required", action: #selector(grantPermission), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
        }

        menu.addItem(NSMenuItem.separator())

        // View History
        let historyItem = NSMenuItem(title: "View History...", action: #selector(viewHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        // Start at Login
        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isStartAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu
        statusItemManager.statusItem?.menu = menu
        button.performClick(nil)
        statusItemManager.statusItem?.menu = nil
    }

    private func formatNumber(_ number: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    @objc private func grantPermission() {
        permissionManager.requestAuthorization()
    }

    @objc private func viewHistory() {
        historyWindowController.show(stats: repository.getAllStats())
    }

    @objc private func toggleStartAtLogin() {
        let newValue = !isStartAtLoginEnabled()
        setStartAtLogin(enabled: newValue)
    }

    private func isStartAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setStartAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Login item registration failed - user can retry
            }
        }
    }

    @objc private func quit() {
        repository.forceSave()
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        repository.forceSave()
    }
}
