import Foundation

/// A G-Counter (Grow-only Counter) CRDT for conflict-free merging across devices.
/// Each device maintains its own count, and the total is the sum of all device counts.
/// Merging takes the max value per device, ensuring convergence.
struct GCounter: Codable, Equatable {
    private var counts: [String: UInt64] = [:]

    init() {}

    /// Increment the counter for a specific device
    mutating func increment(deviceID: String, by amount: UInt64 = 1) {
        counts[deviceID, default: 0] += amount
    }

    /// Get the count for a specific device
    func count(for deviceID: String) -> UInt64 {
        counts[deviceID] ?? 0
    }

    /// Total count across all devices
    var total: UInt64 {
        counts.values.reduce(0, +)
    }

    /// Merge with another G-Counter (CRDT merge: max per device)
    mutating func merge(with other: GCounter) {
        for (deviceID, remoteCount) in other.counts {
            let localCount = counts[deviceID] ?? 0
            counts[deviceID] = max(localCount, remoteCount)
        }
    }

    /// All device IDs that have contributed to this counter
    var deviceIDs: Set<String> {
        Set(counts.keys)
    }
}
