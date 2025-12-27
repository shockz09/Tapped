import Foundation

/// Handles local JSON file persistence to Application Support
final class LocalStore {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Application Support directory for TypingStats
    private lazy var storeDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TypingStats", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Path to the stats JSON file
    private var statsFilePath: URL {
        storeDirectory.appendingPathComponent("stats.json")
    }

    /// Save a single day's stats
    func save(_ stats: DailyStats) {
        var allStats = loadAll()
        allStats[stats.id] = stats
        saveAll(allStats)
    }

    /// Load all stats from disk
    func loadAll() -> [String: DailyStats] {
        guard fileManager.fileExists(atPath: statsFilePath.path),
              let data = try? Data(contentsOf: statsFilePath),
              let stats = try? decoder.decode([String: DailyStats].self, from: data) else {
            return [:]
        }
        return stats
    }

    /// Save all stats to disk (atomic write)
    private func saveAll(_ stats: [String: DailyStats]) {
        guard let data = try? encoder.encode(stats) else { return }

        // Atomic write via temp file
        let tempURL = storeDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try? fileManager.replaceItemAt(statsFilePath, withItemAt: tempURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
        }
    }

    /// Delete all stored data (for testing/reset)
    func deleteAll() {
        try? fileManager.removeItem(at: statsFilePath)
    }
}
