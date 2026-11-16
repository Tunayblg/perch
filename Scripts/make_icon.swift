// Kullanım: swift Scripts/make_icon.swift  → Resources/AppIcon.icns üretir
import AppKit

func draw(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size) / 1024
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    // Zemin: koyu gradyanlı yuvarlak kare
    let bg = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 210, yRadius: 210)
    NSGradient(colors: [NSColor(red: 0.20, green: 0.22, blue: 0.34, alpha: 1),
                        NSColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1)])!
        .draw(in: bg, angle: -90)

    // Çentik: üstten sarkan siyah kapsül
    let notch = NSBezierPath()
    let nx: CGFloat = 232, nw: CGFloat = 560, nTop: CGFloat = 984, nh: CGFloat = 190, r: CGFloat = 70
    notch.move(to: NSPoint(x: nx, y: nTop))
    notch.line(to: NSPoint(x: nx + nw, y: nTop))
    notch.line(to: NSPoint(x: nx + nw, y: nTop - nh + r))
    notch.appendArc(withCenter: NSPoint(x: nx + nw - r, y: nTop - nh + r), radius: r, startAngle: 0, endAngle: -90, clockwise: true)
    notch.line(to: NSPoint(x: nx + r, y: nTop - nh))
    notch.appendArc(withCenter: NSPoint(x: nx + r, y: nTop - nh + r), radius: r, startAngle: 270, endAngle: 180, clockwise: true)
    notch.close()
    NSColor.black.setFill()
    notch.fill()

    // Ses çubukları (müzik) + zaman halkası (plan)
    NSColor.white.setFill()
    let heights: [CGFloat] = [150, 270, 200, 320, 170]
    for (i, h) in heights.enumerated() {
        let x = 232 + CGFloat(i) * 70
        NSBezierPath(roundedRect: NSRect(x: x, y: 300, width: 44, height: h), xRadius: 22, yRadius: 22).fill()
    }
    NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 622, y: 300, width: 150, height: 150))
    ring.lineWidth = 26
    ring.stroke()
    let hand = NSBezierPath()
    hand.move(to: NSPoint(x: 697, y: 375))
    hand.line(to: NSPoint(x: 697, y: 430))
    hand.line(to: NSPoint(x: 735, y: 395))
    hand.lineWidth = 20
    hand.lineCapStyle = .round
    hand.lineJoinStyle = .round
    hand.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = "build/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
                   ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
                   ("512x512", 512), ("512x512@2x", 1024)] {
    try draw(size: px).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(name).png"))
}
print("iconset hazır")
