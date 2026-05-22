import Foundation

enum SpeedFormatter {
  static func string(bytesPerSecond: Double) -> String {
    let unit = RateUnit.automatic(for: bytesPerSecond)
    let value = unit.value(from: bytesPerSecond)
    let decimals: Int

    if value >= 100 {
      decimals = 0
    } else if value >= 10 {
      decimals = 1
    } else {
      decimals = 2
    }

    let formattedValue = String(format: "%.\(decimals)f", value)
    return "\(formattedValue) \(unit.rawValue)"
  }
}
