import Foundation

/// Represents keystroke statistics for a single day
struct DailyStats: Codable, Identifiable, Equatable {
    /// Date identifier in YYYY-MM-DD format
    let id: String
    /// G-Counter for this day's keystrokes
    var counter: GCounter
    /// When this record was first created
    let createdAt: Date
    /// Last modification time
    var modifiedAt: Date

    /// Total keystrokes across all devices for this day
    var totalKeystrokes: UInt64 {
        counter.total
    }

    init(date: Date = Date()) {
        self.id = DateHelpers.dateID(from: date)
        self.counter = GCounter()
        self.createdAt = date
        self.modifiedAt = date
    }

    /// Increment the keystroke count for the current device
    mutating func increment(by amount: UInt64 = 1) {
        counter.increment(deviceID: DeviceIdentifier.current, by: amount)
        modifiedAt = Date()
    }

    /// Merge with another DailyStats (for iCloud sync)
    mutating func merge(with other: DailyStats) {
        counter.merge(with: other.counter)
        modifiedAt = Date()
    }
}

/// Date formatting utilities
struct DateHelpers {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    static func todayID() -> String {
        formatter.string(from: Date())
    }

    static func dateID(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from id: String) -> Date? {
        formatter.date(from: id)
    }

    /// Format date ID for display (e.g., "Dec 27")
    static func displayString(from id: String) -> String {
        guard let date = date(from: id) else { return id }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
    }

    /// Get date ID for N days ago
    static func dateID(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }

    /// Short display format (e.g., "12/26")
    static func shortDisplayString(from id: String) -> String {
        guard let date = date(from: id) else { return id }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M/d"
        return displayFormatter.string(from: date)
    }
}
