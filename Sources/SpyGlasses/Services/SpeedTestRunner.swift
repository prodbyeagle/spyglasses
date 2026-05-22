import Foundation

@MainActor
final class SpeedTestRunner: ObservableObject {
  enum Phase: Equatable {
    case idle
    case ping
    case download
    case upload
    case failed(String)
  }

  @Published private(set) var phase: Phase = .idle
  @Published private(set) var pingMilliseconds: Double?
  @Published private(set) var downloadBytesPerSecond: Double?
  @Published private(set) var uploadBytesPerSecond: Double?
  @Published private(set) var serverName: String?

  private var task: Task<Void, Never>?

  var isRunning: Bool {
    phase == .ping || phase == .download || phase == .upload
  }

  deinit {
    task?.cancel()
  }

  func start() {
    guard !isRunning else {
      return
    }

    task?.cancel()
    phase = .ping
    pingMilliseconds = nil
    downloadBytesPerSecond = nil
    uploadBytesPerSecond = nil
    serverName = nil

    task = Task { [weak self] in
      guard let self else {
        return
      }

      do {
        let result = try await Self.runOoklaSpeedTest { [weak self] event in
          Task { @MainActor in
            self?.apply(event)
          }
        }

        downloadBytesPerSecond = Double(result.download.bandwidth)
        uploadBytesPerSecond = Double(result.upload.bandwidth)
        pingMilliseconds = result.ping.latency
        serverName = result.server.displayName
        phase = .idle
      } catch is CancellationError {
        phase = .idle
      } catch {
        phase = .failed("Failed")
      }
    }
  }

  private func apply(_ event: OoklaSpeedTestEvent) {
    switch event.type {
    case "testStart":
      serverName = event.server?.displayName
    case "ping":
      phase = .ping
      if let latency = event.ping?.latency {
        pingMilliseconds = latency
      }
    case "download":
      phase = .download
      if let bandwidth = event.download?.bandwidth {
        downloadBytesPerSecond = Double(bandwidth)
      }
    case "upload":
      phase = .upload
      if let bandwidth = event.upload?.bandwidth {
        uploadBytesPerSecond = Double(bandwidth)
      }
    case "result":
      if let latency = event.ping?.latency {
        pingMilliseconds = latency
      }
      if let bandwidth = event.download?.bandwidth {
        downloadBytesPerSecond = Double(bandwidth)
      }
      if let bandwidth = event.upload?.bandwidth {
        uploadBytesPerSecond = Double(bandwidth)
      }
      if let server = event.server {
        serverName = server.displayName
      }
    default:
      break
    }
  }

  nonisolated private static func runOoklaSpeedTest(
    onEvent: @escaping @Sendable (OoklaSpeedTestEvent) -> Void
  ) async throws -> OoklaSpeedTestResult {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let parser = JSONLineParser(onEvent: onEvent)

    process.executableURL = try speedtestExecutableURL()
    process.arguments = [
      "--accept-license",
      "--accept-gdpr",
      "--format=jsonl",
      "--progress=yes",
      "--progress-update-interval=500",
    ]
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
          let data = handle.availableData

          guard !data.isEmpty else {
            return
          }

          parser.append(data)
        }

        process.terminationHandler = { process in
          outputPipe.fileHandleForReading.readabilityHandler = nil
          parser.finish()

          let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()

          guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput, encoding: .utf8) ?? "Speedtest failed"
            continuation.resume(throwing: SpeedTestError.processFailed(message))
            return
          }

          if let result = parser.result {
            continuation.resume(returning: result)
          } else {
            continuation.resume(throwing: SpeedTestError.missingResult)
          }
        }

        do {
          try process.run()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    } onCancel: {
      process.terminate()
    }
  }

  nonisolated private static func speedtestExecutableURL() throws -> URL {
    let paths = [
      "/opt/homebrew/bin/speedtest",
      "/usr/local/bin/speedtest",
      "/usr/bin/speedtest",
    ]

    guard let path = paths.first(where: FileManager.default.isExecutableFile(atPath:)) else {
      throw SpeedTestError.missingExecutable
    }

    return URL(fileURLWithPath: path)
  }
}

private final class JSONLineParser: @unchecked Sendable {
  private var buffer = Data()
  private let decoder = JSONDecoder()
  private let lock = NSLock()
  private let onEvent: @Sendable (OoklaSpeedTestEvent) -> Void

  private(set) var result: OoklaSpeedTestResult?

  init(onEvent: @escaping @Sendable (OoklaSpeedTestEvent) -> Void) {
    self.onEvent = onEvent
  }

  func append(_ data: Data) {
    lock.lock()
    defer { lock.unlock() }

    buffer.append(data)
    parseCompleteLines()
  }

  func finish() {
    lock.lock()
    defer { lock.unlock() }

    parseLine(buffer)
    buffer.removeAll()
  }

  private func parseCompleteLines() {
    while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
      let line = buffer[..<newlineRange.lowerBound]
      parseLine(Data(line))
      buffer.removeSubrange(..<newlineRange.upperBound)
    }
  }

  private func parseLine(_ line: Data) {
    guard !line.isEmpty,
      let event = try? decoder.decode(OoklaSpeedTestEvent.self, from: line)
    else {
      return
    }

    onEvent(event)

    if event.type == "result",
      let ping = event.ping,
      let download = event.download,
      let upload = event.upload,
      let server = event.server
    {
      result = OoklaSpeedTestResult(ping: ping, download: download, upload: upload, server: server)
    }
  }
}

private struct OoklaSpeedTestEvent: Decodable, Sendable {
  let type: String
  let ping: Ping?
  let download: Transfer?
  let upload: Transfer?
  let server: Server?
}

private struct OoklaSpeedTestResult: Sendable {
  let ping: Ping
  let download: Transfer
  let upload: Transfer
  let server: Server
}

private struct Ping: Decodable, Sendable {
  let latency: Double
}

private struct Transfer: Decodable, Sendable {
  let bandwidth: Int
}

private struct Server: Decodable, Sendable {
  let name: String
  let location: String

  var displayName: String {
    "\(name), \(location)"
  }
}

private enum SpeedTestError: Error {
  case missingExecutable
  case missingResult
  case processFailed(String)
}
