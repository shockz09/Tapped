import Foundation

/// Handles iCloud sync via NSUbiquitousKeyValueStore
final class iCloudSync {
    private let store = NSUbiquitousKeyValueStore.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let keyPrefix = "stats_"

    init() {
        // Force initial sync
        store.synchronize()
    }

    /// Save stats to iCloud
    func save(_ stats: DailyStats) {
        guard let data = try? encoder.encode(stats),
              let json = String(data: data, encoding: .utf8) else { return }

        store.set(json, forKey: keyPrefix + stats.id)
        store.synchronize()
    }

    /// Load stats for a specific date from iCloud
    func load(dateID: String) -> DailyStats? {
        guard let json = store.string(forKey: keyPrefix + dateID),
              let data = json.data(using: .utf8),
              let stats = try? decoder.decode(DailyStats.self, from: data) else {
            return nil
        }
        return stats
    }

    /// Load all stats from iCloud
    func loadAll() -> [String: DailyStats] {
        var result: [String: DailyStats] = [:]
        for key in store.dictionaryRepresentation.keys {
            guard key.hasPrefix(keyPrefix) else { continue }
            let dateID = String(key.dropFirst(keyPrefix.count))
            if let stats = load(dateID: dateID) {
                result[dateID] = stats
            }
        }
        return result
    }

    /// Observe external changes from other devices
    func observeChanges(handler: @escaping ([DailyStats]) -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
                return
            }

            let changedStats = changedKeys
                .filter { $0.hasPrefix(self.keyPrefix) }
                .compactMap { key -> DailyStats? in
                    let dateID = String(key.dropFirst(self.keyPrefix.count))
                    return self.load(dateID: dateID)
                }

            if !changedStats.isEmpty {
                handler(changedStats)
            }
        }
    }
}
