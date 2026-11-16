import Darwin
import Foundation
import IOKit.ps

/// CPU, RAM, ağ, pil ve disk bilgisi. Yalnızca "Sistem" sekmesi görünürken örnekler (enerji tasarrufu).
final class StatsService: ObservableObject {
    @Published private(set) var cpu: Double = 0            // 0...1
    @Published private(set) var memUsed: UInt64 = 0
    let memTotal = ProcessInfo.processInfo.physicalMemory
    @Published private(set) var netDown: Double = 0        // bayt/sn
    @Published private(set) var netUp: Double = 0
    @Published private(set) var downHistory: [Double] = Array(repeating: 0, count: 40)
    @Published private(set) var upHistory: [Double] = Array(repeating: 0, count: 40)
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var diskFree: Int64 = 0
    @Published private(set) var diskTotal: Int64 = 0

    private var timer: Timer?
    private var prevTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var prevNet: [String: (rx: UInt32, tx: UInt32)] = [:]
    private var prevDate: Date?

    func start() {
        guard timer == nil else { return }
        prevTicks = nil
        prevNet = [:]
        prevDate = nil
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()
        sampleBattery()
        sampleDisk()
    }

    // MARK: - CPU

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let t = (user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1),
                 idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
        defer { prevTicks = t }
        guard let p = prevTicks else { return }
        let busy = (t.user &- p.user) + (t.system &- p.system) + (t.nice &- p.nice)
        let total = busy + (t.idle &- p.idle)
        if total > 0 { cpu = Double(busy) / Double(total) }
    }

    // MARK: - RAM

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let page = UInt64(getpagesize())
        // Etkinlik Monitörü'ndeki "Kullanılan Bellek": uygulama + sabit + sıkıştırılmış
        let pages = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
            + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        memUsed = min(pages * page, memTotal)
    }

    // MARK: - Ağ

    private func sampleNetwork() {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return }
        defer { freeifaddrs(head) }

        var down: UInt64 = 0
        var up: UInt64 = 0
        var current: [String: (rx: UInt32, tx: UInt32)] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let ifa = p.pointee
            ptr = ifa.ifa_next
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = ifa.ifa_data else { continue }
            let name = String(cString: ifa.ifa_name)
            guard name.hasPrefix("en") else { continue } // tünel/sanal arayüzler çift saymasın
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            current[name] = (d.ifi_ibytes, d.ifi_obytes)
            if let old = prevNet[name] {
                down += UInt64(d.ifi_ibytes &- old.rx) // 32 bit taşmaya dayanıklı
                up += UInt64(d.ifi_obytes &- old.tx)
            }
        }
        let now = Date()
        if let last = prevDate {
            let dt = max(now.timeIntervalSince(last), 0.1)
            netDown = Double(down) / dt
            netUp = Double(up) / dt
            downHistory = Array((downHistory + [netDown]).suffix(40))
            upHistory = Array((upHistory + [netUp]).suffix(40))
        }
        prevNet = current
        prevDate = now
    }

    // MARK: - Pil

    private func sampleBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            batteryPercent = nil
            return
        }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let cap = desc[kIOPSCurrentCapacityKey] as? Int else { continue }
            batteryPercent = cap
            isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            return
        }
        batteryPercent = nil
    }

    // MARK: - Disk

    private func sampleDisk() {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return }
        diskFree = v.volumeAvailableCapacityForImportantUsage ?? 0
        diskTotal = Int64(v.volumeTotalCapacity ?? 0)
    }

    // MARK: - Biçim

    static func rate(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var i = 0
        while value >= 1000, i < units.count - 1 { value /= 1000; i += 1 }
        return i == 0 ? String(format: "%.0f %@", value, units[i]) : String(format: "%.1f %@", value, units[i])
    }

    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}
