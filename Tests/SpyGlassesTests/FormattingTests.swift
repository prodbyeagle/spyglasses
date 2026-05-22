import XCTest
@testable import SpyGlasses

final class FormattingTests: XCTestCase {
  func testSpeedFormatterUsesKilobitsBelowOneMegabit() {
    XCTAssertEqual(SpeedFormatter.string(bytesPerSecond: 125), "1.00 Kbps")
  }

  func testSpeedFormatterUsesMegabitsAtOneMegabit() {
    XCTAssertEqual(SpeedFormatter.string(bytesPerSecond: 125_000), "1.00 Mbps")
  }

  func testUpdateIntervalNormalizationClampsToSupportedRange() {
    XCTAssertEqual(UpdateIntervalSettings.normalized(0.01), 0.5)
    XCTAssertEqual(UpdateIntervalSettings.normalized(3), 2)
  }
}
