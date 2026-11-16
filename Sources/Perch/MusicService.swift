import AppKit
import Foundation

/// Spotify ve Apple Music'ten şu an çalan bilgiyi AppleScript ile okur.
/// (macOS 15.4+ MediaRemote kısıtlandığı için ilk sürümde bu yol seçildi;
/// ileride mediaremote-adapter ile tüm uygulamalar desteklenebilir.)
final class MusicService: ObservableObject {
    enum Source: String {
        case spotify = "Spotify"
        case music = "Music"

        var bundleID: String {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            }
        }
    }

    @Published var hasTrack = false
    @Published var isPlaying = false
    @Published var title = ""
    @Published var artist = ""
    @Published var artworkURL: URL?
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var sourceName = ""

    private var source: Source?
    private let queue = DispatchQueue(label: "music.applescript")
    private var timer: Timer?
    private var pollCount = 0
    /// İlerleme çubuğunu gösteren görünüm sayısı (panel/gizlilik ekranı). 0 iken ilerleme güncellenmez.
    private(set) var progressObservers = 0

    func beginProgress() {
        progressObservers += 1
        refreshNow()
    }

    func endProgress() {
        progressObservers = max(progressObservers - 1, 0)
    }

    func start() {
        refreshNow()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pollCount += 1
            // Çalarken saniyede bir (ilerleme çubuğu için), değilken 3 sn'de bir
            if (self.isPlaying && self.progressObservers > 0) || self.pollCount % 3 == 0 { self.refreshNow() }
        }
        timer?.tolerance = 0.3
    }

    func refreshNow() {
        queue.async { [weak self] in
            guard let self else { return }
            let results = [Source.spotify, .music].compactMap { self.query($0) }
            let best = results.first { $0.playing } ?? results.first
            DispatchQueue.main.async { self.apply(best) }
        }
    }

    // MARK: - Kontroller

    func togglePlayPause() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }

    private func command(_ cmd: String) {
        guard let source else { return }
        queue.async { [weak self] in
            _ = Self.run("tell application \"\(source.rawValue)\" to \(cmd)")
            self?.refreshNow()
        }
    }

    // MARK: - Okuma

    private struct Info {
        let source: Source
        let playing: Bool
        let title: String
        let artist: String
        let position: Double
        let duration: Double
        let artwork: URL?
    }

    private func isRunning(_ s: Source) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: s.bundleID).first != nil
    }

    private func query(_ s: Source) -> Info? {
        guard isRunning(s) else { return nil }
        let script: String
        switch s {
        case .spotify:
            script = """
            tell application "Spotify"
              if player state is stopped then return "stopped"
              set t to current track
              return (player state as string) & "||" & (name of t) & "||" & (artist of t) & "||" & ((player position) as integer) & "||" & (((duration of t) / 1000) as integer) & "||" & (artwork url of t)
            end tell
            """
        case .music:
            script = """
            tell application "Music"
              if player state is stopped then return "stopped"
              set t to current track
              return (player state as string) & "||" & (name of t) & "||" & (artist of t) & "||" & ((player position) as integer) & "||" & ((duration of t) as integer) & "||" & ""
            end tell
            """
        }
        guard let out = Self.run(script), out != "stopped" else { return nil }
        let p = out.components(separatedBy: "||")
        guard p.count >= 6 else { return nil }
        return Info(
            source: s,
            playing: p[0] == "playing",
            title: p[1],
            artist: p[2],
            position: Double(p[3]) ?? 0,
            duration: Double(p[4]) ?? 0,
            artwork: URL(string: p[5])
        )
    }

    private func apply(_ info: Info?) {
        guard let info else {
            hasTrack = false
            isPlaying = false
            source = nil
            return
        }
        let trackChanged = title != info.title
        source = info.source
        sourceName = info.source.rawValue
        hasTrack = true
        isPlaying = info.playing
        title = info.title
        artist = info.artist
        // İlerleme yalnızca görünürken ya da parça değişince güncellenir (kapalı çentikte gereksiz çizim olmasın)
        if progressObservers > 0 || trackChanged {
            position = info.position
            duration = info.duration
        }
        if artworkURL != info.artwork { artworkURL = info.artwork }
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
