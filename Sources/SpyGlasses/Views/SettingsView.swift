import SwiftUI

struct SettingsView: View {
  @State private var autoStart = LaunchAtLoginController.isEnabled
  @State private var launchAtLoginError: String?
  @AppStorage(UpdateIntervalSettings.key) private var updateInterval = UpdateIntervalSettings.defaultValue

  var body: some View {
    Form {
      Toggle("Launch at login", isOn: $autoStart)
        .onChange(of: autoStart) { _, enabled in
          do {
            try LaunchAtLoginController.setEnabled(enabled)
            launchAtLoginError = nil
          } catch {
            autoStart = LaunchAtLoginController.isEnabled
            launchAtLoginError = error.localizedDescription
          }
        }

      if let launchAtLoginError {
        Text(launchAtLoginError)
          .font(.caption)
          .foregroundStyle(.red)
      }

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
      autoStart = LaunchAtLoginController.isEnabled
      updateInterval = UpdateIntervalSettings.current
    }
  }
}
