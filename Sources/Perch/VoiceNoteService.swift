import AVFoundation
import AppKit
import Speech

struct VoiceNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var text: String
    var audioFile: String?
    var inNotes = false
}

/// Sesli hızlı not: ses kaydeder, cihaz içinde yazıya çevirir, istenirse Apple Notes'a ekler.
final class VoiceNoteService: ObservableObject {
    @Published private(set) var notes: [VoiceNote] = []
    @Published private(set) var isRecording = false
    @Published private(set) var liveText = ""
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var status: String?
    @Published var autoSaveToNotes: Bool {
        didSet { UserDefaults.standard.set(autoSaveToNotes, forKey: "autoSaveToNotes") }
    }

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var audioURL: URL?
    private var startDate = Date()
    private var clock: Timer?
    private var finalized = false
    private let queue = DispatchQueue(label: "voice.notes.applescript")

    private let folder: URL = {
        let base = AppPaths.support
        try? FileManager.default.createDirectory(at: base.appendingPathComponent("Voice"), withIntermediateDirectories: true)
        return base
    }()
    private var indexURL: URL { folder.appendingPathComponent("voice-notes.json") }

    init() {
        autoSaveToNotes = UserDefaults.standard.object(forKey: "autoSaveToNotes") as? Bool ?? true
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([VoiceNote].self, from: data) {
            notes = decoded
        }
    }

    // MARK: - Kayıt

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        guard !isRecording else { return }
        status = nil
        requestPermissions { [weak self] ok, message in
            guard let self else { return }
            if ok { self.beginRecording() } else { self.status = message }
        }
    }

    private func requestPermissions(_ done: @escaping (Bool, String?) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { micOK in
            SFSpeechRecognizer.requestAuthorization { speech in
                DispatchQueue.main.async {
                    if !micOK {
                        done(false, L("Mikrofon izni yok (Sistem Ayarları → Gizlilik ve Güvenlik → Mikrofon)", "No microphone permission (System Settings → Privacy & Security → Microphone)"))
                    } else if speech != .authorized {
                        done(false, L("Konuşma tanıma izni yok (Sistem Ayarları → Gizlilik ve Güvenlik)", "No speech recognition permission (System Settings → Privacy & Security)"))
                    } else {
                        done(true, nil)
                    }
                }
            }
        }
    }

    private func beginRecording() {
        let localeID = Locale.current.identifier
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
                ?? SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")),
              recognizer.isAvailable else {
            status = L("Konuşma tanıma şu an kullanılamıyor", "Speech recognition is unavailable")
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let url = folder.appendingPathComponent("Voice").appendingPathComponent("\(UUID().uuidString).m4a")
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: 1,
            ])
        } catch {
            status = L("Ses dosyası açılamadı", "Could not open audio file")
            return
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            req.append(buffer)
            try? file.write(from: buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            status = L("Mikrofon başlatılamadı", "Could not start the microphone")
            return
        }

        request = req
        audioURL = url
        finalized = false
        liveText = ""
        elapsed = 0
        startDate = Date()
        isRecording = true
        clock = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed = Date().timeIntervalSince(self.startDate)
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.liveText = result.bestTranscription.formattedString
                    if result.isFinal { self.finalize() }
                } else if error != nil, !self.isRecording {
                    self.finalize()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        clock?.invalidate()
        clock = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // Nihai sonuç gelmezse 3 sn sonra eldeki metinle bitir
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.finalize()
        }
    }

    private func finalize() {
        guard !finalized, !isRecording else { return }
        finalized = true
        task?.cancel()
        task = nil
        request = nil

        let text = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = audioURL
        audioURL = nil
        liveText = ""

        guard !text.isEmpty else {
            if let url { try? FileManager.default.removeItem(at: url) }
            status = L("Ses algılanmadı", "No speech detected")
            return
        }

        let note = VoiceNote(text: text, audioFile: url?.lastPathComponent)
        notes.insert(note, at: 0)
        persist()
        status = nil
        if autoSaveToNotes { saveToAppleNotes(note.id) }
    }

    // MARK: - Liste

    func delete(_ id: UUID) {
        if let n = notes.first(where: { $0.id == id }), let f = n.audioFile {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent("Voice").appendingPathComponent(f))
        }
        notes.removeAll { $0.id == id }
        persist()
    }

    func copy(_ id: UUID) {
        guard let n = notes.first(where: { $0.id == id }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(n.text, forType: .string)
        let msg = L("Kopyalandı", "Copied")
        status = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.status == msg { self?.status = nil }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Apple Notes

    /// Metni Notlar uygulamasına yeni not olarak ekler (iCloud ile iPhone'a senkronlanır).
    func saveToAppleNotes(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: AppSettings.shared.isTurkish ? "tr_TR" : "en_US")
        let title = L("Sesli not", "Voice note") + " – " + formatter.string(from: note.date)

        let html = "<h1>\(Self.htmlEscape(title))</h1><div>"
            + Self.htmlEscape(note.text).replacingOccurrences(of: "\n", with: "<br>")
            + "</div>"
        let script = """
        tell application "Notes"
          make new note with properties {body:"\(Self.appleScriptEscape(html))"}
        end tell
        """
        queue.async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                guard let self else { return }
                if error == nil, let i = self.notes.firstIndex(where: { $0.id == id }) {
                    self.notes[i].inNotes = true
                    self.persist()
                    let msg = L("Notlar'a kaydedildi", "Saved to Notes")
                    self.status = msg
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if self.status == msg { self.status = nil }
                    }
                } else {
                    self.status = L("Notlar'a kaydedilemedi (Otomasyon iznini kontrol et)", "Could not save to Notes (check Automation permission)")
                }
            }
        }
    }

    private static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
