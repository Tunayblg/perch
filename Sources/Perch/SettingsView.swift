import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var voice: VoiceNoteService

    var body: some View {
        Form {
            Section {
                Picker(L("Dil", "Language"), selection: $settings.language) {
                    Text(L("Sistem", "System")).tag(AppLanguage.system)
                    Text("Türkçe").tag(AppLanguage.tr)
                    Text("English").tag(AppLanguage.en)
                }
                Toggle(L("Oturum açılınca başlat", "Launch at login"), isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let err = settings.launchError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            Section(L("Pomodoro", "Pomodoro")) {
                Stepper(value: $settings.workMinutes, in: 1...120) {
                    Text(L("Odak süresi: \(settings.workMinutes) dk", "Focus: \(settings.workMinutes) min"))
                }
                Stepper(value: $settings.restMinutes, in: 1...60) {
                    Text(L("Mola süresi: \(settings.restMinutes) dk", "Break: \(settings.restMinutes) min"))
                }
            }

            Section(L("Sesli not", "Voice note")) {
                Toggle(L("Notlar'a otomatik kaydet", "Auto-save to Notes"), isOn: $voice.autoSaveToNotes)
                Text(L("Kısayol: ⌃⌥N (kaydı başlat/durdur)", "Shortcut: ⌃⌥N (start/stop recording)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Perch \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 400)
    }
}

/// Ayarlar penceresini yönetir.
final class SettingsWindowController {
    private var window: NSWindow?
    private let voice: VoiceNoteService

    init(voice: VoiceNoteService) { self.voice = voice }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.contentView = NSHostingView(rootView: SettingsView(voice: voice))
            w.title = L("Ayarlar", "Settings")
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.title = L("Ayarlar", "Settings")
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
