import SwiftUI

/// Pomodoro (solda) + hızlı zamanlayıcılar (sağda).
struct TimerPanel: View {
    @ObservedObject var planner: PlannerService
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            pomodoro
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 6)
            timers
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Pomodoro

    private var pomodoro: some View {
        VStack(spacing: 6) {
            Text(planner.phase.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(phaseColor)
            Text(PlannerService.format(planner.pomodoroRemaining))
                .font(.system(size: 34, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
            Button(action: planner.togglePomodoro) {
                Text(planner.phase == .idle ? L("Başlat", "Start") : L("Durdur", "Stop"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(planner.phase == .idle ? .black : .white)
                    .frame(width: 84, height: 26)
                    .notchSurface(in: Capsule(),
                                  classic: planner.phase == .idle ? accent : .white.opacity(0.16),
                                  glass: planner.phase == .idle ? accent : .white.opacity(0.10))
            }
            .buttonStyle(.plain)
            Text("\(planner.completedPomodoros) pomodoro")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var phaseColor: Color {
        switch planner.phase {
        case .idle: return .white.opacity(0.5)
        case .work: return .orange
        case .rest: return .green
        }
    }

    // MARK: - Zamanlayıcılar

    private var timers: some View {
        VStack(spacing: 8) {
            Text(L("Zamanlayıcı", "Timer"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 6) {
                ForEach([5, 10, 15, 30], id: \.self) { m in
                    Button { planner.addTimer(minutes: m) } label: {
                        Text("\(m)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 26)
                            .notchSurface(in: Capsule(), classic: .white.opacity(0.14), glass: .white.opacity(0.08))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(L("dakika", "minutes"))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, -4)

            VStack(spacing: 4) {
                ForEach(planner.timers.prefix(2)) { t in
                    HStack {
                        Image(systemName: "timer").font(.system(size: 10))
                        Text(PlannerService.format(planner.remaining(until: t.endDate)))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                        Spacer()
                        Button { planner.removeTimer(t.id) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                }
                if planner.timers.count > 2 {
                    Text(L("+\(planner.timers.count - 2) daha", "+\(planner.timers.count - 2) more"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }
}
