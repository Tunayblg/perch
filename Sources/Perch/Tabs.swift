import SwiftUI

/// Panelin sekmeleri.
enum NotchTab: String, CaseIterable, Codable, Identifiable {
    case music, timer, voice, todo, shelf, stats, clipboard, awayGuard, settings

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .music: return "music.note"
        case .timer: return "timer"
        case .voice: return "mic.fill"
        case .todo: return "checklist"
        case .shelf: return "tray.fill"
        case .stats: return "cpu"
        case .clipboard: return "doc.on.clipboard"
        case .awayGuard: return "lock.shield.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .music: return L("Müzik", "Music")
        case .timer: return L("Zamanlayıcı", "Timer")
        case .voice: return L("Sesli not", "Voice note")
        case .todo: return L("Yapılacaklar", "To-do")
        case .shelf: return L("Raf / AirDrop", "Shelf / AirDrop")
        case .stats: return L("Sistem", "System")
        case .clipboard: return L("Pano geçmişi", "Clipboard")
        case .awayGuard: return "Away Guard (beta)"
        case .settings: return L("Ayarlar", "Settings")
        }
    }
}

/// Vurgu rengi seçenekleri (aktif sekme, ilerleme çubuğu, ses çubukları...).
enum AccentChoice: String, CaseIterable, Identifiable {
    case white, blue, green, orange, pink, purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: return .white
        case .blue: return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .green: return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .orange: return Color(red: 1.0, green: 0.60, blue: 0.20)
        case .pink: return Color(red: 1.0, green: 0.40, blue: 0.65)
        case .purple: return Color(red: 0.65, green: 0.45, blue: 1.0)
        }
    }
}

private struct AccentKey: EnvironmentKey {
    static let defaultValue = Color.white
}

extension EnvironmentValues {
    var accent: Color {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}

extension Notification.Name {
    static let openSettingsWindow = Notification.Name("openSettingsWindow")
}
