import Foundation

struct ShelfItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var url: URL
    var added = Date()

    var name: String { url.lastPathComponent }
}

/// Dosya rafı: çentiğe bırakılan dosyaların listesi (dosyalar kopyalanmaz, yolları tutulur).
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let fileURL: URL = {
        let base = AppPaths.support
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("shelf.json")
    }()

    init() { load() }

    func add(_ urls: [URL]) {
        var changed = false
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.append(ShelfItem(url: url))
            changed = true
        }
        if changed { save() }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    /// Silinmiş/taşınmış dosyaları listeden düşür.
    func pruneMissing() {
        let before = items.count
        items.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        if items.count != before { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = decoded.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
