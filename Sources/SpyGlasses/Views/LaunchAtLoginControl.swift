import SwiftUI

struct LaunchAtLoginControl: View {
  enum Style {
    case compact
    case settings
  }

  let style: Style
  var onChange: () -> Void = {}

  @State private var isEnabled = LaunchAtLoginController.isEnabled
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      toggle

      if let errorMessage {
        Text(errorMessage)
          .font(style == .compact ? .caption2 : .caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear {
      isEnabled = LaunchAtLoginController.isEnabled
    }
  }

  @ViewBuilder
  private var toggle: some View {
    switch style {
    case .compact:
      HStack(spacing: 12) {
        Text("Auto Start")
          .font(.callout)

        Spacer()

        Toggle("Auto Start", isOn: $isEnabled)
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.small)
          .onChange(of: isEnabled) { _, enabled in
            updateLaunchAtLogin(enabled)
          }
      }
    case .settings:
      Toggle("Launch at login", isOn: $isEnabled)
        .onChange(of: isEnabled) { _, enabled in
          updateLaunchAtLogin(enabled)
        }
    }
  }

  private func updateLaunchAtLogin(_ enabled: Bool) {
    onChange()

    do {
      try LaunchAtLoginController.setEnabled(enabled)
      errorMessage = nil
    } catch {
      isEnabled = LaunchAtLoginController.isEnabled
      errorMessage = style == .compact
        ? "Launch at login failed: \(error.localizedDescription)"
        : error.localizedDescription
    }
  }
}
