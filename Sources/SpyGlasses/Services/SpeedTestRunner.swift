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

    enum InstallationState: Equatable {
        case checking
        case installed
        case notInstalled
        case installing
        case failed(String)
    }

    @Published private(set) var installationState: InstallationState = .checking
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var pingMilliseconds: Double?
    @Published private(set) var downloadBytesPerSecond: Double?
    @Published private(set) var uploadBytesPerSecond: Double?
    @Published private(set) var serverName: String?

    private var task: Task<Void, Never>?
    private var installTask: Task<Void, Never>?

    var isRunning: Bool {
        phase == .ping || phase == .download || phase == .upload
    }

    init() {
        refreshInstallationState()
    }

    deinit {
        task?.cancel()
        installTask?.cancel()
    }

    func refreshInstallationState() {
        installationState = Self.isSpeedtestInstalled ? .installed : .notInstalled
    }

    func installSpeedtestCLI() {
        guard installationState != .installing else {
            return
        }

        installTask?.cancel()
        installationState = .installing

        installTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await Self.installSpeedtestWithHomebrew()
                installationState = Self.isSpeedtestInstalled ? .installed : .notInstalled
            } catch let error as SpeedTestError {
                installationState = .failed(error.message)
            } catch {
                installationState = .failed(error.localizedDescription)
            }
        }
    }

    func start() {
        guard !isRunning else {
            return
        }

        guard Self.isSpeedtestInstalled else {
            installationState = .notInstalled
            return
        }

        installationState = .installed
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

            let relay = SpeedTestEventRelay()
            let progressTask = Task { @MainActor [weak self, stream = relay.stream] in
                for await event in stream {
                    self?.apply(event)
                }
            }

            do {
                let result = try await Self.runOoklaSpeedTest { event in
                    relay.yield(event)
                }

                relay.finish()
                await progressTask.value
                apply(result)
                phase = .idle
            } catch is CancellationError {
                relay.finish()
                await progressTask.value
                phase = .idle
            } catch let error as SpeedTestError {
                relay.finish()
                await progressTask.value
                phase = .failed(error.message)
            } catch {
                relay.finish()
                await progressTask.value
                phase = .failed(error.localizedDescription)
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

    private func apply(_ result: OoklaSpeedTestResult) {
        downloadBytesPerSecond = Double(result.download.bandwidth)
        uploadBytesPerSecond = Double(result.upload.bandwidth)
        pingMilliseconds = result.ping.latency
        serverName = result.server.displayName
    }

    nonisolated private static func runOoklaSpeedTest(
        onEvent: @escaping @Sendable (OoklaSpeedTestEvent) -> Void
    ) async throws -> OoklaSpeedTestResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let parser = JSONLineParser(onEvent: onEvent)
        let errorOutput = ProcessOutputBuffer()

        process.executableURL = try speedtestExecutableURL()
        process.arguments = [
            "--accept-license",
            "--accept-gdpr",
            "--format=jsonl",
            "--progress=yes",
            "--progress-update-interval=750",
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

                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData

                    guard !data.isEmpty else {
                        return
                    }

                    errorOutput.append(data)
                }

                process.terminationHandler = { process in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    parser.finish()

                    guard process.terminationStatus == 0 else {
                        let message = errorOutput.string(fallback: "Speedtest failed")
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
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
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

    nonisolated private static var isSpeedtestInstalled: Bool {
        (try? speedtestExecutableURL()) != nil
    }

    nonisolated private static func installSpeedtestWithHomebrew() async throws {
        let brewURL = try homebrewExecutableURL()

        try await runHomebrewCommand(["tap", "teamookla/speedtest"], brewURL: brewURL)
        try await runHomebrewCommand(["install", "speedtest", "--force"], brewURL: brewURL)
    }

    nonisolated private static func homebrewExecutableURL() throws -> URL {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]

        guard let path = paths.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            throw SpeedTestError.missingHomebrew
        }

        return URL(fileURLWithPath: path)
    }

    nonisolated private static func runHomebrewCommand(_ arguments: [String], brewURL: URL) async throws {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let processOutput = ProcessOutputBuffer()

        process.executableURL = brewURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData

                    guard !data.isEmpty else {
                        return
                    }

                    processOutput.append(data)
                }

                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData

                    guard !data.isEmpty else {
                        return
                    }

                    processOutput.append(data)
                }

                process.terminationHandler = { process in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil

                    guard process.terminationStatus == 0 else {
                        let message = processOutput.string(fallback: "Homebrew install failed")
                        continuation.resume(throwing: SpeedTestError.processFailed(message))
                        return
                    }

                    continuation.resume()
                }

                do {
                    try process.run()
                } catch {
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}

private final class SpeedTestEventRelay: @unchecked Sendable {
    let stream: AsyncStream<OoklaSpeedTestEvent>

    private let lock = NSLock()
    private var continuation: AsyncStream<OoklaSpeedTestEvent>.Continuation?

    init() {
        var continuation: AsyncStream<OoklaSpeedTestEvent>.Continuation?
        stream = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    func yield(_ event: OoklaSpeedTestEvent) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.yield(event)
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        continuation?.finish()
        continuation = nil
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let maxBytes = 64 * 1024

    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }

        data.append(newData)
        if data.count > maxBytes {
            data.removeSubrange(..<(data.count - maxBytes))
        }
    }

    func string(fallback: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        guard let message = String(data: data, encoding: .utf8), !message.isEmpty else {
            return fallback
        }

        return message
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
    case missingHomebrew
    case missingResult
    case processFailed(String)

    var message: String {
        switch self {
        case .missingExecutable:
            "Install the Ookla speedtest CLI."
        case .missingHomebrew:
            "Homebrew not installed."
        case .missingResult:
            "Speedtest finished without a result."
        case .processFailed(let message):
            message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Speedtest failed."
                : message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
