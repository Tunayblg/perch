import AppKit
import CoreBluetooth
import LocalAuthentication

/// Hassasiyet seviyesi. Eşik, masadayken öğrenilen "normal" sinyalin delta dB altında olur;
/// öğrenme yoksa sabit bir yedek eşik kullanılır. Bekleme süresi de otomatik.
enum AwaySensitivity: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }

    /// Normal sinyalden bu kadar dB düşünce "uzakta" sayılır (küçük = daha hassas).
    var delta: Int {
        switch self {
        case .low: return 14
        case .medium: return 9
        case .high: return 5
        }
    }
    /// Masadayken (yazarken) öğrenilen alt sınırın da altına bırakılan pay (dB).
    var margin: Int {
        switch self {
        case .low: return 10
        case .medium: return 6
        case .high: return 3
        }
    }
    /// Normal sinyal henüz öğrenilmediyse kullanılan sabit eşik (dBm).
    var fallbackThreshold: Int {
        switch self {
        case .low: return -78
        case .medium: return -70
        case .high: return -62
        }
    }
    /// "Uzakta" durumu bu kadar saniye sürerse geri sayım başlar.
    var grace: Int {
        switch self {
        case .low: return 12
        case .medium: return 7
        case .high: return 3
        }
    }
    var title: String {
        switch self {
        case .low: return L("Düşük", "Low")
        case .medium: return L("Orta", "Medium")
        case .high: return L("Yüksek", "High")
        }
    }
    var hint: String {
        switch self {
        case .low: return L("Başka odaya geçince", "When you move to another room")
        case .medium: return L("Birkaç metre uzaklaşınca", "When you walk a few meters away")
        case .high: return L("Masadan kalkar kalkmaz", "As soon as you leave the desk")
        }
    }
}

/// Away Guard (beta): seçilen iPhone/Apple Watch'un Bluetooth sinyali zayıflayınca ekranı
/// siyah bir gizlilik ekranıyla örter, yaklaşınca kaldırır. Kamera kullanmaz. Varsayılan KAPALI.
final class AwayGuardService: NSObject, ObservableObject, CBCentralManagerDelegate {
    struct Device: Identifiable, Equatable {
        let id: UUID
        var name: String
        var rssi: Int
        var lastSeen: Date
    }

    struct Sample {
        let time: Date
        let rssi: Int
    }

    enum Phase: Equatable { case present, countdown, covered }
    enum BluetoothStatus { case unknown, ready, off, unauthorized }

    // MARK: - Yayınlanan durum

    @Published var devices: [Device] = []
    @Published var samples: [Sample] = []
    @Published var smoothed: Int?
    @Published var phase: Phase = .present
    @Published var countdown: Int?
    @Published var awayFor = 0
    @Published var bluetooth: BluetoothStatus = .unknown
    @Published var seenSelected = false
    @Published var isTesting = false
    /// Sinyal zayıf ama kullanıcı bilgisayarı kullanıyor: ekran bilerek açık bırakıldı.
    @Published var holdingOff = false
    /// Koruma kapalıyken sinyali elle canlı izleme (kalibrasyon). Panel kapanınca kendiliğinden kapanır.
    @Published var previewing = false
    @Published private(set) var waitingForDeviceSince: Date?

    @Published var selectedID: UUID?
    @Published var selectedName: String

    /// Önizleme görüntüsü üretilirken true: ayarlar kaydedilmez, tarama başlamaz.
    var isPreview = false

    @Published var enabled: Bool {
        didSet {
            guard !isPreview else { return }
            UserDefaults.standard.set(enabled, forKey: "awayEnabled")
            reset()
            refreshScanning()
        }
    }
    @Published var sensitivity: AwaySensitivity {
        didSet {
            guard !isPreview else { return }
            UserDefaults.standard.set(sensitivity.rawValue, forKey: "awaySensitivity")
        }
    }

    /// Masadayken öğrenilen normal sinyal (dBm); cihaz ve yerleşime göre kendiliğinden ayarlanır.
    @Published var baseline: Int?
    private var baselineValue: Double?
    /// Masadayken (klavye/fare aktifken) görülen sinyalin alt sınırı (%10'luk dilim, dBm). Cihaza özeldir:
    /// Apple Watch gibi oynak cihazlarda daha aşağıda çıkar, eşik de ona göre genişler.
    @Published var floor: Int?
    private var floorValue: Double?
    private var activeSamples: [Double] = []

