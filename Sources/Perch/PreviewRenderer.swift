import AppKit
import SwiftUI

/// README görüntülerini üretir: `Perch --render-previews docs/screenshots`
/// Arayüz kodunun kendisini ÖRNEK verilerle çizer (kişisel veri yok, kullanıcı ayarlarına dokunulmaz).
enum PreviewRenderer {
    @MainActor
    static func run(outputDir: String) {
        let root = URL(fileURLWithPath: outputDir, isDirectory: true)
        let settings = AppSettings.shared
        settings.accentOverride = .blue
        settings.tabsOverride = [.music, .timer, .voice, .todo, .stats, .awayGuard, .settings]

        for (folder, lang) in [("en", AppLanguage.en), ("tr", AppLanguage.tr)] {
            settings.languageOverride = lang
            let dir = root.appendingPathComponent(folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            for (tab, name) in [(NotchTab.music, "music"), (.timer, "timer"), (.stats, "system"),
                                (.awayGuard, "away-guard"), (.settings, "settings")] {
                save(notch(tab: tab), size: CGSize(width: 760, height: 250), name: name, dir: dir)
            }
            save(privacyScreen(), size: CGSize(width: 1440, height: 900), name: "privacy-screen", dir: dir, scale: 1)
            print("✓ \(folder)")
        }
    }

    // MARK: - Örnek veriler

    @MainActor
    private static func sampleMusic() -> MusicService {
        let m = MusicService()
        m.hasTrack = true
        m.isPlaying = true
        m.title = "Midnight City"
        m.artist = "M83"
        m.position = 83
        m.duration = 244
        m.sourceName = "Spotify"
        return m
    }

    @MainActor
    private static func samplePlanner() -> PlannerService {
        let p = PlannerService()
        p.addTimer(minutes: 10)
        p.togglePomodoro()
        p.completedPomodoros = 3
        return p
    }

    @MainActor
    private static func sampleAway() -> AwayGuardService {
        let a = AwayGuardService()
        a.isPreview = true
        let watch = AwayGuardService.Device(id: UUID(), name: "Apple Watch", rssi: -52, lastSeen: Date())
        let phone = AwayGuardService.Device(id: UUID(), name: "iPhone", rssi: -61, lastSeen: Date())
        a.devices = [watch, phone]
        a.selectedID = watch.id
        a.selectedName = watch.name
        a.bluetooth = .ready
        a.enabled = true
        a.baseline = -52
        a.seenSelected = true
        // Örnek eğri: masada sabit, bir süre uzaklaşma, dönüş
        let now = Date()
        a.samples = (0...60).map { i in
            let t = Double(i)
            var v = -52 + sin(t * 0.9) * 2 + sin(t * 0.37) * 1.5
            if i > 18 && i < 40 { v -= 26 * sin(Double(i - 18) / 22 * .pi) }
            return AwayGuardService.Sample(time: now.addingTimeInterval(Double(i) - 60), rssi: Int(v.rounded()))
        }
        a.smoothed = -53
        return a
    }

    // MARK: - Görünümler

    @MainActor
    private static func notch(tab: NotchTab) -> some View {
        let state = NotchState()
        state.notchSize = CGSize(width: 190, height: 32)
        state.expanded = true
        state.tab = tab
        let stats = StatsService()
        stats.isPreview = true
        stats.cpu = 0.23
        stats.memUsed = UInt64(Double(stats.memTotal) * 0.52)
        stats.netDown = 2_400_000
        stats.netUp = 180_000
        var down: [Double] = []
        var up: [Double] = []
        for i in 0..<40 {
            let t = Double(i)
            let d1: Double = 900_000 * sin(t * 0.42)
            let d2: Double = 300_000 * sin(t * 1.3)
            let u1: Double = 70_000 * sin(t * 0.55 + 1)
            let u2: Double = 30_000 * sin(t * 1.7)
            down.append(1_600_000 + d1 + d2)
            up.append(160_000 + u1 + u2)
        }
        stats.downHistory = down
        stats.upHistory = up
        stats.batteryPercent = 82
        stats.isCharging = true
        stats.diskFree = 312_000_000_000
        stats.diskTotal = 494_000_000_000
        let view = NotchView(state: state, music: sampleMusic(), planner: samplePlanner(), todos: TodoStore(),
                             shelf: ShelfStore(), voice: VoiceNoteService(), stats: stats,
                             clipboard: ClipboardService(), awayGuard: sampleAway())
        return Desktop { view.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) }
    }

    @MainActor
    private static func privacyScreen() -> some View {
        let model = OverlayModel()
        model.shown = true
        model.music = sampleMusic()
        model.planner = samplePlanner()
        return OverlayContent(model: model)
    }

    @MainActor
    private static func save<V: View>(_ view: V, size: CGSize, name: String, dir: URL, scale: CGFloat = 2) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("✗ \(name): görüntü üretilemedi")
            return
        }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

/// Masaüstü duvar kâğıdı gibi bir zemin; çentik paneli ekranın üstüne yapışık durur.
private struct Desktop<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.10, green: 0.09, blue: 0.30),
                                    Color(red: 0.36, green: 0.16, blue: 0.52),
                                    Color(red: 0.12, green: 0.34, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color(red: 1, green: 0.5, blue: 0.7).opacity(0.25)).frame(width: 420).blur(radius: 70).offset(x: 250, y: 120)
            Circle().fill(Color(red: 0.3, green: 0.8, blue: 1).opacity(0.22)).frame(width: 380).blur(radius: 70).offset(x: -260, y: 150)
            Rectangle().fill(Color.black.opacity(0.28)).frame(height: 28).frame(maxHeight: .infinity, alignment: .top)
            content
        }
    }
}
