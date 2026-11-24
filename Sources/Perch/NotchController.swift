import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Yazı yazılabilen ama uygulamayı öne çıkarmayan panel.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Panelin açık/kapalı durumu ve ölçüleri. SwiftUI bunu gözlemler.
final class NotchState: ObservableObject {
    @Published var expanded = false
    @Published var showsBadge = false
    @Published var tab: NotchTab = .music
    /// Sekme geçişinde içeriğin kayma yönü (+1: sağa doğru ilerliyor, -1: geri).
    @Published var tabDirection: CGFloat = 1

    /// Sekme değiştirir; panel açıksa yönlü kaydırma animasyonuyla.
    func select(_ new: NotchTab) {
        let tabs = AppSettings.shared.visibleTabs
        let current = tabs.contains(tab) ? tab : (tabs.first ?? .settings)
        guard new != current else { return }
        guard expanded else { tab = new; return }
        let a = tabs.firstIndex(of: current) ?? 0
        let b = tabs.firstIndex(of: new) ?? 0
        tabDirection = b > a ? 1 : -1
        // Yön, çıkan görünümün geçişine ulaşsın diye bir sonraki turda değiştir
        DispatchQueue.main.async { withAnimation(.smooth(duration: 0.32)) { self.tab = new } }
    }

    /// Fiziksel çentik (ya da çentiksiz Mac'te kapsül) ölçüsü.
    var notchSize = CGSize(width: 200, height: 32)
    /// Aktif geri sayım varken çentiğin iki yanına eklenen genişlik.
    let badgeWidth: CGFloat = 64
    /// Genişlik, görünen sekme sayısına göre iki yandan simetrik büyür/küçülür.
    var expandedSize: CGSize {
        let count = AppSettings.shared.visibleTabs.count
        let side = max((count + 1) / 2, 1) // bir yandaki en çok düğme
        let sideWidth = CGFloat(side) * 26 + CGFloat(side - 1) * 2 + 14 + 6
        let headerNeeds = notchSize.width + 12 + sideWidth * 2
        return CGSize(width: max(headerNeeds, 400), height: 176)
    }
    var hasNotch = true

    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + (showsBadge ? badgeWidth * 2 : 0), height: notchSize.height)
    }
}

/// Çentiğin üstünde duran şeffaf paneli yönetir; fare çentiğe gelince açar.
final class NotchController {
    let state = NotchState()
    let music = MusicService()
    let planner = PlannerService()
    let todos = TodoStore()
    let shelf = ShelfStore()
    let voice = VoiceNoteService()
    let stats = StatsService()
    let clipboard = ClipboardService()
    let ai = AIStatusService()
    let awayGuard = AwayGuardService()
    private var hotKey: GlobalHotKey?
    private var privacyHotKey: GlobalHotKey?

    private var panel: NSPanel!
    private var screen: NSScreen!
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var collapseWork: DispatchWorkItem?
    private var pinnedUntil = Date.distantPast
    private var scrollMonitor: Any?
    private var swipeAccum: CGFloat = 0
    private var swipeFired = false
    private var cancellables = Set<AnyCancellable>()

    func start() {
        screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        measureNotch()

        panel = NotchPanel(
            contentRect: frame(expanded: false),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false

        let host = NSHostingView(rootView: NotchView(state: state, music: music, planner: planner, todos: todos, shelf: shelf, voice: voice, stats: stats, clipboard: clipboard, awayGuard: awayGuard, ai: ai))
        host.layer?.backgroundColor = .clear
        panel.contentView = host
        panel.orderFrontRegardless()

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.mouseChanged(dragging: event.type == .leftMouseDragged)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.mouseChanged(dragging: event.type == .leftMouseDragged)
            return event
        }

        // İki parmakla sağa/sola kaydırınca sekme değiştir
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }

