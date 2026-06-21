import Foundation

struct NetworkThroughput: Equatable {
  var downloadBytesPerSecond: Double
  var uploadBytesPerSecond: Double
}

struct MemoryStats: Equatable {
  var usedBytes: UInt64
  var totalBytes: UInt64

  var usage: Double {
    guard totalBytes > 0 else {
      return 0
    }

    return Double(usedBytes) / Double(totalBytes)
  }
}

struct DiskStats: Equatable {
  var freeBytes: UInt64
  var totalBytes: UInt64

  var usedBytes: UInt64 {
    totalBytes > freeBytes ? totalBytes - freeBytes : 0
  }

  var usage: Double {
    guard totalBytes > 0 else {
      return 0
    }

    return Double(usedBytes) / Double(totalBytes)
  }
}

struct SystemStats: Equatable {
  var network: NetworkThroughput
  var cpuUsage: Double?
  var temperatureCelsius: Double?
  var memory: MemoryStats
  var disk: DiskStats
  var uptime: TimeInterval

  static let empty = SystemStats(
    network: NetworkThroughput(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0),
    cpuUsage: nil,
    temperatureCelsius: nil,
    memory: MemoryStats(usedBytes: 0, totalBytes: 0),
    disk: DiskStats(freeBytes: 0, totalBytes: 0),
    uptime: 0
  )
}
