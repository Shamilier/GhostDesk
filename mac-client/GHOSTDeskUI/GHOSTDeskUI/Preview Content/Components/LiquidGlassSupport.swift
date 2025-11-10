import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Liquid Glass Compatibility Layer
// These compatibility helpers allow the project to compile on SDKs that do not yet
// expose the new SwiftUI glass effect APIs introduced on the latest macOS releases.
// When the real APIs are available (Swift 6 / macOS 15 SDK), the declarations below
// are ignored thanks to the Swift version conditional.
#if !swift(>=6.0)
struct GlassEffect {
    struct Style {
        func tint(_ color: Color) -> Style { self }
        func interactive() -> Style { self }
        static var regular: Style { Style() }
    }
}

struct GlassEffectShape {
    static var capsule: GlassEffectShape { GlassEffectShape() }
    static var circle: GlassEffectShape { GlassEffectShape() }
    static func rect(cornerRadius: CGFloat) -> GlassEffectShape { GlassEffectShape() }
}

struct GlassEffectTransition {
    static var matchedGeometry: GlassEffectTransition { GlassEffectTransition() }
}

struct GlassEffectContainer<Content: View>: View {
    private let content: () -> Content

    init(spacing _: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}

extension View {
    func glassEffect(_: GlassEffect.Style, in _: GlassEffectShape) -> some View {
        self
    }

    func glassEffectUnion(id _: String, namespace _: Namespace.ID) -> some View {
        self
    }

    func glassEffectID(_: String, in _: Namespace.ID) -> some View {
        self
    }

    func glassEffectTransition(_: GlassEffectTransition) -> some View {
        self
    }
}
#endif

// MARK: - Liquid Glass Decoration
@available(macOS 13.0, *)
struct LiquidGlassDecoration<S: InsettableShape>: View {
    var shape: S
    var tint: Color?
    var tintOpacity: Double
    var highlightOpacity: Double
    var rimOpacity: Double
    var isPressed: Bool
    var isHovering: Bool

    init(
        shape: S,
        tint: Color? = nil,
        tintOpacity: Double = 0.24,
        highlightOpacity: Double = 0.18,
        rimOpacity: Double = 0.36,
        isPressed: Bool = false,
        isHovering: Bool = false
    ) {
        self.shape = shape
        self.tint = tint
        self.tintOpacity = tintOpacity
        self.highlightOpacity = highlightOpacity
        self.rimOpacity = rimOpacity
        self.isPressed = isPressed
        self.isHovering = isHovering
    }

    private var baseBlur: CGFloat { isPressed ? 18 : 32 }
    private var rimWidth: CGFloat { isHovering ? 1.45 : 1.15 }
    private var accent: Color { tint ?? .accentColor }

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: false)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let wave1 = CGFloat(sin(time * 0.45))
                let wave2 = CGFloat(cos(time * 0.32))
                let hoverBoost = isHovering ? 1.18 : 1.0
                let pressCompression = isPressed ? 0.95 : 1.0

