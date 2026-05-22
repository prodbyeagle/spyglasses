import Combine
import Darwin
import Foundation

@MainActor
final class NetworkMonitor: ObservableObject {
  @Published private(set) var downloadBytesPerSecond: Double = 0
  @Published private(set) var uploadBytesPerSecond: Double = 0

  private var lastSample = NetworkSample.current()
  private var refreshTask: Task<Void, Never>?

  init() {
    refreshTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        self?.refresh()

        let interval = UInt64(UpdateIntervalSettings.current * 1_000_000_000)
        try? await Task.sleep(nanoseconds: interval)
      }
    }
  }

  deinit {
    refreshTask?.cancel()
  }

  private func refresh() {
    let sample = NetworkSample.current()
    let interval = max(sample.timestamp.timeIntervalSince(lastSample.timestamp), 0.1)

    if sample.receivedBytes >= lastSample.receivedBytes {
      downloadBytesPerSecond = Double(sample.receivedBytes - lastSample.receivedBytes) / interval
    } else {
      downloadBytesPerSecond = 0
    }

    if sample.sentBytes >= lastSample.sentBytes {
      uploadBytesPerSecond = Double(sample.sentBytes - lastSample.sentBytes) / interval
    } else {
      uploadBytesPerSecond = 0
    }

    lastSample = sample
  }
}

private struct NetworkSample {
  let receivedBytes: UInt64
  let sentBytes: UInt64
  let timestamp: Date

  static func current() -> NetworkSample {
    var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
    var receivedBytes: UInt64 = 0
    var sentBytes: UInt64 = 0

    guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
      return NetworkSample(receivedBytes: 0, sentBytes: 0, timestamp: Date())
    }

    defer { freeifaddrs(interfaceAddresses) }

    var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

    while let currentPointer = pointer {
      pointer = currentPointer.pointee.ifa_next

      let interface = currentPointer.pointee
      let flags = Int32(interface.ifa_flags)
      let name = String(cString: interface.ifa_name)

      guard (flags & IFF_UP) != 0,
        (flags & IFF_RUNNING) != 0,
        (flags & IFF_LOOPBACK) == 0,
        name.hasPrefix("en"),
        let address = interface.ifa_addr,
        address.pointee.sa_family == UInt8(AF_LINK),
        let data = interface.ifa_data
      else {
        continue
      }

      let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
      receivedBytes += UInt64(interfaceData.ifi_ibytes)
      sentBytes += UInt64(interfaceData.ifi_obytes)
    }

    return NetworkSample(
      receivedBytes: receivedBytes,
      sentBytes: sentBytes,
      timestamp: Date()
    )
  }
}
