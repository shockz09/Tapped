import Foundation
import IOKit

/// Provides a stable device identifier using the hardware UUID
struct DeviceIdentifier {
    static let current: String = {
        // Try to get hardware UUID from IOKit
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }

        if let uuid = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return uuid
        }

        // Fallback to UserDefaults UUID if hardware UUID unavailable
        let key = "typingstats_device_uuid"
        if let stored = UserDefaults.standard.string(forKey: key) {
            return stored
        }
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: key)
        return newUUID
    }()
}