    /// Geçerli eşik: normal sinyalin delta dB altı (öğrenme yoksa yedek değer).
    var threshold: Int {
        let t: Int
        if let f = floor {
            t = f - sensitivity.margin
        } else if let b = baseline {
            t = b - sensitivity.delta
        } else {
            t = sensitivity.fallbackThreshold
        }
        return min(max(t, -95), -45)
    }
    var grace: Int { sensitivity.grace }

    /// Gizlilik ekranında gösterilecek widget'lar için (müzik, zamanlayıcı).
    weak var music: MusicService?
    weak var planner: PlannerService?

    /// Geri sayım başlayınca çağrılır (panelin kendiliğinden açılması için).
    var onCountdownStart: (() -> Void)?
    var onPINRequired: ((@escaping () -> Void) -> Void)?

    // MARK: - Sabitler

    static let countdownSeconds = 3
    private let lostSeconds: TimeInterval = 10      // paket gelmezse "kayıp" sayılır
    private let smoothingWindow: TimeInterval = 6   // uzaklaşma kararı için hareketli ortalama
    private let returnWindow: TimeInterval = 6      // dönüş kararı için daha kısa pencere
    private let historyWindow: TimeInterval = 90
    private let minCoverSeconds: TimeInterval = 1.0 // ekran en az bu kadar kapalı kalır (titremesin)

    // MARK: - İç durum

    private var central: CBCentralManager?
    private var table: [UUID: Device] = [:]
    private var appleSeen = Set<UUID>()
    private var timer: Timer?
    /// Away Guard sekmesi şu an ekranda mı? (tek bir panel olduğu için sayaç değil bayrak: sızıntı olmaz)
    private var viewing = false
    private var tickCount = 0
    private var awaySince: Date?
    private var snoozeUntil = Date.distantPast
    private var coveredAt = Date.distantPast
    private var remaining = 0
    private var testing = false
    private var manualCover = false
    private var returnStreak = 0
    private var authentication: LAContext?
    private let overlay = PrivacyOverlay()

    override init() {
        let d = UserDefaults.standard
        let wasEnabled = d.bool(forKey: "awayEnabled")
        enabled = wasEnabled && AppSettings.shared.hasAwayPassword
        sensitivity = AwaySensitivity(rawValue: d.string(forKey: "awaySensitivity") ?? "") ?? .medium
        selectedID = (d.string(forKey: "awayDeviceID")).flatMap(UUID.init(uuidString:))
        selectedName = d.string(forKey: "awayDeviceName") ?? ""
        super.init()
        baselineValue = selectedID.flatMap { d.object(forKey: "awayBaseline." + $0.uuidString) as? Double }
        baseline = baselineValue.map { Int($0.rounded()) }
        floorValue = selectedID.flatMap { d.object(forKey: "awayFloor." + $0.uuidString) as? Double }
        floor = floorValue.map { Int($0.rounded()) }
        if wasEnabled && !enabled { d.set(false, forKey: "awayEnabled") }
        if enabled { refreshScanning() }
    }

    // MARK: - Panel görünürlüğü (kalibrasyon için sürekli tarama)

    func viewerAppeared() {
        viewing = true
        refreshScanning()
    }

    func viewerDisappeared() {
        viewing = false
        previewing = false
        refreshScanning()
    }

    // MARK: - Cihaz seçimi

    func select(_ device: Device) {
        if selectedID == nil { previewing = false }
        selectedID = device.id
        selectedName = device.name
        UserDefaults.standard.set(device.id.uuidString, forKey: "awayDeviceID")
        UserDefaults.standard.set(device.name, forKey: "awayDeviceName")
        samples.removeAll()
        smoothed = nil
        seenSelected = false
        baselineValue = UserDefaults.standard.object(forKey: "awayBaseline." + device.id.uuidString) as? Double
        baseline = baselineValue.map { Int($0.rounded()) }
        floorValue = UserDefaults.standard.object(forKey: "awayFloor." + device.id.uuidString) as? Double
        floor = floorValue.map { Int($0.rounded()) }
        activeSamples.removeAll()
        reset()
        refreshScanning()
    }

    func cycleDevice(_ direction: Int) {
        guard !devices.isEmpty else { return }
        let current = devices.firstIndex { $0.id == selectedID } ?? (direction > 0 ? -1 : 0)
        let next = (current + direction + devices.count) % devices.count
        select(devices[next])
    }

    // MARK: - Eylemler

