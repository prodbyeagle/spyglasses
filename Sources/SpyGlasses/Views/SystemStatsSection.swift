import SwiftUI

struct SystemStatsSection: View {
    let stats: SystemStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Stats")
                .font(.callout)

            VStack(spacing: 6) {
                statRow(
                    title: "Download",
                    value: SpeedFormatter.string(bytesPerSecond: stats.network.downloadBytesPerSecond)
                )

                statRow(
                    title: "Upload",
                    value: SpeedFormatter.string(bytesPerSecond: stats.network.uploadBytesPerSecond)
                )

                statRow(
                    title: "Temperature",
                    value: SystemStatsFormatter.temperature(stats.temperatureCelsius)
                )

                statRow(
                    title: "CPU",
                    value: SystemStatsFormatter.percentage(stats.cpuUsage)
                )

                statRow(
                    title: "Memory",
                    value: "\(SystemStatsFormatter.percentage(stats.memory.usage))  \(SystemStatsFormatter.bytes(stats.memory.usedBytes))"
                )

                statRow(
                    title: "Disk",
                    value: "\(SystemStatsFormatter.percentage(stats.disk.usage))  \(SystemStatsFormatter.bytes(stats.disk.freeBytes)) free"
                )

                statRow(
                    title: "Uptime",
                    value: SystemStatsFormatter.uptime(stats.uptime)
                )
            }
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 82, alignment: .leading)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 150, alignment: .trailing)
        }
    }
}
