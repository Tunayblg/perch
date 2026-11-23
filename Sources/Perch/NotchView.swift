import AppKit
import SwiftUI

/// Üstü düz (ekrana yapışık), altı yuvarlak köşeli çentik şekli.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct NotchView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var music: MusicService
    @ObservedObject var planner: PlannerService
    @ObservedObject var todos: TodoStore
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var voice: VoiceNoteService
    @ObservedObject var stats: StatsService
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var awayGuard: AwayGuardService
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let size = state.expanded ? state.expandedSize : state.collapsedSize
        ZStack(alignment: .top) {
            NotchBackground(
                expanded: state.expanded,
                glass: settings.appearance == .liquidGlass,
                reduceTransparency: reduceTransparency
            )
            .allowsHitTesting(false)

            if state.expanded {
                VStack(spacing: 0) {
                    header
                    Group {
                        switch effectiveTab {
                        case .music: MusicPanel(music: music)
                        case .timer: TimerPanel(planner: planner)
                        case .voice: VoicePanel(voice: voice)
                        case .todo: TodoPanel(store: todos)
                        case .shelf: ShelfPanel(store: shelf)
                        case .stats: StatsPanel(stats: stats)
                        case .clipboard: ClipboardPanel(clipboard: clipboard)
                        case .awayGuard: AwayGuardPanel(away: awayGuard)
                        case .settings: SettingsPanel(compact: size.width < 490)
                        }
                    }
                    .id(effectiveTab)
                    .transition(.tabSlide(direction: state.tabDirection))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                    .frame(maxHeight: .infinity)
                }
                .transition(.asymmetric(
                    // Panel açılınca içerik, kabuk büyürken hafif gecikmeli belirir
                    insertion: .opacity.animation(.easeOut(duration: 0.26).delay(0.1))
                        .combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity.animation(.easeIn(duration: 0.12))
                ))
            } else if state.showsBadge {
                if voice.isRecording {
                    collapsedBadge(icon: "mic.fill", text: PlannerService.format(voice.elapsed), tint: .red)
                        .transition(.opacity)
                } else if let c = awayGuard.countdown {
                    collapsedBadge(icon: "lock.fill", text: "\(c)", tint: .orange)
                        .transition(.opacity)
                } else if let badge = planner.badge {
                    collapsedBadge(icon: badge.icon, text: badge.text)
                        .transition(.opacity)
                } else if music.isPlaying {
                    musicBadge
                        .transition(.opacity)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.42), value: state.expanded)
        .animation(.smooth(duration: 0.36), value: state.showsBadge)
        .animation(.smooth(duration: 0.36), value: size.width)
        .environment(\.accent, settings.effectiveAccent.color)
        .environment(\.notchAppearance, settings.appearance)
        .id(settings.language) // dil değişince tüm arayüz yeniden kurulur
    }

    /// Seçili sekme gizlendiyse ilk görünür sekmeye düş.
    private var effectiveTab: NotchTab {
        settings.visibleTabs.contains(state.tab) ? state.tab : (settings.visibleTabs.first ?? .settings)
    }

    /// Sekme düğmeleri çentiğin iki yanında (2 sol, 2 sağ); çentiğin kendisi ortada kalır.
    private var header: some View {
        let tabs = settings.visibleTabs
        let half = (tabs.count + 1) / 2
        return HStack(spacing: 2) {
            ForEach(Array(tabs.prefix(half))) { tabButton($0) }
            Spacer(minLength: state.notchSize.width + 12)
            ForEach(Array(tabs.dropFirst(half))) { tabButton($0) }
        }
        .padding(.horizontal, 14)
        .frame(height: state.notchSize.height)
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        let active = effectiveTab == tab
        return Button { state.select(tab) } label: {
            Image(systemName: tab.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? settings.effectiveAccent.color : .white.opacity(0.4))
                .frame(width: 26, height: 24)
                .notchSurface(in: Capsule(), classic: active ? .white.opacity(0.14) : .clear,
                              glass: active ? .white.opacity(0.12) : .clear,
                              highlighted: active)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: active)
        .help(tab.title)
    }

    /// Şarkı çalarken: solda kapak, sağda ses animasyonu; ortada fiziksel çentik.
    private var musicBadge: some View {
        HStack(spacing: 0) {
            Group {
                if let url = music.artworkURL {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Color.white.opacity(0.15) }
                } else {
                    ZStack {
                        Color.white.opacity(0.15)
                        Image(systemName: "music.note").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .frame(width: state.badgeWidth)

            Spacer().frame(width: state.notchSize.width)

            EqualizerBars()
                .frame(width: state.badgeWidth)
        }
        .frame(height: state.notchSize.height)
    }

    /// Kapalıyken: solda ikon, sağda kalan süre; ortada fiziksel çentik.
    private func collapsedBadge(icon: String, text: String, tint: Color = .white) -> some View {
        HStack(spacing: 0) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: state.badgeWidth)
            Spacer().frame(width: state.notchSize.width)
            Text(text)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .frame(width: state.badgeWidth)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .frame(height: state.notchSize.height)
    }
}