    func toggleProtection() {
        if enabled {
            enabled = false
        } else {
            enableProtection()
        }
    }

    private func enableProtection() {
        guard !enabled, selectedID != nil else { return }
        guard AppSettings.shared.hasAwayPassword else {
            onPINRequired? { [weak self] in self?.enableProtection() }
            return
        }
        enabled = true
    }

    /// 3 sn'lik geri sayımla gizlilik ekranını dener; ekran 4 sn sonra kendiliğinden kalkar.
    func testCover() {
        guard phase == .present else { return }
        testing = true
        isTesting = true
        startCountdown(seconds: 3)
    }

    /// Kısayolla (⌃⌥P) elle gizle / göster.
    func toggleManual() {
        if phase != .covered {
            coverManually()
        } else if !AppSettings.shared.hasAwayPassword {
            uncover()
        } else if authentication == nil {
            overlay.focusUnlockWindow()
        }
    }

    func coverManually() {
        guard phase != .covered else { return }
        guard AppSettings.shared.hasAwayPassword else {
            onPINRequired? { [weak self] in self?.coverManually() }
            return
        }
        testing = false
        isTesting = false
        cover(manual: true)
    }

    func cancelCountdown() {
        guard phase == .countdown else { return }
        phase = .present
        countdown = nil
        testing = false
        isTesting = false
        awaySince = nil
        snoozeUntil = Date().addingTimeInterval(60) // iptal sonrası 1 dk rahat bırak
    }

    private func reset() {
        cancelAuthentication()
        if overlay.isShown { music?.endProgress() }
        overlay.hide()
        phase = .present
        countdown = nil
        awayFor = 0
        awaySince = nil
        testing = false
        isTesting = false
        manualCover = false
        returnStreak = 0
        waitingForDeviceSince = nil
        snoozeUntil = Date().addingTimeInterval(10)
    }

    private func startCountdown(seconds: Int) {
        holdingOff = false
        phase = .countdown
        remaining = seconds
        countdown = seconds
        refreshScanning() // panel kapansa bile geri sayım devam etsin
        DispatchQueue.main.async { self.onCountdownStart?() }
    }

    private func cover(manual: Bool) {
        phase = .covered
        countdown = nil
        manualCover = manual
        coveredAt = Date()
        returnStreak = 0
        let settings = AppSettings.shared
        if settings.awayAlsoLock, !testing { ScreenLocker.lock() }
        let verifyPassword: ((String) -> Bool)? = settings.hasAwayPassword ? { [weak self] password in
            self?.unlock(with: password) == true
        } : nil
        let touchIDAvailable = canUseTouchID(LAContext())
        overlay.show(music: music, planner: planner, requiresManualUnlock: manual,
                     verifyPassword: verifyPassword, usesPIN: settings.awayUsesPIN,
                     touchIDAvailable: touchIDAvailable,
                     requestSystemUnlock: { [weak self] action in
                         self?.requestSystemUnlock(preferTouchID: touchIDAvailable, action: action)
                     })
        music?.beginProgress()
        refreshScanning()
    }

    private func uncover(recovered: Bool = false, immediately: Bool = false) {
        cancelAuthentication()
        if overlay.isShown { music?.endProgress() }
        overlay.hide(immediately: immediately)
        phase = .present
        manualCover = false
        testing = false
        isTesting = false
        awaySince = nil
        awayFor = 0
        returnStreak = 0
        if recovered, enabled, selectedID != nil {
            waitingForDeviceSince = Date()
        }
        snoozeUntil = Date().addingTimeInterval(20) // dönüşte hemen tekrar örtülmesin
        refreshScanning()
    }

    @discardableResult
    func unlock(with password: String) -> Bool {
        guard phase == .covered, AppSettings.shared.verifiesAwayPassword(password) else { return false }
        uncover(recovered: true)
        return true
    }

    private func canUseTouchID(_ context: LAContext) -> Bool {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            && context.biometryType == .touchID
    }

