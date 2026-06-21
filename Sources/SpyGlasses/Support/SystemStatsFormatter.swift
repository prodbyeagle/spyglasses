import Foundation

enum SystemStatsFormatter {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func percentage(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }

        return (value * 100).formatted(.number.precision(.fractionLength(0))) + "%"
    }

    static func temperature(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }

        return value.formatted(.number.precision(.fractionLength(1))) + " C"
    }

    static func bytes(_ value: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(value))
    }

    static func uptime(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}
