import AppKit
import SwiftUI

private struct NotchAppearanceKey: EnvironmentKey {
    static let defaultValue = NotchAppearance.classic
}

extension EnvironmentValues {
    var notchAppearance: NotchAppearance {
        get { self[NotchAppearanceKey.self] }
        set { self[NotchAppearanceKey.self] = newValue }
    }
}

struct NotchBackground: View {
    let expanded: Bool
    let glass: Bool
    let reduceTransparency: Bool

    var body: some View {
        let shape = NotchShape(bottomRadius: expanded ? 26 : 10)
        if expanded && glass {
            ZStack {
                if reduceTransparency {
                    shape.fill(Color(white: 0.14))
                } else {
                    NotchBlur()
                    shape.fill(.black.opacity(0.34))
                }

                shape.fill(
                    LinearGradient(colors: [.black.opacity(0.23), .clear],
                                   startPoint: .top, endPoint: .center)
                )
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.23), .white.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
                .clipShape(shape)
            }
        } else {
            shape.fill(.black)
        }
    }
}

private struct NotchBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> BlurView {
        let view = BlurView()
        view.appearance = NSAppearance(named: .darkAqua)
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: BlurView, context: Context) {}

    final class BlurView: NSVisualEffectView {
        override func layout() {
            super.layout()
            let size = bounds.size
            guard size.width > 0, size.height > 0, maskImage?.size != size else { return }
            maskImage = NSImage(size: size, flipped: true) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.addPath(NotchShape(bottomRadius: 26).path(in: rect).cgPath)
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
                return true
            }
        }
    }
}

private struct NotchSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.notchAppearance) private var appearance

    let shape: S
    let classic: Color
    let glass: Color
    let highlighted: Bool

    func body(content: Content) -> some View {
        if appearance == .liquidGlass {
            content.background {
                shape.fill(glass)
                    .overlay {
                        if highlighted {
                            shape.strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.04)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                        }
                    }
            }
        } else {
            content.background(classic, in: shape)
        }
    }
}

extension View {
    func notchSurface<S: InsettableShape>(in shape: S, classic: Color, glass: Color,
                                          highlighted: Bool = true) -> some View {
        modifier(NotchSurface(shape: shape, classic: classic, glass: glass, highlighted: highlighted))
    }
}
