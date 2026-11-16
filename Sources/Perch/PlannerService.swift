import AppKit
import UserNotifications

/// Zamanlayıcılar ve Pomodoro. Tüm geri sayımlar bitiş tarihine göre hesaplanır,
/// bu yüzden saniye kaçsa bile süre kayması olmaz.
final class PlannerService: ObservableObject {
    struct CountdownTimer: Identifiable {
        let id = UUID()
        let total: TimeInterval
        let endDate: Date
    }

    enum Phase {
        case idle, work, rest

        var title: String {
            switch self {
            case .idle: return "Pomodoro"
            case .work: return L("Odak", "Focus")
            case .rest: return L("Mola", "Break")
            }
        }
    }

    @Published var timers: [CountdownTimer] = []
    @Published var phase: Phase = .idle
    @Published var phaseEnd: Date?
    @Published var completedPomodoros = 0
    @Published var now = Date()

    var workDuration: TimeInterval { TimeInterval(AppSettings.shared.workMinutes * 60) }
    var restDuration: TimeInterval { TimeInterval(AppSettings.shared.restMinutes * 60) }

    /// Bir süre bittiğinde çağrılır (panel genişleyip uyarsın diye).
    var onAlert: (() -> Void)?

    private var ticker: Timer?
    private let notificationDelegate = ForegroundNotificationDelegate()

    func start() {
        if Bundle.main.bundleURL.pathExtension == "app" {
            let center = UNUserNotificationCenter.current()
            center.delegate = notificationDelegate
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Saat yalnızca bir zamanlayıcı ya da Pomodoro çalışırken döner (boştayken işlemciyi uyandırmaz).
    private func ensureTicker() {
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        ticker?.tolerance = 0.15
    }

    // MARK: - Eylemler

    func addTimer(minutes: Int) {
        let total = TimeInterval(minutes * 60)
        timers.append(CountdownTimer(total: total, endDate: Date().addingTimeInterval(total)))
        ensureTicker()
    }

    func removeTimer(_ id: UUID) {
        timers.removeAll { $0.id == id }
    }

    func togglePomodoro() {
        if phase == .idle {
            phase = .work
            phaseEnd = Date().addingTimeInterval(workDuration)
            ensureTicker()
        } else {
            phase = .idle
            phaseEnd = nil
        }
    }

    // MARK: - Durum

    func remaining(until date: Date) -> TimeInterval {
        max(date.timeIntervalSince(now), 0)
    }

    var pomodoroRemaining: TimeInterval {
        guard let end = phaseEnd else { return workDuration }
        return remaining(until: end)
    }

    var isActive: Bool { !timers.isEmpty || phase != .idle }

    /// Kapalı çentikte gösterilecek rozet: bitmesine en yakın geri sayım.
    var badge: (icon: String, text: String)? {
        var best: (icon: String, left: TimeInterval)?
        if phase != .idle, let end = phaseEnd {
            best = (phase == .work ? "flame.fill" : "cup.and.saucer.fill", remaining(until: end))
        }
        for t in timers {
            let left = remaining(until: t.endDate)
            if best == nil || left < best!.left { best = ("timer", left) }
        }
        guard let best else { return nil }
        return (best.icon, Self.format(best.left))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let t = Int(seconds.rounded(.up))
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60) }
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    // MARK: - Saat

    private func tick() {
        let current = Date()
        if Int(current.timeIntervalSince1970) != Int(now.timeIntervalSince1970) {
            now = current
        }

        let finished = timers.filter { $0.endDate <= current }
        if !finished.isEmpty {
            timers.removeAll { $0.endDate <= current }
            for t in finished {
                let m = Int(t.total / 60)
                alert(title: L("Zamanlayıcı bitti", "Timer finished"), body: L("\(m) dakika doldu.", "\(m) minutes are up."))
            }
        }

        if phase != .idle, let end = phaseEnd, end <= current {
            switch phase {
            case .work:
                completedPomodoros += 1
                phase = .rest
                phaseEnd = current.addingTimeInterval(restDuration)
                let r = AppSettings.shared.restMinutes
                alert(title: L("Mola zamanı", "Break time"), body: L("\(completedPomodoros). pomodoro tamam. \(r) dakika dinlen.", "Pomodoro #\(completedPomodoros) done. Rest for \(r) minutes."))
            case .rest:
                phase = .work
                phaseEnd = current.addingTimeInterval(workDuration)
                alert(title: L("Odaklanma zamanı", "Focus time"), body: L("Mola bitti, yeni pomodoro başladı.", "Break is over, a new pomodoro has started."))
            case .idle:
                break
            }
        }
        stopTickerIfIdle()
    }

    private func stopTickerIfIdle() {
        if timers.isEmpty, phase == .idle {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func alert(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        if Bundle.main.bundleURL.pathExtension == "app" {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
        DispatchQueue.main.async { self.onAlert?() }
    }
}

/// Uygulama ön plandayken de bildirim banner'ı gösterir.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
