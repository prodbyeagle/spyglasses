import AppKit
import SwiftUI

struct MenuBarContentView: View {
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
      LaunchAtLoginControl(style: .compact, onChange: performHapticFeedback)

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

      SpeedTestSection(speedTest: speedTest, onStart: performHapticFeedback)
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
