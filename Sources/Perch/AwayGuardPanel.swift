import SwiftUI

/// Away Guard (beta): cihaz seç, canlı sinyal grafiğini izle, eşiği ayarla, kilidi test et.
struct AwayGuardPanel: View {
    @ObservedObject var away: AwayGuardService
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leftColumn
                .frame(width: 176)
            rightColumn
                .frame(maxWidth: .infinity)
        }
        .onAppear { away.viewerAppeared() }
        .onDisappear { away.viewerDisappeared() }
    }

    // MARK: - Sol: aç/kapa, cihaz, durum, test

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Away Guard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("BETA")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange, in: Capsule())
                Spacer(minLength: 0)
                Button {
                    NotificationCenter.default.post(name: .openAwayGuardPassword, object: nil)
                } label: {
                    Label(L("Şifre", "Password"), systemImage: "key.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .notchSurface(in: Capsule(), classic: .white.opacity(0.10), glass: .white.opacity(0.07))
                }
                .buttonStyle(.plain)
                .help(settings.hasAwayPassword
                      ? L("Away Guard şifresini değiştir", "Change the Away Guard password")
                      : L("Away Guard şifresi belirle", "Set an Away Guard password"))
            }

            deviceRow

            mainButton

            HStack(spacing: 6) {
                manualCoverButton
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(statusText)
            }
            .frame(height: 26)
        }
    }

    private var manualCoverButton: some View {
        Button(action: away.coverManually) {
            Label(L("Elle gizle", "Hide now"), systemImage: "lock")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 7)
                .frame(height: 22)
                .notchSurface(in: Capsule(), classic: .white.opacity(0.10), glass: .white.opacity(0.07))
        }
        .buttonStyle(.plain)
        .disabled(away.phase == .covered)
        .help(L("Bluetooth cihazı gerekmeden ekranı gizle", "Hide the screen without a Bluetooth device"))
    }

    /// Büyük aç/kapa düğmesi. Geri sayımda "İptal"e dönüşür.
    private var mainButton: some View {
        let counting = away.phase == .countdown
        let title: String
        let symbol: String
        let background: Color
        let foreground: Color
        if counting {
            (title, symbol, background, foreground) = (L("İptal", "Cancel"), "xmark", .orange, .black)
        } else if away.enabled {
            (title, symbol, background, foreground) = (L("Koruma açık", "Guard on"), "checkmark.shield.fill", accent, .black)
        } else {
            (title, symbol, background, foreground) = (L("Korumayı aç", "Turn guard on"), "shield", Color.white.opacity(0.14), .white)
        }
        let disabled = away.selectedID == nil && !counting
        return Button {
            if counting { away.cancelCountdown() } else { away.enabled.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 32)
            .notchSurface(in: Capsule(), classic: background,
                          glass: counting || away.enabled ? background : .white.opacity(0.07))
            .animation(.smooth(duration: 0.25), value: away.enabled)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    /// Koruma kapalıyken sinyali elle canlı izlemek için (kalibrasyon). Panel kapanınca kendiliğinden kapanır.
    @ViewBuilder private var previewChip: some View {
        if !away.enabled, away.selectedID != nil {
            Button { away.setPreview(!away.previewing) } label: {
                Text(L("Önizle", "Preview"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(away.previewing ? Color.black : .white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .frame(height: 20)
                    .notchSurface(in: Capsule(), classic: away.previewing ? accent : .white.opacity(0.12),
                                  glass: away.previewing ? accent : .white.opacity(0.07))
            }
            .buttonStyle(.plain)
            .help(L("Koruma kapalıyken sinyali canlı izle", "Watch the live signal while the guard is off"))
        }
    }

    /// Koruma kapalı, cihaz seçili ve önizleme kapalı: hiçbir şey taranmıyor.
    private var paused: Bool { !away.enabled && away.selectedID != nil && !away.previewing }

    /// Küçük test düğmesi (3 sn sonra gizlilik ekranı, 4 sn sonra kendiliğinden kalkar).
    private var testChip: some View {
        Button(action: away.testCover) {
            Text("Test")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .frame(height: 20)
                .notchSurface(in: Capsule(), classic: .white.opacity(0.12), glass: .white.opacity(0.07))
        }
        .buttonStyle(.plain)
        .disabled(away.phase != .present)
        .opacity(away.phase != .present ? 0.4 : 1)
        .help(L("Ekranı gizlemeyi dene", "Try the privacy screen"))
    }

    private var deviceRow: some View {
        HStack(spacing: 4) {
            chevron("chevron.left") { away.cycleDevice(-1) }
            Group {
                if away.selectedID == nil, !away.previewing {
                    Button { away.setPreview(true) } label: {
                        Text(L("Cihaz ara", "Find device"))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(away.selectedName.isEmpty ? L("Cihaz seç", "Pick a device") : away.selectedName)
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            chevron("chevron.right") { away.cycleDevice(1) }
        }
        .padding(.horizontal, 3)
        .frame(height: 26)
        .notchSurface(in: RoundedRectangle(cornerRadius: 8), classic: .white.opacity(0.08),
                      glass: .black.opacity(0.12))
    }

    private func chevron(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(away.devices.isEmpty ? 0.2 : 0.7))
                .frame(width: 20, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(away.devices.isEmpty)
    }

    // MARK: - Sağ: canlı grafik + ayarlar

    private var rightColumn: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(paused ? "—" : (away.smoothed.map { "\($0) dBm" } ?? "—"))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .fixedSize()
                Spacer()
                previewChip
                testChip
                Text(away.baseline.map { L("normal", "usual") + " \($0)" } ?? L("öğreniyor…", "learning…"))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            }

            RSSIGraph(samples: paused ? [] : away.samples, threshold: away.threshold, baseline: away.baseline,
                      isAway: away.smoothed.map { $0 < away.threshold } ?? false, accent: accent)
                .frame(height: 50)
                .overlay {
                    if paused {
                        Text(L("Koruma kapalı, sinyal izlenmiyor", "Guard is off, signal isn't monitored"))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

            VStack(spacing: 5) {
                HStack(spacing: 8) {
                    Text(L("Hassasiyet", "Sensitivity"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    sensitivityPicker
                }
                Text(away.sensitivity.hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(nil, value: away.sensitivity)
            }
        }
    }

    /// Tek parça seçici: vurgu seçimler arasında yaylanarak kayar.
    private var sensitivityPicker: some View {
        let levels = AwaySensitivity.allCases
        let index = levels.firstIndex(of: away.sensitivity) ?? 1
        return GeometryReader { geo in
            let w = geo.size.width / CGFloat(levels.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(accent)
                    .frame(width: w - 4, height: geo.size.height - 4)
                    .offset(x: CGFloat(index) * w + 2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: index)
                HStack(spacing: 0) {
                    ForEach(levels) { level in
                        Button { away.sensitivity = level } label: {
                            Text(level.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(away.sensitivity == level ? Color.black : .white.opacity(0.75))
                                .frame(width: w, height: geo.size.height)
                                .contentShape(Rectangle())
                                .animation(.smooth(duration: 0.2), value: away.sensitivity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 26)
    }

    private func stepper(_ title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            miniButton("minus", minus)
            Text(value)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 34)
            miniButton("plus", plus)
        }
    }

    private func miniButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Durum metni

    private var statusText: String {
        if away.phase == .covered { return L("Ekran gizli", "Screen hidden") }
        if away.phase == .countdown { return L("Ekran gizleniyor: \(away.countdown ?? 0) sn", "Hiding screen in \(away.countdown ?? 0) s") + (away.isTesting ? " (test)" : "") }
        if away.waitingForDeviceSince != nil { return L("Cihaz dönene kadar beklemede", "Paused until device returns") }
        switch away.bluetooth {
        case .unauthorized: return L("Bluetooth izni yok. Sistem Ayarları → Gizlilik → Bluetooth", "No Bluetooth permission. System Settings → Privacy → Bluetooth")
        case .off: return L("Bluetooth kapalı", "Bluetooth is off")
        default: break
        }
        if away.selectedID == nil {
            return away.previewing && away.devices.isEmpty
                ? L("Cihaz aranıyor…", "Looking for devices…")
                : L("Otomatik koruma için cihaz seç", "Choose a device for auto guard")
        }
        if !away.seenSelected { return L("Cihaz aranıyor…", "Looking for the device…") }
        if away.enabled, away.holdingOff { return L("Sinyal zayıf ama bilgisayarı kullanıyorsun, ekran açık", "Weak signal but you're using the Mac, screen stays on") }
        if !away.enabled { return away.previewing ? L("Kapalı, önizleme açık", "Off, preview is on") : L("Kapalı, sinyal izlenmiyor", "Off, not monitoring") }
        if away.awayFor > 0 { return L("Uzakta \(away.awayFor)/\(away.grace) sn", "Away \(away.awayFor)/\(away.grace) s") }
        return L("Koruma açık, yakında", "Guard on, nearby")
    }

    private var statusColor: Color {
        if away.phase == .countdown { return .orange }
        if away.bluetooth == .unauthorized || away.bluetooth == .off { return .red.opacity(0.9) }
        return .white.opacity(0.6)
    }
}

/// Son 60 saniyenin sinyal gücü: yumuşak eğri, dolgu, parlayan uç nokta, eşik altı bölge.
struct RSSIGraph: View {
    let samples: [AwayGuardService.Sample]
    let threshold: Int
    let baseline: Int?
    let isAway: Bool
    let accent: Color

    private let window: TimeInterval = 60

    var body: some View {
        // Yalnızca sekme açıkken çizilir. Eğri 60 sn'de ~280 px kaydığı için 10 fps akıcı görünür ve ucuzdur
        TimelineView(.animation(minimumInterval: 0.1)) { ctx in
            Canvas { gc, size in draw(gc, size, ctx.date) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Dikey aralık normal sinyale göre ortalanır; yoksa sabit aralık.
    private var range: (lo: Double, hi: Double) {
        if let b = baseline { return (Double(b) - 34, Double(b) + 10) }
        return (-98, -38)
    }

    private func draw(_ gc: GraphicsContext, _ size: CGSize, _ now: Date) {
        let (lo, hi) = range
        func y(_ v: Double) -> CGFloat {
            let t = (min(max(v, lo), hi) - lo) / (hi - lo)
            return size.height * 0.07 + size.height * 0.86 * (1 - CGFloat(t))
        }
        let lineColor: Color = isAway ? .orange : accent

        // Zemin
        gc.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.05)))

        // Eşik altı bölge (turuncu, hafif) ve kesikli eşik çizgisi
        let ty = y(Double(threshold))
        gc.fill(Path(CGRect(x: 0, y: ty, width: size.width, height: size.height - ty)),
                with: .linearGradient(Gradient(colors: [.orange.opacity(0.16), .orange.opacity(0.02)]),
                                      startPoint: CGPoint(x: 0, y: ty), endPoint: CGPoint(x: 0, y: size.height)))
        var dash = Path()
        dash.move(to: CGPoint(x: 0, y: ty))
        dash.addLine(to: CGPoint(x: size.width, y: ty))
        gc.stroke(dash, with: .color(.orange.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        // Örnekleri yumuşatılmış noktalara çevir; 4 sn'den uzun boşlukta çizgiyi böl
        var runs: [[CGPoint]] = []
        var current: [CGPoint] = []
        var smoothedValue: Double?
        var previous: Date?
        for s in samples {
            let age = now.timeIntervalSince(s.time)
            guard age <= window else { continue }
            if let p = previous, s.time.timeIntervalSince(p) > 4 {
                if !current.isEmpty { runs.append(current) }
                current = []
                smoothedValue = nil
            }
            let v = smoothedValue.map { $0 * 0.55 + Double(s.rssi) * 0.45 } ?? Double(s.rssi)
            smoothedValue = v
            current.append(CGPoint(x: size.width * CGFloat(1 - age / window), y: y(v)))
            previous = s.time
        }
        if !current.isEmpty { runs.append(current) }

        for run in runs where run.count > 1 {
            let curve = Self.curve(run)
            // Dolgu
            var area = curve
            area.addLine(to: CGPoint(x: run.last!.x, y: size.height))
            area.addLine(to: CGPoint(x: run.first!.x, y: size.height))
            area.closeSubpath()
            gc.fill(area, with: .linearGradient(Gradient(colors: [lineColor.opacity(0.32), lineColor.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
            // Çizgi
            gc.stroke(curve, with: .color(lineColor),
                      style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }

        // Parlayan uç nokta
        if let head = runs.last?.last {
            gc.fill(Path(ellipseIn: CGRect(x: head.x - 7, y: head.y - 7, width: 14, height: 14)), with: .color(lineColor.opacity(0.18)))
            gc.fill(Path(ellipseIn: CGRect(x: head.x - 3.2, y: head.y - 3.2, width: 6.4, height: 6.4)), with: .color(lineColor))
        }
    }

    /// Catmull-Rom → Bezier: noktalardan geçen pürüzsüz eğri.
    private static func curve(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count > 1 else { return p }
        p.move(to: pts[0])
        for i in 0..<pts.count - 1 {
            let p0 = i > 0 ? pts[i - 1] : pts[i]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = i + 2 < pts.count ? pts[i + 2] : p2
            p.addCurve(to: p2,
                       control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                       control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
        return p
    }
}
