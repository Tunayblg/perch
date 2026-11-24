import SwiftUI

/// Gizlilik ekranının renk teması (Ayarlar'dan seçilir).
enum PrivacyTheme: String, CaseIterable, Identifiable {
    case night, forest, sunset, graphite
    var id: String { rawValue }

    var title: String {
        switch self {
        case .night: return L("Gece", "Night")
        case .forest: return L("Orman", "Forest")
        case .sunset: return L("Gün batımı", "Sunset")
        case .graphite: return L("Grafit", "Graphite")
        }
    }

    /// (üst, alt, parıltı, kuş tonu)
    var palette: (top: Color, bottom: Color, glow: Color, tint: Color) {
        switch self {
        case .night:
            return (Color(red: 0.012, green: 0.012, blue: 0.035), Color(red: 0.05, green: 0.04, blue: 0.11),
                    Color(red: 0.36, green: 0.30, blue: 0.92), Color(red: 0.72, green: 0.76, blue: 1))
        case .forest:
            return (Color(red: 0.01, green: 0.03, blue: 0.025), Color(red: 0.03, green: 0.09, blue: 0.07),
                    Color(red: 0.16, green: 0.72, blue: 0.5), Color(red: 0.70, green: 0.95, blue: 0.82))
        case .sunset:
            return (Color(red: 0.04, green: 0.015, blue: 0.03), Color(red: 0.13, green: 0.05, blue: 0.06),
                    Color(red: 0.95, green: 0.45, blue: 0.3), Color(red: 1.0, green: 0.82, blue: 0.72))
        case .graphite:
            return (Color(red: 0.02, green: 0.02, blue: 0.02), Color(red: 0.07, green: 0.07, blue: 0.08),
                    Color(red: 0.6, green: 0.6, blue: 0.65), Color(red: 0.85, green: 0.85, blue: 0.88))
        }
    }
}
