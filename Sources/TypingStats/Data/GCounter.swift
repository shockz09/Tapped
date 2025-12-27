import Foundation

/// A G-Counter (Grow-only Counter) CRDT for conflict-free merging across devices.
/// Each device maintains its own count, and the total is the sum of all device counts.
/// Merging takes the max value per device, ensuring convergence.
struct GCounter: Codable, Equatable {
    private var counts: [String: UInt64] = [:]

    init() {}

    /// Increment the counter for a specific device (overflow-safe)
    mutating func increment(deviceID: String, by amount: UInt64 = 1) {
        let current = counts[deviceID, default: 0]
        let (result, overflow) = current.addingReportingOverflow(amount)
        counts[deviceID] = overflow ? UInt64.max : result
    }

    /// Get the count for a specific device
    func count(for deviceID: String) -> UInt64 {
        counts[deviceID] ?? 0
    }

    /// Total count across all devices (overflow-safe)
    var total: UInt64 {
        counts.values.reduce(UInt64(0)) { sum, count in
            let (result, overflow) = sum.addingReportingOverflow(count)
            return overflow ? UInt64.max : result
        }
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
