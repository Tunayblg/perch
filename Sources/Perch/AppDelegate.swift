import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController()
        self.controller = controller
        controller.start()
        settingsWindow = SettingsWindowController(voice: controller.voice)

        // Menü çubuğu simgesi: ayarlar ve çıkış
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "Perch")
        statusItem = item
        rebuildMenu()

        NotificationCenter.default.addObserver(forName: .openSettingsWindow, object: nil, queue: .main) { [weak self] _ in
            self?.settingsWindow?.show()
        }

        AppSettings.shared.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: L("Ayarlar…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Perch'ten Çık", "Quit Perch"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        settingsWindow?.show()
    }
}
