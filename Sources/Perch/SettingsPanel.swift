import SwiftUI

/// Paneldeki Ayarlar sekmesi: sekmeleri, temayı, vurgu rengini ve dili düzenler.
struct SettingsPanel: View {
    let compact: Bool

    @ObservedObject var settings = AppSettings.shared
    @State private var selected: NotchTab = .music
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                tabsColumn
                appearancePicker
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
            appearanceColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sekmeler

    private var tabsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(L("Sekmeler", "Tabs"))

            HStack(spacing: compact ? 2 : 4) {
                ForEach(settings.tabOrder) { tab in
                    Button { selected = tab } label: {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(settings.isVisible(tab) ? 0.95 : 0.3))
                            .frame(width: compact ? 18 : 25, height: 25)
                            .background(selected == tab ? Color.white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(selected == tab ? accent : .clear, lineWidth: 1.2)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                Text(selected.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                smallButton(settings.isVisible(selected) ? "eye.fill" : "eye.slash.fill",
                            enabled: selected != .settings) { settings.toggle(selected) }
                smallButton("chevron.left") { settings.move(selected, by: -1) }
                smallButton("chevron.right") { settings.move(selected, by: 1) }
            }
            Text(L("Gizli sekmeler silik görünür.", "Hidden tabs look dimmed."))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Görünüm

    private var appearancePicker: some View {
        HStack(spacing: 5) {
            sectionTitle(L("Tema", "Theme"))
            ForEach(NotchAppearance.allCases) { appearance in
                let selected = settings.appearance == appearance
                Button { settings.appearance = appearance } label: {
                    Text(appearance.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .notchSurface(in: Capsule(), classic: selected ? accent : .white.opacity(0.1),
                                      glass: selected ? accent : .white.opacity(0.07))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var appearanceColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(L("Vurgu rengi", "Accent color"))
            HStack(spacing: compact ? 5 : 7) {
                ForEach(AccentChoice.allCases) { choice in
                    Button { settings.accent = choice } label: {
                        Circle()
                            .fill(choice.color)
                            .frame(width: compact ? 18 : 20, height: 20)
                            .overlay(
                                Circle().strokeBorder(.white, lineWidth: settings.accent == choice ? 2 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            sectionTitle(L("Dil", "Language")).padding(.top, 2)
            HStack(spacing: 5) {
                langButton(L("Sistem", "System"), .system)
                langButton("TR", .tr)
                langButton("EN", .en)
            }

            Button { NotificationCenter.default.post(name: .openSettingsWindow, object: nil) } label: {
                Text(L("Tüm ayarlar…", "All settings…"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Parçalar

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
    }

    private func smallButton(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(enabled ? 0.85 : 0.25))
                .frame(width: 24, height: 22)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func langButton(_ title: String, _ lang: AppLanguage) -> some View {
        Button { settings.language = lang } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(settings.language == lang ? .black : .white.opacity(0.8))
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(settings.language == lang ? accent : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