                ZStack {
                    LiquidGlassMaterialView()
                        .clipShape(shape)
                        .saturation(1.08)
                        .brightness(isPressed ? -0.015 : 0)
                        .scaleEffect(y: pressCompression, anchor: .center)

                    shape
                        .fill(accent.opacity(tintOpacity * 0.9))
                        .blur(radius: baseBlur * 1.25)
                        .scaleEffect(x: 1.05, y: 1.12)
                        .offset(y: -6)
                        .blendMode(.plusLighter)
                        .opacity(0.85)

                    Canvas { context, size in
                        context.addFilter(.blur(radius: baseBlur * 0.55))
                        let gradient = Gradient(colors: [
                            accent.opacity(tintOpacity * 1.18),
                            accent.opacity(tintOpacity * 0.38),
                            .clear
                        ])
                        let start = CGPoint(
                            x: size.width * (0.18 + 0.24 * wave1),
                            y: size.height * (isPressed ? 0.08 : 0.12)
                        )
                        let end = CGPoint(
                            x: size.width * (0.82 + 0.2 * wave2),
                            y: size.height * (isPressed ? 0.92 : 0.96)
                        )
                        context.fill(Path(rect), with: .linearGradient(gradient, start: start, end: end))
                    }
                    .clipShape(shape)
                    .blendMode(.plusLighter)
                    .opacity(0.9)

                    Canvas { context, size in
                        let ovalHeight = size.height * (1.28 + 0.08 * wave2)
                        let ovalRect = CGRect(
                            x: -size.width * 0.25 + size.width * 0.35 * wave1,
                            y: -ovalHeight * 0.85,
                            width: size.width * 1.65,
                            height: ovalHeight
                        )
                        context.addFilter(.blur(radius: 22))
                        let gradient = Gradient(colors: [
                            Color.white.opacity(highlightOpacity * hoverBoost * 1.05),
                            Color.white.opacity(0.05)
                        ])
                        context.fill(
                            Path(ellipseIn: ovalRect),
                            with: .radialGradient(
                                gradient,
                                center: CGPoint(x: ovalRect.midX, y: ovalRect.midY),
                                startRadius: 0,
                                endRadius: max(ovalRect.width, ovalRect.height) / 2
                            )
                        )
                    }
                    .clipShape(shape)
                    .blendMode(.screen)

                    shape
                        .strokeBorder(Color.white.opacity(rimOpacity * hoverBoost), lineWidth: rimWidth)
                        .blendMode(.screen)

                    shape
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.05)
                        .blur(radius: 2.4)
                        .offset(y: -1.6)
                        .opacity(0.9)

                    shape
                        .strokeBorder(Color.black.opacity(isPressed ? 0.28 : 0.2), lineWidth: 1.4)
                        .blur(radius: isPressed ? 9 : 12)
                        .offset(y: 3.6)
                        .opacity(0.82)

                    shape
                        .inset(by: 0.9)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1.0)
                        .blendMode(.overlay)

                    LiquidGlassNoiseLayer()
                        .clipShape(shape)
                        .opacity(isPressed ? 0.055 : 0.08)
                        .blendMode(.overlay)
                }
                .compositingGroup()
                .animation(.easeInOut(duration: 0.28), value: isPressed)
                .animation(.easeInOut(duration: 0.32), value: isHovering)
            }
            .frame(width: rect.width, height: rect.height)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Backdrop + Noise helpers
@available(macOS 13.0, *)
private struct LiquidGlassMaterialView: View {
    var body: some View {
        LiquidGlassVisualEffectRepresentable()
            .overlay(Color.white.opacity(0.04).blendMode(.screen))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

@available(macOS 13.0, *)
private struct LiquidGlassVisualEffectRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = AlwaysActiveVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.state = .active
        view.material = .hudWindow
        view.blendingMode = .withinWindow
        view.isEmphasized = true
        view.wantsLayer = true
        view.layer?.masksToBounds = true
    }
}

@available(macOS 13.0, *)
private final class AlwaysActiveVisualEffectView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        state = .active
        material = .hudWindow
        blendingMode = .withinWindow
        isEmphasized = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        state = .active
        material = .hudWindow
        blendingMode = .withinWindow
        isEmphasized = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        state = .active
        isEmphasized = true
    }
}

@available(macOS 13.0, *)
private struct LiquidGlassNoiseLayer: View {
    private static let texture: Image = {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let filter = CIFilter.randomGenerator()
        let size: CGFloat = 512
        let extent = CGRect(x: 0, y: 0, width: size, height: size)
        if let output = filter.outputImage?.cropped(to: extent),
           let cgImage = context.createCGImage(output, from: extent) {
            return Image(decorative: cgImage, scale: 1, orientation: .up)
        }
        return Image(systemName: "square.fill")
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let offsetX = CGFloat(sin(t * 0.36)) * 12
            let offsetY = CGFloat(cos(t * 0.28)) * 12

            LiquidGlassNoiseLayer.texture
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .scaleEffect(1.05)
                .offset(x: offsetX, y: offsetY)
        }
    }
}
