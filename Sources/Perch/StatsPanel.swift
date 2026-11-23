import SwiftUI

/// Sistem sekmesi: CPU / RAM halkaları, ağ hızı, pil ve disk.
struct StatsPanel: View {
    @ObservedObject var stats: StatsService
    @Environment(\.accent) private var accent
    @Environment(\.notchAppearance) private var appearance

    var body: some View {
        HStack(spacing: 18) {
            ring(title: "CPU", value: stats.cpu, detail: "\(Int(stats.cpu * 100))%")
            ring(title: "RAM", value: Double(stats.memUsed) / Double(max(stats.memTotal, 1)),
                 detail: StatsService.gigabytes(stats.memUsed))

            VStack(alignment: .leading, spacing: 7) {
                netRow(symbol: "arrow.down", value: stats.netDown, history: stats.downHistory)
                netRow(symbol: "arrow.up", value: stats.netUp, history: stats.upHistory)
                HStack(spacing: 12) {
                    if let pct = stats.batteryPercent {
                        label(stats.isCharging ? "battery.100.bolt" : "battery.75", "\(pct)%")
                    }
                    label("internaldrive", L("\(Int(Double(stats.diskFree) / 1e9)) GB boş", "\(Int(Double(stats.diskFree) / 1e9)) GB free"))
                }
            }
            .padding(appearance == .liquidGlass ? 8 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .notchSurface(in: RoundedRectangle(cornerRadius: 10), classic: .clear,
                          glass: .black.opacity(0.10))
        }
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
    }

    private func ring(title: String, value: Double, detail: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                    .stroke(color(for: value), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: value)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            Text(detail)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Yükseldikçe vurgu renginden kırmızıya döner.
    private func color(for value: Double) -> Color {
        value > 0.85 ? .red : (value > 0.65 ? .orange : accent)
    }

    private func netRow(symbol: String, value: Double, history: [Double]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 12)
            Text(StatsService.rate(value))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 70, alignment: .leading)
            Sparkline(values: history)
                .stroke(accent.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                .frame(height: 16)
        }
    }

    private func label(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11))
            Text(text).font(.system(size: 11).monospacedDigit())
        }
        .foregroundStyle(.white.opacity(0.6))
    }
}

/// Basit çizgi grafiği.
struct Sparkline: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        let peak = max(values.max() ?? 1, 1)
        for (i, v) in values.enumerated() {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = rect.maxY - rect.height * CGFloat(v / peak)
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}
