import AppKit

if let i = CommandLine.arguments.firstIndex(of: "--render-previews") {
    // Geliştirici modu: örnek verilerle arayüz görüntüleri üretir (README için). Kullanıcı verisine dokunmaz.
    let dir = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "docs/screenshots"
    _ = NSApplication.shared
    MainActor.assumeIsolated { PreviewRenderer.run(outputDir: dir) }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
