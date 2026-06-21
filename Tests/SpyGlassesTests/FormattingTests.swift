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

  func testSystemStatsFormatterFormatsUnavailableValues() {
    XCTAssertEqual(SystemStatsFormatter.percentage(nil), "--")
    XCTAssertEqual(SystemStatsFormatter.temperature(nil), "--")
  }

  func testSystemStatsFormatterFormatsUptime() {
    XCTAssertEqual(SystemStatsFormatter.uptime(65), "1m")
    XCTAssertEqual(SystemStatsFormatter.uptime(3_900), "1h 5m")
    XCTAssertEqual(SystemStatsFormatter.uptime(90_000), "1d 1h")
  }
}
