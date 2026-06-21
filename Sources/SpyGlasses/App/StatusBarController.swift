import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let monitor = SystemStatsMonitor()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let statusFont = NSFont.monospacedSystemFont(
        ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .medium)

    private var anchoredStatusItemLength: CGFloat?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.cell?.lineBreakMode = .byClipping
            button.cell?.wraps = false
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(systemStats: monitor)
        )

        monitor.$stats
            .sink { [weak self] _ in
                self?.updateStatus()
            }
            .store(in: &cancellables)

        updateStatus()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            unanchorStatusItem()
            return
        }

        guard let button = statusItem.button else {
            return
        }

        anchorStatusItem()
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    private func updateStatus() {
        let titleParts = [
            "D \(SpeedFormatter.string(bytesPerSecond: monitor.stats.network.downloadBytesPerSecond))",
            "U \(SpeedFormatter.string(bytesPerSecond: monitor.stats.network.uploadBytesPerSecond))",
            "T \(SystemStatsFormatter.temperature(monitor.stats.temperatureCelsius))",
        ]
        let title = titleParts.joined(separator: "  ")

        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: statusFont]
        )

        if popover.isShown {
            anchorStatusItem()
        }
    }

    private func anchorStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if anchoredStatusItemLength == nil {
            anchoredStatusItemLength = button.bounds.width
        }

        statusItem.length = max(anchoredStatusItemLength ?? NSStatusItem.variableLength, 1)
    }

    private func unanchorStatusItem() {
        anchoredStatusItemLength = nil
        statusItem.length = NSStatusItem.variableLength
    }
}
