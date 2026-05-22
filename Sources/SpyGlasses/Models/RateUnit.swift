import Foundation

enum RateUnit: String {
  case megabits = "Mbps"
  case kilobits = "Kbps"

  func value(from bytesPerSecond: Double) -> Double {
    switch self {
    case .megabits:
      bytesPerSecond * 8 / 1_000_000
    case .kilobits:
      bytesPerSecond * 8 / 1_000
    }
  }

  static func automatic(for bytesPerSecond: Double) -> RateUnit {
    bytesPerSecond * 8 >= 1_000_000 ? .megabits : .kilobits
  }
}
