import AppKit
import SwiftUI

/// Klavye girdisini yutan, tam ekran pencere.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

/// Giriş/çıkış animasyonlarını sürer. Ekran kapalıyken hiçbir animasyon çalışmaz (pil dostu).
final class OverlayModel: ObservableObject {
    @Published var shown = false
    @Published var vanishing = false
    var music: MusicService?
    var planner: PlannerService?
}

/// Gizlilik ekranı: tüm ekranları örter; yaklaşınca kenarlardan buharlaşarak açılır ve önceki
/// uygulama kaldığı yerden devam eder. Not: Bu gerçek bir kilit DEĞİL, yalnızca ekranı gizler.
final class PrivacyOverlay {
    private var windows: [NSWindow] = []
    private var model: OverlayModel?
    private var previousApp: NSRunningApplication?

    var isShown: Bool { !windows.isEmpty }

    func show(music: MusicService? = nil, planner: PlannerService? = nil) {
        guard windows.isEmpty else { return }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = (front?.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : front

        let model = OverlayModel()
        model.music = music
        model.planner = planner
        self.model = model
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false, screen: screen)
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.contentView = NSHostingView(rootView: OverlayContent(model: model))
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
        }
        // Klavye girdisi arkadaki uygulamaya gitmesin diye odağı biz alırız
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        DispatchQueue.main.async { model.shown = true } // giriş animasyonu bir sonraki turda başlar
    }

    func hide() {
        guard !windows.isEmpty, let model else { return }
        let old = windows
        windows = []
        self.model = nil
        // Hemen kullanılabilir olsun: fare/klavye artık altındaki uygulamaya gider
        old.forEach { $0.ignoresMouseEvents = true }
        previousApp?.activate()
        previousApp = nil
        model.vanishing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { old.forEach { $0.orderOut(nil) } }
    }
}

struct OverlayContent: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        GeometryReader { geo in
            let diag = hypot(geo.size.width, geo.size.height)
            ZStack {
                backdrop
                    // Kapanırken kara örtü kenarlardan merkeze doğru çekilir (buharlaşma)
                    .mask {
                        Circle().fill(Color.black)
                            .frame(width: model.vanishing ? 0 : diag * 1.3, height: model.vanishing ? 0 : diag * 1.3)
                            .blur(radius: 90)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .animation(.timingCurve(0.35, 0, 0.7, 1, duration: 0.85), value: model.vanishing)
                    }
                    .opacity(model.shown ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: model.shown)

                content
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        // Tarih/saat biçimi uygulamanın seçili diline uysun (sistem diline değil)
        .environment(\.locale, Locale(identifier: AppSettings.shared.isTurkish ? "tr_TR" : "en_US"))
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.012, green: 0.012, blue: 0.035),
                                    Color(red: 0.05, green: 0.04, blue: 0.11)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.36, green: 0.30, blue: 0.92).opacity(0.20), .clear],
                           center: .center, startRadius: 0, endRadius: 560)
        }
    }

    private var content: some View {
        VStack(spacing: 30) {
            bird

            TimelineView(.everyMinute) { ctx in
                VStack(spacing: 4) {
                    Text(ctx.date, format: .dateTime.hour().minute())
                        .font(.system(size: 92, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                    Text(ctx.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if let music = model.music, let planner = model.planner {
                OverlayWidgets(music: music, planner: planner)
            }

            VStack(spacing: 6) {
                Text(L("Perch nöbette", "Perch is on watch"))
                    .font(.system(size: 17, weight: .medium))
                Text(L("Geri döndüğünde ekran kendiliğinden açılır", "Your screen reopens the moment you're back"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .foregroundStyle(.white)
        // Girişte bulanıktan netleşir, çıkışta buhar gibi dağılıp yükselir
        .blur(radius: model.vanishing ? 26 : (model.shown ? 0 : 14))
        .scaleEffect(model.vanishing ? 1.2 : (model.shown ? 1 : 0.94))
        .offset(y: model.vanishing ? -50 : 0)
        .opacity(model.vanishing ? 0 : (model.shown ? 1 : 0))
        .animation(.smooth(duration: 0.6), value: model.shown)
        .animation(.easeIn(duration: 0.6), value: model.vanishing)
    }

    /// Dala konmuş kuş: girişte zıplayarak konar, çıkışta uçup gider.
    private var bird: some View {
        VStack(spacing: 5) {
            Image(systemName: "bird.fill")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.72, green: 0.76, blue: 1)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 0.5, green: 0.5, blue: 1).opacity(0.65), radius: 22)
            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 96, height: 3)
        }
        .offset(y: model.vanishing ? -320 : (model.shown ? 0 : -90))
        .rotationEffect(.degrees(model.vanishing ? -16 : 0))
        .animation(.spring(response: 0.75, dampingFraction: 0.5), value: model.shown)
        .animation(.easeIn(duration: 0.7), value: model.vanishing)
    }
}

/// Gizlilik ekranındaki widget'lar: çalan müzik ve çalışan zamanlayıcı/Pomodoro.
private struct OverlayWidgets: View {
    @ObservedObject var music: MusicService
    @ObservedObject var planner: PlannerService

    var body: some View {
        VStack(spacing: 12) {
            if music.isPlaying { nowPlaying }
            if let badge = planner.badge { timerChip(icon: badge.icon, text: badge.text) }
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 14) {
            Group {
                if let url = music.artworkURL {
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.white.opacity(0.1) }
                } else {
                    ZStack { Color.white.opacity(0.1); Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5)) }
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(music.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(music.artist).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule().fill(.white.opacity(0.85))
                            .frame(width: g.size.width * CGFloat(min(music.position / max(music.duration, 1), 1)))
                    }
                }
                .frame(height: 3)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                control("backward.fill", 13) { music.previous() }
                control(music.isPlaying ? "pause.fill" : "play.fill", 17) { music.togglePlayPause() }
                control("forward.fill", 13) { music.next() }
            }
        }
        .padding(14)
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        )
    }

    private func control(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func timerChip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).monospacedDigit()
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 16)
        .frame(height: 34)
        .background(Capsule().fill(Color.white.opacity(0.09)).overlay(Capsule().strokeBorder(Color.white.opacity(0.1))))
    }
}
