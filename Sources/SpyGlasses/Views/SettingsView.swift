import SwiftUI

struct SettingsView: View {
  @AppStorage(UpdateIntervalSettings.key) private var updateInterval = UpdateIntervalSettings.defaultValue

  var body: some View {
    Form {
      LaunchAtLoginControl(style: .settings)

      VStack(alignment: .leading) {
        Text("Update interval: \(updateInterval.formatted(.number.precision(.fractionLength(1))))s")

        Slider(
          value: $updateInterval,
          in: UpdateIntervalSettings.range,
          step: UpdateIntervalSettings.step
        )
      }
    }
    .padding(20)
    .frame(width: 360)
    .onAppear {
      updateInterval = UpdateIntervalSettings.current
    }
  }
}
