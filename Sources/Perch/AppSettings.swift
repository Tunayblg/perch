import Foundation
import ServiceManagement

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, tr, en
    var id: String { rawValue }
}

/// Kullanıcı ayarları (UserDefaults'ta saklanır).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var workMinutes: Int {
        didSet { UserDefaults.standard.set(workMinutes, forKey: "workMinutes") }
    }
    @Published var restMinutes: Int {
        didSet { UserDefaults.standard.set(restMinutes, forKey: "restMinutes") }
    }
    /// Away Guard: gizlilik ekranına ek olarak gerçek ekran kilidi de at (parola/Touch ID ister).
    @Published var awayAlsoLock: Bool {
        didSet { UserDefaults.standard.set(awayAlsoLock, forKey: "awayAlsoLock") }
    }
    @Published var accent: AccentChoice {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: "accent") }
    }
    @Published private(set) var tabOrder: [NotchTab] {
        didSet { UserDefaults.standard.set(tabOrder.map(\.rawValue), forKey: "tabOrder") }
    }
    @Published private(set) var hiddenTabs: Set<NotchTab> {
        didSet { UserDefaults.standard.set(hiddenTabs.map(\.rawValue), forKey: "hiddenTabs") }
    }
    @Published private(set) var launchAtLogin: Bool
    @Published var launchError: String?

    private init() {
        let d = UserDefaults.standard
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .system
        let work = d.integer(forKey: "workMinutes")
        let rest = d.integer(forKey: "restMinutes")
        workMinutes = work > 0 ? work : 25
        restMinutes = rest > 0 ? rest : 5
        accent = AccentChoice(rawValue: d.string(forKey: "accent") ?? "") ?? .white
        awayAlsoLock = d.bool(forKey: "awayAlsoLock")

        // Kayıtlı sıra + sonradan eklenen yeni sekmeler
        var order = (d.stringArray(forKey: "tabOrder") ?? []).compactMap(NotchTab.init(rawValue:))
        for tab in NotchTab.allCases where !order.contains(tab) {
            order.insert(tab, at: order.firstIndex(of: .settings) ?? order.endIndex)
        }
        tabOrder = order
        hiddenTabs = Set((d.stringArray(forKey: "hiddenTabs") ?? []).compactMap(NotchTab.init(rawValue:)))
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Sekmeler

    /// Ayarlar sekmesi her zaman görünür (kilitlenmemek için).
    func isVisible(_ tab: NotchTab) -> Bool { tab == .settings || !hiddenTabs.contains(tab) }

    var visibleTabs: [NotchTab] { tabsOverride ?? tabOrder.filter(isVisible) }

    func toggle(_ tab: NotchTab) {
        guard tab != .settings else { return }
        if hiddenTabs.contains(tab) { hiddenTabs.remove(tab) } else { hiddenTabs.insert(tab) }
    }

    func move(_ tab: NotchTab, by offset: Int) {
        guard let i = tabOrder.firstIndex(of: tab) else { return }
        let j = i + offset
        guard tabOrder.indices.contains(j) else { return }
        tabOrder.swapAt(i, j)
    }

    // Önizleme üretimi için bellek içi geçersiz kılmalar (kullanıcı ayarlarına dokunmaz, kaydedilmez)
    var languageOverride: AppLanguage?
    var accentOverride: AccentChoice?
    var tabsOverride: [NotchTab]?
    var effectiveAccent: AccentChoice { accentOverride ?? accent }

    var isTurkish: Bool {
        switch languageOverride ?? language {
        case .tr: return true
        case .en: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("tr") ?? false
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Çift dilli metin: L("Türkçe", "English")
func L(_ tr: String, _ en: String) -> String {
    AppSettings.shared.isTurkish ? tr : en
}
