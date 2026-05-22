import AppKit
import SwiftUI

struct MenuBarContentView: View {
  @State private var autoStart = LaunchAtLoginController.isEnabled
  @StateObject private var speedTest = SpeedTestRunner()
  @AppStorage(UpdateIntervalSettings.key) private var updateInterval = UpdateIntervalSettings.defaultValue

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()
        .padding(.top, 10)
        .padding(.bottom, 12)

      settings
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(width: 300)
    .onAppear {
      autoStart = LaunchAtLoginController.isEnabled
      updateInterval = UpdateIntervalSettings.current
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "network")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 24, height: 24)

      Text("SpyGlasses")
        .font(.headline)

      Spacer()

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Image(systemName: "power")
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      .help("Quit")
    }
  }

  private var settings: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        Text("Auto Start")
          .font(.callout)

        Spacer()

        Toggle("Auto Start", isOn: $autoStart)
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.small)
          .onChange(of: autoStart) { _, enabled in
            performHapticFeedback()

            do {
              try LaunchAtLoginController.setEnabled(enabled)
            } catch {
              autoStart = LaunchAtLoginController.isEnabled
            }
          }
      }

      VStack(alignment: .leading, spacing: 7) {
        updateHeader

        Slider(
          value: $updateInterval,
          in: UpdateIntervalSettings.range,
          step: UpdateIntervalSettings.step
        )
        .controlSize(.small)
        .onChange(of: updateInterval) { oldValue, newValue in
          updateIntervalChanged(oldValue: oldValue, newValue: newValue)
        }

        updateRangeLabels
      }

      Divider()

      speedTestView
    }
  }

  private var speedTestView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Speed Test")
          .font(.callout)

        Spacer()

        Button {
          performHapticFeedback()
          speedTest.start()
        } label: {
          if speedTest.isRunning {
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
        .disabled(speedTest.isRunning)
        .help("Run Speed Test")
      }

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
      }

      if case .failed(let message) = speedTest.phase {
        Text(message)
          .font(.caption2)
          .foregroundStyle(.red)
      }
    }
  }

  private var pingRow: some View {
    HStack {
      HStack(spacing: 5) {
        Text("Ping")

        if speedTest.phase == .ping {
          Circle()
            .fill(.green)
            .frame(width: 5, height: 5)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      Spacer()

      Text(speedTest.pingMilliseconds.map(pingText) ?? (speedTest.phase == .ping ? "Testing" : "--"))
        .font(.caption.monospacedDigit())
        .foregroundStyle(speedTest.pingMilliseconds == nil ? .tertiary : .secondary)
        .contentTransition(.numericText())
        .animation(.snappy(duration: 0.18), value: speedTest.pingMilliseconds)
    }
  }

  private func speedTestRow(title: String, value: Double?, isActive: Bool) -> some View {
    HStack {
      HStack(spacing: 5) {
        Text(title)

        if isActive {
          Circle()
            .fill(.green)
            .frame(width: 5, height: 5)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      Spacer()

      Text(value.map(SpeedFormatter.string(bytesPerSecond:)) ?? (isActive ? "Testing" : "--"))
        .font(.caption.monospacedDigit())
        .foregroundStyle(value == nil ? .tertiary : .secondary)
        .contentTransition(.numericText())
        .animation(.snappy(duration: 0.18), value: value)
    }
  }

  private var updateHeader: some View {
    HStack {
      Text("Update")
        .font(.callout)

      Spacer()

      Text(updateIntervalText)
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .contentTransition(.numericText(value: updateInterval))
        .animation(.snappy(duration: 0.18), value: updateInterval)
        .frame(width: 34, alignment: .trailing)
    }
  }

  private var updateRangeLabels: some View {
    HStack {
      Text("0.1s")
      Spacer()
      Text("0.5s")
      Spacer()
      Text("1.0s")
      Spacer()
      Text("1.5s")
      Spacer()
      Text("2.0s")
    }
    .font(.caption2.monospacedDigit())
    .foregroundStyle(.tertiary)
  }

  private var updateIntervalText: String {
    updateInterval.formatted(.number.precision(.fractionLength(1))) + "s"
  }

  private func pingText(_ milliseconds: Double) -> String {
    milliseconds.formatted(.number.precision(.fractionLength(1))) + " ms"
  }

  private func updateIntervalChanged(oldValue: Double, newValue: Double) {
    let normalizedValue = UpdateIntervalSettings.normalized(newValue)

    if normalizedValue != newValue {
      updateInterval = normalizedValue
      return
    }

    if UpdateIntervalSettings.stopIndex(for: oldValue) != UpdateIntervalSettings.stopIndex(for: newValue) {
      performHapticFeedback()
    }
  }

  private func performHapticFeedback() {
    let performer = NSHapticFeedbackManager.defaultPerformer
      performer.perform(.levelChange, performanceTime: .now)
    }
}
