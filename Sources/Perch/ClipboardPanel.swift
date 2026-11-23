import SwiftUI

/// Pano geçmişi: satıra tıkla, metin tekrar panoya kopyalansın.
struct ClipboardPanel: View {
    @ObservedObject var clipboard: ClipboardService
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(L("Pano geçmişi", "Clipboard history"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !clipboard.items.isEmpty {
                    Button(L("Temizle", "Clear")) { clipboard.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if clipboard.items.isEmpty {
                Spacer()
                Text(L("Kopyaladığın metinler burada görünür.", "Text you copy will show up here."))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(clipboard.items) { item in
                            row(item)
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        let copied = clipboard.lastCopiedID == item.id
        return HStack(spacing: 8) {
            Text(item.text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if copied {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
            } else {
                Button { clipboard.remove(item.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .notchSurface(in: RoundedRectangle(cornerRadius: 8),
                      classic: .white.opacity(copied ? 0.16 : 0.07),
                      glass: .white.opacity(copied ? 0.15 : 0.06),
                      highlighted: copied)
        .contentShape(Rectangle())
        .onTapGesture { clipboard.copy(item) }
        .animation(.smooth(duration: 0.2), value: copied)
    }
}
