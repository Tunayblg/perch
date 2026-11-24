import Foundation
import SwiftUI

/// Claude Code gibi yapay zekâ araçlarının durumunu çentikte gösterir. Araçların hook'ları
/// `~/.perch/ai/claude` dosyasına `working`, `waiting` ya da `done` yazar; biz de dosyayı izleriz.
final class AIStatusService: ObservableObject {
    enum State: Equatable { case idle, working, waiting, done }

    @Published private(set) var state: State = .idle

    static let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".perch/ai")
    private let file = AIStatusService.directory.appendingPathComponent("claude")
    private var source: DispatchSourceFileSystemObject?
    private var clearWork: DispatchWorkItem?

    init(watching: Bool = true) {
        guard watching else { return }
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let fd = open(Self.directory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend], queue: .main)
        src.setEventHandler { [weak self] in self?.read() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    deinit { source?.cancel() }

    /// Önizleme/test için durumu doğrudan ayarlar.
    func set(_ new: State) {
        clearWork?.cancel()
        state = new
        // Bitti simgesi birkaç saniye görünüp kaybolur; takılı kalan "çalışıyor" da bir süre sonra düşer.
        let lifetime: TimeInterval
        switch new {
        case .idle: return
        case .done: lifetime = 8
        case .waiting: lifetime = 120
        case .working: lifetime = 600
        }
        let work = DispatchWorkItem { [weak self] in self?.state = .idle }
        clearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime, execute: work)
    }

    private func read() {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return }
        // Eski dosyayı yeni olay sanma: yalnızca son dakika içinde yazılmışsa göster.
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let modified, Date().timeIntervalSince(modified) < 60 else { return }
        switch text.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "working": set(.working)
        case "waiting": set(.waiting)
        case "done": set(.done)
        default: break
        }
    }
}

/// Claude Code'un ayar dosyasına Perch hook'larını ekler (kullanıcı Ayarlar'dan isteyince).
enum ClaudeHookInstaller {
    private static let marker = ".perch/ai/claude"

    private static func command(_ state: String) -> String {
        "mkdir -p ~/.perch/ai && printf \(state) > ~/.perch/ai/claude.tmp && mv -f ~/.perch/ai/claude.tmp ~/.perch/ai/claude"
    }

    private static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static var isInstalled: Bool {
        guard let data = try? Data(contentsOf: settingsURL), let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains(marker)
    }

    /// Başarıda nil, hatada açıklama döner. Önce yedek alır; mevcut hook'lara dokunmaz.
    static func install() -> String? {
        let fm = FileManager.default
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL), !data.isEmpty {
            guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return L("settings.json okunamadı.", "Could not read settings.json.")
            }
            root = obj
            try? data.write(to: settingsURL.appendingPathExtension("perch-backup"))
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let events = ["UserPromptSubmit": "working", "Notification": "waiting", "Stop": "done"]
        for (event, state) in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            let entry: [String: Any] = ["type": "command", "command": command(state)]
            groups.append(["hooks": [entry]])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        do {
            try fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try out.write(to: settingsURL, options: .atomic)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

/// Claude'un turuncu yıldız işareti (basit çizim).
struct ClaudeMark: View {
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .frame(width: size * 0.14, height: size * 0.5)
                    .offset(y: -size * 0.25)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
    }
}
