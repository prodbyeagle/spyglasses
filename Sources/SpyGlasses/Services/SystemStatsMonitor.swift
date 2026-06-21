import Combine
import Darwin
import Foundation

@MainActor
final class SystemStatsMonitor: ObservableObject {
    @Published private(set) var stats = SystemStats.empty

    private var refreshTask: Task<Void, Never>?

    init() {
        refreshTask = Task { [weak self] in
            let sampler = SystemStatsSampler()

            while !Task.isCancelled {
                let stats = await sampler.refresh()
                self?.stats = stats

                let interval = UInt64(UpdateIntervalSettings.current * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }
}

private actor SystemStatsSampler {
    private var lastNetworkSample = NetworkSample.current()
    private var lastProcessorSample = ProcessorSample.current()
    private var lastTemperatureSample: TemperatureSample?
    private let temperatureReader = TemperatureReader()
    private let temperatureRefreshInterval: TimeInterval = 5

    func refresh() -> SystemStats {
        let networkSample = NetworkSample.current()
        let processorSample = ProcessorSample.current()
        let temperature = currentTemperature()

        let stats = SystemStats(
            network: throughput(from: networkSample),
            cpuUsage: processorSample.usage(since: lastProcessorSample),
            temperatureCelsius: temperature,
            memory: MemoryStats.current(),
            disk: DiskStats.current(),
            uptime: ProcessInfo.processInfo.systemUptime
        )

        lastNetworkSample = networkSample
        lastProcessorSample = processorSample
        return stats
    }

    private func currentTemperature() -> Double? {
        let now = Date()

        if let lastTemperatureSample,
            now.timeIntervalSince(lastTemperatureSample.timestamp) < temperatureRefreshInterval
        {
            return lastTemperatureSample.value
        }

        let value = temperatureReader.currentTemperatureCelsius()
        lastTemperatureSample = TemperatureSample(value: value, timestamp: now)
        return value
    }

    private func throughput(from sample: NetworkSample) -> NetworkThroughput {
        let interval = max(sample.timestamp.timeIntervalSince(lastNetworkSample.timestamp), 0.1)

        let downloadBytesPerSecond: Double
        if sample.receivedBytes >= lastNetworkSample.receivedBytes {
            downloadBytesPerSecond = Double(sample.receivedBytes - lastNetworkSample.receivedBytes) / interval
        } else {
            downloadBytesPerSecond = 0
        }

        let uploadBytesPerSecond: Double
        if sample.sentBytes >= lastNetworkSample.sentBytes {
            uploadBytesPerSecond = Double(sample.sentBytes - lastNetworkSample.sentBytes) / interval
        } else {
            uploadBytesPerSecond = 0
        }

        return NetworkThroughput(
            downloadBytesPerSecond: downloadBytesPerSecond,
            uploadBytesPerSecond: uploadBytesPerSecond
        )
    }
}

private struct TemperatureSample {
    let value: Double?
    let timestamp: Date
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

private struct ProcessorSample {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    var total: UInt64 {
        user + system + idle + nice
    }

    static func current() -> ProcessorSample {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return ProcessorSample(user: 0, system: 0, idle: 0, nice: 0)
        }

        return ProcessorSample(
            user: UInt64(loadInfo.cpu_ticks.0),
            system: UInt64(loadInfo.cpu_ticks.1),
            idle: UInt64(loadInfo.cpu_ticks.2),
            nice: UInt64(loadInfo.cpu_ticks.3)
        )
    }

    func usage(since previous: ProcessorSample) -> Double? {
        let totalDelta = total >= previous.total ? total - previous.total : 0
        let idleDelta = idle >= previous.idle ? idle - previous.idle : 0

        guard totalDelta > 0, idleDelta <= totalDelta else {
            return nil
        }

        return Double(totalDelta - idleDelta) / Double(totalDelta)
    }
}

private extension MemoryStats {
    static func current() -> MemoryStats {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory

        guard result == KERN_SUCCESS else {
            return MemoryStats(usedBytes: 0, totalBytes: totalBytes)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let usedPages =
            UInt64(stats.active_count)
            + UInt64(stats.inactive_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)

        return MemoryStats(
            usedBytes: min(usedPages * pageSize, totalBytes),
            totalBytes: totalBytes
        )
    }
}

private extension DiskStats {
    static func current() -> DiskStats {
        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
            let freeBytes = attributes[.systemFreeSize] as? NSNumber,
            let totalBytes = attributes[.systemSize] as? NSNumber
        else {
            return DiskStats(freeBytes: 0, totalBytes: 0)
        }

        return DiskStats(
            freeBytes: freeBytes.uint64Value,
            totalBytes: totalBytes.uint64Value
        )
    }
}
