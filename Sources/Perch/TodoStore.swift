import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var created = Date()
}

/// Yapılacaklar listesi. ~/Library/Application Support/Perch/todos.json içinde saklanır.
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let fileURL: URL = {
        let base = AppPaths.support
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("todos.json")
    }()

    init() { load() }

    /// Önce bitmemişler (eskiden yeniye), sonra tamamlananlar.
    var sorted: [TodoItem] {
        items.filter { !$0.done } + items.filter { $0.done }
    }

    var openCount: Int { items.filter { !$0.done }.count }

    func add(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.append(TodoItem(title: t))
        save()
    }

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done.toggle()
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearDone() {
        items.removeAll { $0.done }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
