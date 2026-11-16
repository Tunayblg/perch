import Foundation

enum AppPaths {
    /// ~/Library/Application Support/Perch
    /// (Eski "NotchPlanner" klasörü varsa verilerle birlikte otomatik taşınır.)
    static let support: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let new = base.appendingPathComponent("Perch", isDirectory: true)
        let old = base.appendingPathComponent("NotchPlanner", isDirectory: true)
        if !fm.fileExists(atPath: new.path), fm.fileExists(atPath: old.path) {
            try? fm.moveItem(at: old, to: new)
        }
        try? fm.createDirectory(at: new, withIntermediateDirectories: true)
        return new
    }()
}
