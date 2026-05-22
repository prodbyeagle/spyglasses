import Foundation

enum UpdateIntervalSettings {
  static let key = "updateInterval"
  static let defaultValue: TimeInterval = 0.5
  static let range: ClosedRange<Double> = 0.1...2
  static let step: Double = 0.1

  static var current: TimeInterval {
    get {
      let value = UserDefaults.standard.double(forKey: key)
      return normalized(value == 0 ? defaultValue : value)
    }
    set {
      UserDefaults.standard.set(normalized(newValue), forKey: key)
    }
  }

  static func normalized(_ value: Double) -> Double {
    min(max(value, range.lowerBound), range.upperBound)
  }

  static func stopIndex(for value: Double) -> Int {
    Int((normalized(value) / step).rounded())
  }
}
