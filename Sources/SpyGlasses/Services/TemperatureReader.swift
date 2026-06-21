import Foundation
import IOKit

final class TemperatureReader {
  private let preferredKeys = [
    "TC0P",
    "TC0E",
    "TC0F",
    "TC0D",
    "Tp09",
    "Tp0T",
    "Tm0P",
    "Ts0P",
  ]
  private lazy var smc = SMCConnection()

  func currentTemperatureCelsius() -> Double? {
    if let temperature = HIDTemperatureReader.currentTemperatureCelsius() {
      return temperature
    }

    guard let smc else {
      return nil
    }

    for key in preferredKeys {
      if let temperature = smc.temperature(forKey: key) {
        return temperature
      }
    }

    return nil
  }
}

private enum HIDTemperatureReader {
  private static let temperatureEventType: Int64 = 15
  private static let temperatureField = Int32(15 << 16)

  static func currentTemperatureCelsius() -> Double? {
    guard let system = IOHIDEventSystemClientCreateRaw(kCFAllocatorDefault)?.takeRetainedValue()
    else {
      return nil
    }

    let matching = [
      "PrimaryUsagePage": 0xff00,
      "PrimaryUsage": 5,
    ] as CFDictionary

    IOHIDEventSystemClientSetMatchingRaw(system, matching)

    guard let services = IOHIDEventSystemClientCopyServicesRaw(system)?.takeRetainedValue() else {
      return nil
    }

    var acceleratorTemps: [Double] = []
    var dieTemps: [Double] = []
    var socTemps: [Double] = []

    for index in 0..<CFArrayGetCount(services) {
      let service = unsafeBitCast(CFArrayGetValueAtIndex(services, index), to: CFTypeRef.self)

      guard
        let product = IOHIDServiceClientCopyPropertyRaw(service, "Product" as CFString)?
          .takeRetainedValue() as? String,
        let event = IOHIDServiceClientCopyEventRaw(service, temperatureEventType, 0, 0)?
          .takeRetainedValue()
      else {
        continue
      }

      let temperature = IOHIDEventGetFloatValueRaw(event, temperatureField)

      guard temperature > 0, temperature < 150 else {
        continue
      }

      if product.hasPrefix("eACC") || product.hasPrefix("pACC") {
        acceleratorTemps.append(temperature)
      } else if product.hasPrefix("PMU tdie") {
        dieTemps.append(temperature)
      } else if product.hasPrefix("SOC MTR Temp Sensor") {
        socTemps.append(temperature)
      }
    }

    let temperatures =
      !dieTemps.isEmpty ? dieTemps : (!acceleratorTemps.isEmpty ? acceleratorTemps : socTemps)

    guard !temperatures.isEmpty else {
      return nil
    }

    return temperatures.reduce(0, +) / Double(temperatures.count)
  }
}

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreateRaw(_ allocator: CFAllocator?) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
@discardableResult
private func IOHIDEventSystemClientSetMatchingRaw(
  _ client: CFTypeRef,
  _ matching: CFDictionary
) -> Int32

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServicesRaw(_ client: CFTypeRef) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEventRaw(
  _ service: CFTypeRef,
  _ eventType: Int64,
  _ options: Int32,
  _ timestamp: Int64
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyPropertyRaw(
  _ service: CFTypeRef,
  _ property: CFString
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValueRaw(
  _ event: CFTypeRef,
  _ field: Int32
) -> Double

private final class SMCConnection {
  private let connection: io_connect_t

  init?() {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))

    guard service != IO_OBJECT_NULL else {
      return nil
    }

    var connection = io_connect_t()
    let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
    IOObjectRelease(service)

    guard result == kIOReturnSuccess else {
      return nil
    }

    self.connection = connection
  }

  deinit {
    IOServiceClose(connection)
  }

  func temperature(forKey key: String) -> Double? {
    guard let keyInfo = readKeyInfo(key) else {
      return nil
    }

    guard keyInfo.dataTypeString == "sp78",
      let bytes = readBytes(key, size: Int(keyInfo.dataSize)),
      bytes.count >= 2
    else {
      return nil
    }

    let rawValue = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
    return Double(rawValue) / 256.0
  }

  private func readKeyInfo(_ key: String) -> SMCKeyInfo? {
    var input = SMCKeyData()
    input.key = SMCKeyData.keyCode(key)
    input.data8 = SMCCommand.readKeyInfo

    guard let output = call(input) else {
      return nil
    }

    return output.keyInfo
  }

  private func readBytes(_ key: String, size: Int) -> [UInt8]? {
    var input = SMCKeyData()
    input.key = SMCKeyData.keyCode(key)
    input.keyInfo.dataSize = UInt32(size)
    input.data8 = SMCCommand.readBytes

    guard let output = call(input) else {
      return nil
    }

    return SMCByteBuffer.array(output.bytes).prefix(size).map { $0 }
  }

  private func call(_ input: SMCKeyData) -> SMCKeyData? {
    var input = input
    var output = SMCKeyData()
    var outputSize = MemoryLayout<SMCKeyData>.stride

    let result = withUnsafeMutablePointer(to: &input) { inputPointer in
      withUnsafeMutablePointer(to: &output) { outputPointer in
        IOConnectCallStructMethod(
          connection,
          SMCCommand.selector,
          inputPointer,
          MemoryLayout<SMCKeyData>.stride,
          outputPointer,
          &outputSize
        )
      }
    }

    guard result == kIOReturnSuccess else {
      return nil
    }

    return output
  }
}

private enum SMCCommand {
  static let selector: UInt32 = 2
  static let readBytes: UInt8 = 5
  static let readKeyInfo: UInt8 = 9
}

private struct SMCVersion {
  var major: UInt8 = 0
  var minor: UInt8 = 0
  var build: UInt8 = 0
  var reserved: UInt8 = 0
  var release: UInt16 = 0
}

private struct SMCPLimitData {
  var version: UInt16 = 0
  var length: UInt16 = 0
  var cpuPLimit: UInt32 = 0
  var gpuPLimit: UInt32 = 0
  var memPLimit: UInt32 = 0
}

private struct SMCKeyInfo {
  var dataSize: UInt32 = 0
  var dataType: UInt32 = 0
  var dataAttributes: UInt8 = 0

  var dataTypeString: String {
    SMCKeyData.string(from: dataType)
  }
}

private struct SMCKeyData {
  var key: UInt32 = 0
  var vers = SMCVersion()
  var pLimitData = SMCPLimitData()
  var keyInfo = SMCKeyInfo()
  var result: UInt8 = 0
  var status: UInt8 = 0
  var data8: UInt8 = 0
  var data32: UInt32 = 0
  var bytes = SMCByteBuffer.zero

  static func keyCode(_ key: String) -> UInt32 {
    var result: UInt32 = 0

    for scalar in key.unicodeScalars.prefix(4) {
      result = (result << 8) + UInt32(scalar.value)
    }

    return result
  }

  static func string(from keyCode: UInt32) -> String {
    let scalars = [
      UInt8((keyCode >> 24) & 0xff),
      UInt8((keyCode >> 16) & 0xff),
      UInt8((keyCode >> 8) & 0xff),
      UInt8(keyCode & 0xff),
    ]

    return String(bytes: scalars, encoding: .ascii) ?? ""
  }
}

private typealias SMCBytes = (
  UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
  UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
  UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
  UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private enum SMCByteBuffer {
  static var zero: SMCBytes {
    (
      0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0
    )
  }

  static func array(_ bytes: SMCBytes) -> [UInt8] {
    withUnsafeBytes(of: bytes) { pointer in
      Array(pointer)
    }
  }
}
