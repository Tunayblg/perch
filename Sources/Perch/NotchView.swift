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
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        let size = state.expanded ? state.expandedSize : state.collapsedSize
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: state.expanded ? 26 : 10)
                .fill(Color.black)

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
                        case .settings: SettingsPanel()
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
        .environment(\.accent, settings.accent.color)
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
                .foregroundStyle(active ? settings.accent.color : .white.opacity(0.4))
                .frame(width: 26, height: 24)
                .background(active ? Color.white.opacity(0.14) : .clear, in: Capsule())
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
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "music.note")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
        }
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
            button(music.isPlaying ? "pause.fill" : "play.fill", 30) { music.togglePlayPause() }
            button("forward.fill", 20) { music.next() }
            Spacer()
        }
        .disabled(!music.hasTrack)
        .opacity(music.hasTrack ? 1 : 0.35)
    }

    private func button(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
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
struct EqualizerBars: View {
    @Environment(\.accent) private var accent
    private let phases: [Double] = [0.0, 1.3, 2.4, 0.7]
    private let speeds: [Double] = [5.2, 6.6, 4.4, 7.3]

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { i in
                    let h = 5 + 11 * abs(sin(t * speeds[i] * 0.6 + phases[i]))
                    Capsule()
                        .fill(accent)
                        .frame(width: 3, height: h)
                }
            }
            .frame(height: 18)
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
