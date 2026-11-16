import SwiftUI

/// Sesli not: büyük kayıt düğmesi + son notlar.
struct VoicePanel: View {
    @ObservedObject var voice: VoiceNoteService

    var body: some View {
        HStack(spacing: 14) {
            recordColumn
                .frame(width: 84)
            VStack(alignment: .leading, spacing: 6) {
                if voice.isRecording {
                    liveView
                } else {
                    listView
                }
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Kayıt düğmesi

    private var recordColumn: some View {
        VStack(spacing: 6) {
            Button(action: voice.toggle) {
                ZStack {
                    Circle()
                        .fill(voice.isRecording ? Color.red : Color.white.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: voice.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Text(voice.isRecording ? PlannerService.format(voice.elapsed) : "⌃⌥N")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Kayıt sırasında

    private var liveView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Dinliyorum…", "Listening…"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
            Text(voice.liveText.isEmpty ? L("Konuş, bitince durdur.", "Speak, then stop.") : voice.liveText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(voice.liveText.isEmpty ? 0.4 : 0.95))
                .lineLimit(4)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Son notlar

    private var listView: some View {
        Group {
            if voice.notes.isEmpty {
                Text(L("Henüz sesli not yok.\nMikrofona bas ya da ⌃⌥N'e bas ve konuş.", "No voice notes yet.\nTap the mic or press ⌃⌥N and speak."))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(voice.notes) { note in
                            row(note)
                        }
                    }
                }
            }
        }
    }

    private func row(_ note: VoiceNote) -> some View {
        HStack(spacing: 8) {
            Text(note.text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if note.inNotes {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                    .help(L("Notlar'a kaydedildi", "Saved to Notes"))
            } else {
                iconButton("note.text.badge.plus", help: L("Notlar'a kaydet", "Save to Notes")) { voice.saveToAppleNotes(note.id) }
            }
            iconButton("doc.on.doc", help: L("Kopyala", "Copy")) { voice.copy(note.id) }
            iconButton("xmark", help: L("Sil", "Delete")) { voice.delete(note.id) }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Alt satır

    private var footer: some View {
        HStack(spacing: 6) {
            Button { voice.autoSaveToNotes.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: voice.autoSaveToNotes ? "checkmark.square.fill" : "square")
                    Text(L("Notlar'a otomatik kaydet", "Auto-save to Notes"))
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            Spacer()
            if let status = voice.status {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}