        // Sekme gizlenince/sıra değişince panel genişliğini güncelle
        AppSettings.shared.$hiddenTabs.map { _ in () }
            .merge(with: AppSettings.shared.$tabOrder.map { _ in () })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.resizeForTabs() }
            .store(in: &cancellables)

        // Geri sayım varken kapalı çentik iki yana genişleyip süreyi gösterir.
        planner.$timers.combineLatest(planner.$phase, music.$isPlaying, voice.$isRecording)
            .map { !$0.isEmpty || $1 != .idle || $2 || $3 }
            .combineLatest(awayGuard.$countdown.map { $0 != nil })
            .map { $0 || $1 }
            .combineLatest(ai.$state.map { $0 != .idle })
            .map { $0 || $1 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.setBadge(active) }
            .store(in: &cancellables)

        // Panel anahtar pencere olmaktan çıkınca (başka yere tıklandı) yazma odağını bırak.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            self?.panel.makeFirstResponder(nil)
        }

        // ⌃⌥N: sesli notu başlat/durdur (her yerden)
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            guard let self else { return }
            if !self.voice.isRecording { self.state.select(.voice) }
            self.voice.toggle()
        }

        // ⌃⌥P: ekranı elle gizle / göster (Away Guard için acil çıkış de budur)
        privacyHotKey = GlobalHotKey(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey) { [weak self] in
            self?.awayGuard.toggleManual()
        }

        planner.onAlert = { [weak self] in self?.flash() }
        // Away Guard geri sayımı başlayınca panel kendiliğinden açılır (iptal edebilmen için)
        awayGuard.music = music
        awayGuard.planner = planner
        awayGuard.onCountdownStart = { [weak self] in self?.flash(.awayGuard, hold: Double(AwayGuardService.countdownSeconds) + 2) }

        music.start()
        clipboard.start()
        planner.start()
    }

    // MARK: - Ölçüler

    private func measureNotch() {
        let inset = screen.safeAreaInsets.top
        if inset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            state.hasNotch = true
            state.notchSize = CGSize(
                width: screen.frame.width - left.width - right.width,
                height: inset
            )
        } else {
            // Çentiksiz Mac: yüzen küçük kapsül
            state.hasNotch = false
            state.notchSize = CGSize(width: 180, height: 26)
        }
    }

    private func frame(expanded: Bool) -> NSRect {
        let size = expanded ? state.expandedSize : state.collapsedSize
        let f = screen.frame
        return NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
    }

    private func setBadge(_ active: Bool) {
        guard state.showsBadge != active else { return }
        state.showsBadge = active
        guard !state.expanded else { return }
        // Büyürken pencere hemen genişler; küçülürken animasyon bitince daralır.
        let delay: TimeInterval = active ? 0 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.state.expanded else { return }
            self.panel.setFrame(self.frame(expanded: false), display: true)
        }
    }

    // MARK: - Sekmeler

    private var effectiveTab: NotchTab {
        let tabs = AppSettings.shared.visibleTabs
        return tabs.contains(state.tab) ? state.tab : (tabs.first ?? .settings)
    }

    private func cycleTab(_ direction: Int) {
        let tabs = AppSettings.shared.visibleTabs
        guard let i = tabs.firstIndex(of: effectiveTab) else { return }
        let j = min(max(i + direction, 0), tabs.count - 1)
        if j != i { state.select(tabs[j]) }
    }

    private func handleScroll(_ e: NSEvent) {
        guard state.expanded, e.window === panel else { return }
        guard abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) else { return }

        // Rafta dosya varken içerik kendi yatay kaydırmasını kullanır; orada sadece üst şeritte sekme değiştir
        let inHeader = e.locationInWindow.y > panel.frame.height - state.notchSize.height
        if effectiveTab == .shelf, !shelf.items.isEmpty, !inHeader { return }

        let isGesture = e.phase != [] || e.momentumPhase != []
        if e.phase.contains(.began) || e.phase.contains(.mayBegin) { swipeAccum = 0; swipeFired = false }

        // Parmak hareketine göre yön: sola kaydır → sonraki sekme
        let dx = e.isDirectionInvertedFromDevice ? e.scrollingDeltaX : -e.scrollingDeltaX
        if !isGesture {
            if abs(dx) > 0 { cycleTab(dx < 0 ? 1 : -1) }
            return
        }
        if !swipeFired {
            swipeAccum += dx
            if abs(swipeAccum) > 30 {
                swipeFired = true
                cycleTab(swipeAccum < 0 ? 1 : -1)
            }
        }
        if e.phase.contains(.ended) || e.phase.contains(.cancelled) || e.momentumPhase.contains(.ended) {
            swipeAccum = 0
            swipeFired = false
        }
    }

    /// Genişlik değişince pencereyi uydur (büyürken hemen, küçülürken animasyondan sonra).
    private func resizeForTabs() {
        guard state.expanded else { return }
        let target = frame(expanded: true)
        let growing = target.width > panel.frame.width
        DispatchQueue.main.asyncAfter(deadline: .now() + (growing ? 0 : 0.4)) { [weak self] in
            guard let self, self.state.expanded else { return }
            self.panel.setFrame(self.frame(expanded: true), display: true)
        }
    }

    // MARK: - Fare takibi

    /// Sürükleme sırasında panoda dosya var mı?
    private var dragHasFiles: Bool {
        NSPasteboard(name: .drag).types?.contains(.fileURL) ?? false
    }

    private func mouseChanged(dragging: Bool = false) {
        let p = NSEvent.mouseLocation
        if state.expanded {
            if Date() < pinnedUntil { return }
            // Sürüklerken (içeri ya da dışarı) panel kapanmasın; fare bırakılıp oynayınca kapanır
            if dragging {
                collapseWork?.cancel()
                collapseWork = nil
                return
            }
            // Yazı yazarken panel açık kalsın
            if panel.isKeyWindow, panel.firstResponder is NSTextView { return }
            let keep = frame(expanded: true).insetBy(dx: -12, dy: -12)
            if keep.contains(p) {
                collapseWork?.cancel()
                collapseWork = nil
            } else {
                scheduleCollapse()
            }
        } else {
            // Kapalıyken: çentikten uzaktaysa hemen çık (çoğu fare hareketi burada biter)
            if !dragging, p.y < screen.frame.maxY - state.collapsedSize.height - 12 { return }
            // çentiğin hemen üstü/çevresi tetikler
            var trigger = frame(expanded: false).insetBy(dx: -8, dy: -4)
            trigger.size.height += 20 // ekran kenarına kadar
            if trigger.contains(p) {
                if dragging {
                    // Sadece dosya sürüklerken aç; pencere/metin sürüklemesi tetiklemesin
                    guard dragHasFiles else { return }
                    state.select(.shelf)
                }
                setExpanded(true)
            }
        }
    }

    /// Süre bitince panel kendiliğinden açılıp zamanlayıcı sekmesini gösterir.
    private func flash(_ tab: NotchTab = .timer, hold: TimeInterval = 6) {
        state.select(tab)
        pinnedUntil = Date().addingTimeInterval(hold)
        setExpanded(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + hold + 0.2) { [weak self] in
            self?.mouseChanged()
        }
    }

    private func scheduleCollapse() {
        guard collapseWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.collapseWork = nil
            self?.setExpanded(false)
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func setExpanded(_ value: Bool) {
        collapseWork?.cancel()
        collapseWork = nil
        guard state.expanded != value else { return }
        if value {
            panel.setFrame(frame(expanded: true), display: true)
            state.expanded = true
            music.beginProgress()
        } else {
            panel.makeFirstResponder(nil)
            state.expanded = false
            music.endProgress()
            awayGuard.panelClosed()
            // Animasyon bitince pencereyi küçült ki altındaki tıklamaları engellemesin
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, !self.state.expanded else { return }
                self.panel.setFrame(self.frame(expanded: false), display: true)
            }
        }
    }
}