    private func requestSystemUnlock(preferTouchID: Bool, action: OverlayUnlockAction) {
        guard phase == .covered, authentication == nil else { return }
        let context = LAContext()
        let useTouchID = preferTouchID && canUseTouchID(context)
        let policy: LAPolicy = useTouchID ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: nil) else {
            overlay.setAuthenticating(false, failed: true)
            return
        }
        if useTouchID { context.localizedFallbackTitle = L("Mac parolasını kullan", "Use Mac password") }
        authentication = context
        overlay.setAuthenticating(true)
        let reason: String
        switch action {
        case .reveal:
            reason = L("Perch’ün gizlilik ekranını aç", "Reveal the screen behind Perch")
        case .setUpPIN:
            reason = L("Away Guard için PIN belirle", "Set up an Away Guard PIN")
        }
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, error in
            let failure = (error as? LAError)?.code
            DispatchQueue.main.async {
                guard let self, self.authentication === context else { return }
                self.authentication = nil
                if success {
                    self.uncover(recovered: true, immediately: true)
                    if action == .setUpPIN {
                        NotificationCenter.default.post(name: .openAwayGuardPassword, object: nil)
                    }
                } else if useTouchID, failure == .userFallback || failure == .biometryLockout
                            || failure == .biometryNotAvailable || failure == .biometryNotEnrolled {
                    self.requestSystemUnlock(preferTouchID: false, action: action)
                } else {
                    self.overlay.setAuthenticating(false, failed: failure != .userCancel)
                }
            }
        }
    }

    private func cancelAuthentication() {
        let context = authentication
        authentication = nil
        context?.invalidate()
    }

    // MARK: - Tarama (enerji dostu)

    private var wantsScanning: Bool { enabled || (viewing && previewing) }

    // Test geri sayımı ve test örtüsünün süresi Bluetooth olmadan da ilerler.
    private var wantsTicks: Bool { wantsScanning || phase == .countdown || testing }

    /// Panel kapanınca çağrılır: önizleme ve görünürlük bayrakları sıfırlanır, tarama gerekmiyorsa durur.
    func panelClosed() { viewerDisappeared() }

    func setPreview(_ on: Bool) {
        previewing = on
        refreshScanning()
    }

    private func refreshScanning() {
        if wantsScanning {
            if central == nil { central = CBCentralManager(delegate: self, queue: nil) }
            applyScanDuty()
        } else {
            central?.stopScan()
        }
        if wantsTicks {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
                timer?.tolerance = 0.2
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    /// Sekme açıkken (grafik) her saniye taze örnek; arkada ise 4 sn'de bir 2 sn'lik tarama patlaması.
    private func applyScanDuty() {
        guard wantsScanning, let central, central.state == .poweredOn else { return }
        let continuous = viewing || phase != .present
        let slot = tickCount % 2
        if continuous || slot == 0 {
            if continuous || slot == 0 || !central.isScanning {
                central.stopScan() // yeniden başlatmak her cihaz için taze RSSI getirir
                central.scanForPeripherals(withServices: nil,
                                           options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            }
        } else if central.isScanning {
            central.stopScan()
        }
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn: bluetooth = .ready; applyScanDuty()
        case .poweredOff: bluetooth = .off
        case .unauthorized: bluetooth = .unauthorized
        default: bluetooth = .unknown
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData ad: [String: Any], rssi: NSNumber) {
        let value = rssi.intValue
        guard value < 0, value != 127 else { return } // 127 = ölçülemedi
        let id = p.identifier
        if let m = ad[CBAdvertisementDataManufacturerDataKey] as? Data, m.count >= 2, m[0] == 0x4C, m[1] == 0x00 {
            appleSeen.insert(id)
        }
        let name = p.name ?? (ad[CBAdvertisementDataLocalNameKey] as? String) ?? table[id]?.name ?? ""
        let now = Date()
        table[id] = Device(id: id, name: name, rssi: value, lastSeen: now)
        if id == selectedID {
            samples.append(Sample(time: now, rssi: value))
            seenSelected = true
            if phase == .present, ScreenLocker.idleSeconds() < 2 {   // yazıyor/fare kullanıyor = kesin masada
                activeSamples.append(Double(value))
                if activeSamples.count > 400 { activeSamples.removeFirst(activeSamples.count - 400) }
            }
        }
    }

    /// Uzakta mı? Tek tük düşüş sayılmaz: pencere içindeki TÜM örnekler eşiğin altında olmalı.
    /// Paket gelmemesi tek başına yetmez (telefon uykuya girmiş olabilir): son sinyal zayıfsa kısa,
    /// iyiyse uzun süre beklenir.
    private func isAway(_ now: Date) -> Bool {
        guard seenSelected, let id = selectedID else { return false }
        let recent = samples.filter { now.timeIntervalSince($0.time) <= smoothingWindow }
        if let best = recent.map(\.rssi).max() { return best < threshold }
        guard let d = table[id] else { return true }
        let silent = now.timeIntervalSince(d.lastSeen)
        return d.rssi < threshold ? silent > lostSeconds : silent > 3 * lostSeconds
    }

    // MARK: - Saniyelik değerlendirme

    private func tick() {
        let now = Date()
        tickCount += 1
        applyScanDuty()

        // Aday cihaz listesi: adı çözülmüş Apple cihazları (iPhone, Watch, iPad, Mac)
        let list = table.values
            .filter { !$0.name.isEmpty && appleSeen.contains($0.id) && now.timeIntervalSince($0.lastSeen) < 60 }
            .sorted { $0.rssi > $1.rssi }
        if list != devices { devices = list }

        // Kimlik değiştiyse aynı adlı cihaza yeniden bağlan
        if let id = selectedID, table[id] == nil, !selectedName.isEmpty,
           let same = list.first(where: { $0.name == selectedName }) {
            selectedID = same.id
            UserDefaults.standard.set(same.id.uuidString, forKey: "awayDeviceID")
        }

        samples.removeAll { now.timeIntervalSince($0.time) > historyWindow }
        let recent = samples.filter { now.timeIntervalSince($0.time) <= smoothingWindow }
        let newSmoothed = recent.isEmpty ? nil : recent.map(\.rssi).reduce(0, +) / recent.count
        if newSmoothed != smoothed { smoothed = newSmoothed }

        // Masada çalışırken (klavye/fare aktif) sinyali öğren: ortalama = normal, %10'luk dilim = alt sınır.
        if phase == .present, selectedID != nil, activeSamples.count >= 30 {
            let sorted = activeSamples.sorted()
            let p10 = sorted[Int(Double(sorted.count - 1) * 0.10)]
            let mean = activeSamples.reduce(0, +) / Double(activeSamples.count)
            let rate = floorValue == nil ? 1.0 : 0.1
            floorValue = floorValue.map { $0 * (1 - rate) + p10 * rate } ?? p10
            baselineValue = baselineValue.map { $0 * (1 - rate) + mean * rate } ?? mean
            let f = Int(floorValue!.rounded()), bl = Int(baselineValue!.rounded())
            if f != floor { floor = f }
            if bl != baseline { baseline = bl }
            activeSamples.removeAll(keepingCapacity: true)
        }
        if tickCount % 60 == 0, let id = selectedID {
            if let v = baselineValue { UserDefaults.standard.set(v, forKey: "awayBaseline." + id.uuidString) }
            if let v = floorValue { UserDefaults.standard.set(v, forKey: "awayFloor." + id.uuidString) }
        }

        guard selectedID != nil || phase != .present else { return }
        let lastSeen = selectedID.flatMap { table[$0]?.lastSeen }

        switch phase {
        case .present:
            guard enabled, selectedID != nil else { return }
            if let since = waitingForDeviceSince {
                guard let last = samples.last, last.time >= since,
                      now.timeIntervalSince(last.time) < 4, last.rssi >= threshold + 2 else { return }
                waitingForDeviceSince = nil
            }
            let away = isAway(now)                           // cihaz hiç görülmediyse örtme
            let userActive = ScreenLocker.userIsEngaged(threshold: 5) // klavye/fare/video: kullanıyor
            let hold = away && userActive
            if hold != holdingOff { holdingOff = hold }
            if away, !userActive, now >= snoozeUntil {
                awaySince = awaySince ?? now
                awayFor = Int(now.timeIntervalSince(awaySince!))
                if awayFor >= grace { startCountdown(seconds: Self.countdownSeconds) }
            } else if awaySince != nil {
                awaySince = nil
                awayFor = 0
            }

        case .countdown:
            let away = isAway(now)
            let userActive = ScreenLocker.userIsEngaged(threshold: 3)
            if !testing, !away || userActive {
                cancelCountdown()
                return
            }
            remaining -= 1
            countdown = max(remaining, 0)
            if remaining <= 0 { cover(manual: false) }

        case .covered:
            if testing {
                if now.timeIntervalSince(coveredAt) > 4 { uncover() }
                return
            }
            guard !manualCover else { return } // elle gizlendiyse yalnızca kısayol açar
            // Dönüş (bekletmeden): son taze örnek eşiğin açıkça üstündeyse hemen aç
            if let last = samples.last, now.timeIntervalSince(last.time) < 4,
               last.rssi >= threshold + 2, now.timeIntervalSince(coveredAt) > minCoverSeconds {
                uncover()
            }
        }
    }
}
