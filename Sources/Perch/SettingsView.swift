import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var voice: VoiceNoteService

    var body: some View {
        Form {
            Section {
                Picker(L("Çentik teması", "Notch theme"), selection: $settings.appearance) {
                    ForEach(NotchAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
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

            Section("Away Guard (beta)") {
                Button(settings.hasAwayPassword
                       ? L("Away Guard şifresini değiştir…", "Change Away Guard password…")
                       : L("Away Guard şifresi belirle…", "Set an Away Guard password…")) {
                    NotificationCenter.default.post(name: .openAwayGuardPassword, object: nil)
                }
                Toggle(L("Gizlilik ekranına ek olarak ekranı kilitle", "Also lock the screen (password / Touch ID)"), isOn: $settings.awayAlsoLock)
                Text(L("⌃⌥P ile gizlilik ekranını aç. Away Guard şifresi yalnızca bu örtüyü kaldırır. macOS kilidi için Mac parolan veya Touch ID gerekir.",
                       "Press ⌃⌥P to show the privacy curtain. The Away Guard password reveals the screen. Use your Mac password or Touch ID for the macOS lock."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 380, height: 470)
    }
}

/// Ayarlar penceresini yönetir.
final class SettingsWindowController {
    private var window: NSWindow?
    private var passwordWindow: NSWindow?
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

    func showAwayGuardPassword() {
        if let passwordWindow, passwordWindow.isVisible {
            passwordWindow.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.title = L("Away Guard şifresi", "Away Guard password")
        w.contentView = NSHostingView(rootView: AwayGuardPasswordEditor { [weak w] in w?.close() })
        w.center()
        passwordWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct AwayGuardPasswordEditor: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Bu şifreyle Bluetooth cihazın yanında olmasa da Perch’ün gizlilik ekranını açabilirsin.",
                   "This password opens Perch’s privacy screen even when your Bluetooth device is unavailable."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField(L("Yeni şifre", "New password"), text: $password)
            SecureField(L("Şifreyi tekrarla", "Confirm password"), text: $confirmation)
                .onSubmit(save)
            Text(error ?? L("4 ile 128 karakter arasında bir şifre seç.", "Choose a password from 4 to 128 characters."))
                .font(.caption)
                .foregroundStyle(error == nil ? Color.secondary : Color.red)
            HStack {
                Spacer()
                Button(L("Vazgeç", "Cancel"), action: close)
                    .keyboardShortcut(.cancelAction)
                Button(L("Kaydet", "Save"), action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        guard AwayGuardPassword.isValidLength(password) else {
            error = L("Şifre 4 ile 128 karakter arasında olmalı.", "Use between 4 and 128 characters.")
            return
        }
        guard password == confirmation else {
            error = L("Şifreler eşleşmiyor.", "Passwords do not match.")
            return
        }
        guard settings.setAwayPassword(password) else {
            error = L("Şifre kaydedilemedi.", "Could not save the password.")
            return
        }
        close()
    }
}
