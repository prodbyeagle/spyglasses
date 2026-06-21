import SwiftUI

struct SpeedTestSection: View {
    @ObservedObject var speedTest: SpeedTestRunner
    let onStart: () -> Void
    let onValueUpdate: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            switch speedTest.installationState {
            case .checking:
                checkingView
            case .installed:
                resultsView
            case .notInstalled:
                installPrompt
            case .installing:
                installingView
            case .failed(let message):
                installPrompt(message: message)
            }
        }
        .onChange(of: speedTest.phase) { oldValue, newValue in
            if oldValue.runningStep != newValue.runningStep, newValue.isRunning {
                onValueUpdate()
            }

            if oldValue.isRunning && !newValue.isRunning {
                onFinish()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Speed Test")
                .font(.callout)

            Spacer()

            Button {
                onStart()
                speedTest.start()
            } label: {
                if speedTest.isRunning || speedTest.installationState == .checking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.borderless)
            .disabled(speedTest.isRunning || speedTest.installationState != .installed)
            .help("Run Speed Test")
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 5) {
                pingRow

                speedTestRow(
                    title: "Download",
                    value: speedTest.downloadBytesPerSecond,
                    isActive: speedTest.phase == .download
                )

                speedTestRow(
                    title: "Upload",
                    value: speedTest.uploadBytesPerSecond,
                    isActive: speedTest.phase == .upload
                )
            }

            if let serverName = speedTest.serverName {
                Text(serverName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if case .failed(let message) = speedTest.phase {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var checkingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Checking Speedtest CLI")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var installingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Installing with Homebrew")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var installPrompt: some View {
        installPrompt(message: nil)
    }

    private func installPrompt(message: String?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Speedtest CLI not installed")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Install the Ookla CLI with Homebrew to run tests from SpyGlasses.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                onStart()
                speedTest.installSpeedtestCLI()
            } label: {
                Text("Install")
            }
            .controlSize(.small)
            .disabled(speedTest.installationState == .installing)
        }
    }

    private var pingRow: some View {
        HStack {
            rowTitle("Ping", isActive: speedTest.phase == .ping)

            Spacer(minLength: 12)

            Text(speedTest.pingMilliseconds.map(pingText) ?? (speedTest.phase == .ping ? "Testing" : "--"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(speedTest.pingMilliseconds == nil ? .tertiary : .secondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: speedTest.pingMilliseconds)
                .lineLimit(1)
        }
    }

    private func speedTestRow(title: String, value: Double?, isActive: Bool) -> some View {
        HStack {
            rowTitle(title, isActive: isActive)

            Spacer(minLength: 12)

            Text(value.map(SpeedFormatter.string(bytesPerSecond:)) ?? (isActive ? "Testing" : "--"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(value == nil ? .tertiary : .secondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: value)
                .lineLimit(1)
        }
    }

    private func rowTitle(_ title: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Text(title)

            Circle()
                .fill(isActive ? .green : .clear)
                .frame(width: 5, height: 5)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func pingText(_ milliseconds: Double) -> String {
        milliseconds.formatted(.number.precision(.fractionLength(1))) + " ms"
    }
}

private extension SpeedTestRunner.Phase {
    var isRunning: Bool {
        self == .ping || self == .download || self == .upload
    }

    var runningStep: Int? {
        switch self {
        case .ping:
            0
        case .download:
            1
        case .upload:
            2
        case .idle, .failed:
            nil
        }
    }
}