struct MusicPanel: View {
    @ObservedObject var music: MusicService
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 16) {
            artwork
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(music.hasTrack ? music.title : L("Müzik çalmıyor", "Nothing playing"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(music.hasTrack ? music.artist : L("Spotify veya Music'te bir şarkı başlat", "Play a song in Spotify or Music"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                progress
                controls
            }
        }
    }

    private var artwork: some View {
        Group {
            if let url = music.artworkURL {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: "music.note")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .notchSurface(in: RoundedRectangle(cornerRadius: 12), classic: .white.opacity(0.08),
                          glass: .white.opacity(0.06))
    }

    private var progress: some View {
        HStack(spacing: 8) {
            Text(format(music.position))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(accent)
                        .frame(width: g.size.width * CGFloat(min(music.position / max(music.duration, 1), 1)))
                }
            }
            .frame(height: 4)
            .animation(.linear(duration: 1), value: music.position)
            Text("-" + format(max(music.duration - music.position, 0)))
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.6))
        .opacity(music.hasTrack ? 1 : 0.4)
    }

    private var controls: some View {
        HStack(spacing: 30) {
            Spacer()
            button("backward.fill", 20) { music.previous() }
            button(music.isPlaying ? "pause.fill" : "play.fill", 30, primary: true) { music.togglePlayPause() }
            button("forward.fill", 20) { music.next() }
            Spacer()
        }
        .disabled(!music.hasTrack)
        .opacity(music.hasTrack ? 1 : 0.35)
    }

    private func button(_ symbol: String, _ size: CGFloat, primary: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .notchSurface(in: Circle(), classic: .clear, glass: primary ? .white.opacity(0.09) : .clear,
                              highlighted: primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func format(_ s: Double) -> String {
        let t = Int(max(s, 0))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}


/// Ses çubukları animasyonu (çalarken sağ rozet).
struct EqualizerBars: NSViewRepresentable {
    @Environment(\.accent) private var accent

    func makeNSView(context: Context) -> EqualizerNSView { EqualizerNSView() }

    func updateNSView(_ view: EqualizerNSView, context: Context) {
        view.color = NSColor(accent)
    }
}

/// Ses çubukları: animasyonu Core Animation (sistemin çizim sunucusu) yürütür; uygulama her karede
/// kod çalıştırmaz, bu yüzden müzik saatlerce çalsa bile CPU/pil maliyeti neredeyse sıfırdır.
final class EqualizerNSView: NSView {
    var color: NSColor = .white {
        didSet { bars.forEach { $0.backgroundColor = color.cgColor } }
    }

    private var bars: [CALayer] = []
    private let durations: [CFTimeInterval] = [0.46, 0.58, 0.40, 0.66]
    private let offsets: [CFTimeInterval] = [0.0, 0.17, 0.31, 0.08]
    private let barWidth: CGFloat = 3
    private let gap: CGFloat = 2.5
    private let barHeight: CGFloat = 16

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for _ in 0..<4 {
            let l = CALayer()
            l.backgroundColor = color.cgColor
            l.cornerRadius = barWidth / 2
            layer?.addSublayer(l)
            bars.append(l)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let total = CGFloat(bars.count) * barWidth + CGFloat(bars.count - 1) * gap
        let startX = (bounds.width - total) / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, l) in bars.enumerated() {
            l.frame = CGRect(x: startX + CGFloat(i) * (barWidth + gap),
                             y: (bounds.height - barHeight) / 2, width: barWidth, height: barHeight)
        }
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startAnimating() } else { bars.forEach { $0.removeAllAnimations() } }
    }

    private func startAnimating() {
        for (i, l) in bars.enumerated() {
            l.removeAllAnimations()
            let a = CABasicAnimation(keyPath: "transform.scale.y")
            a.fromValue = 0.3
            a.toValue = 1.0
            a.duration = durations[i]
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timeOffset = offsets[i]
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            l.add(a, forKey: "bounce")
        }
    }
}

/// Sekme geçişi: eski içerik kayıp solar, yenisi aynı yönden kayarak gelir.
struct SlideFade: ViewModifier {
    var x: CGFloat
    var opacity: Double
    func body(content: Content) -> some View {
        content.offset(x: x).opacity(opacity)
    }
}

extension AnyTransition {
    static func tabSlide(direction: CGFloat) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: SlideFade(x: 30 * direction, opacity: 0), identity: SlideFade(x: 0, opacity: 1)),
            removal: .modifier(active: SlideFade(x: -30 * direction, opacity: 0), identity: SlideFade(x: 0, opacity: 1))
        )
    }
}
