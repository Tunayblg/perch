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
final class SettingsWindowController: NSObject, NSWindowDelegate {
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
        let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.title = L("Away Guard şifresi", "Away Guard password")
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        let editor = NSHostingView(rootView: AwayGuardPasswordEditor { [weak w] in w?.close() })
        w.contentView = editor
        w.setContentSize(editor.fittingSize)
        w.center()
        passwordWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === passwordWindow else { return }
        passwordWindow = nil
    }
}

private struct AwayGuardPasswordEditor: View {
    private enum Field { case password, confirmation }

    @ObservedObject private var settings = AppSettings.shared
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?
    @FocusState private var focusedField: Field?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "key")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Away Guard şifresi", "Away Guard password"))
                        .font(.system(size: 14, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(L("Bluetooth olmadan da ekranı açar.", "Reveal the screen without Bluetooth."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 7) {
                passwordField(L("Yeni şifre", "New password"), text: $password, field: .password)
                    .onSubmit { focusedField = .confirmation }
                passwordField(L("Şifreyi tekrarla", "Confirm password"), text: $confirmation, field: .confirmation)
                    .onSubmit(save)
            }

            HStack(spacing: 10) {
                Text(error ?? L("En az 4 karakter.", "At least 4 characters."))
                    .font(.system(size: 11))
                    .foregroundStyle(error == nil ? Color.secondary : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: save) {
                    Text(L("Kaydet", "Save"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 28)
                        .background(.primary.opacity(0.12), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(width: 310)
        .onExitCommand(perform: close)
        .onAppear {
            DispatchQueue.main.async { focusedField = .password }
        }
        .onChange(of: password) { _, _ in error = nil }
        .onChange(of: confirmation) { _, _ in error = nil }
    }

    private func passwordField(_ title: String, text: Binding<String>, field: Field) -> some View {
        SecureField(title, text: text)
            .font(.system(size: 13))
            .textFieldStyle(.plain)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.primary.opacity(focusedField == field ? 0.22 : 0.08))
                    .allowsHitTesting(false)
            }
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
