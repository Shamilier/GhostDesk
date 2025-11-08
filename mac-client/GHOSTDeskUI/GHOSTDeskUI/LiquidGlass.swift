import SwiftUI

/// Encapsulates tint configuration for the custom liquid glass helpers.
struct LiquidGlassTint {
    enum Style {
        case color(Color)
        case gradient(LinearGradient)
    }

    let style: Style
    let opacity: Double

    init(style: Style, opacity: Double) {
        self.style = style
        self.opacity = opacity
    }

    static func color(_ color: Color, opacity: Double) -> LiquidGlassTint {
        LiquidGlassTint(style: .color(color), opacity: opacity)
    }

    static func gradient(_ gradient: LinearGradient, opacity: Double) -> LiquidGlassTint {
        LiquidGlassTint(style: .gradient(gradient), opacity: opacity)
    }
}

private struct LiquidGlassBackgroundModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: S
    let clip: Bool
    let highlightColor: Color
    let highlightOpacity: Double
    let highlightBlur: CGFloat
    let borderGradient: LinearGradient
    let borderWidth: CGFloat
    let tint: LiquidGlassTint?
    let fallbackColor: Color?

    func body(content: Content) -> some View {
        let base = content.background {
            ZStack {
                materialLayer

                if let tint, !reduceTransparency {
                    tintLayer(tint)
                        .allowsHitTesting(false)
                }

                if highlightOpacity > 0 && !reduceTransparency {
                    shape
                        .fill(highlightColor.opacity(highlightOpacity))
                        .blur(radius: highlightBlur)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }

                shape
                    .stroke(borderGradient, lineWidth: borderWidth)
                    .allowsHitTesting(false)
            }
        }

        if clip {
            base.clipShape(shape)
        } else {
            base
        }
    }

    @ViewBuilder
    private var materialLayer: some View {
        if reduceTransparency {
            shape.fill((fallbackColor ?? Color.black.opacity(0.72)))
        } else if #available(macOS 15, *) {
            Color.clear
                .glassBackgroundEffect(in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func tintLayer(_ tint: LiquidGlassTint) -> some View {
        switch tint.style {
        case .color(let color):
            shape.fill(color).opacity(tint.opacity)
        case .gradient(let gradient):
            shape.fill(gradient).opacity(tint.opacity)
        }
    }
}

extension View {
    func liquidGlassBackground<S: InsettableShape>(
        _ shape: S,
        clip: Bool = true,
        highlightColor: Color = .white,
        highlightOpacity: Double = 0.25,
        highlightBlur: CGFloat = 38,
        borderGradient: LinearGradient = .liquidGlassDefaultBorder,
        borderWidth: CGFloat = 1,
        tint: LiquidGlassTint? = nil,
        fallbackColor: Color? = nil
    ) -> some View {
        modifier(
            LiquidGlassBackgroundModifier(
                shape: shape,
                clip: clip,
                highlightColor: highlightColor,
                highlightOpacity: highlightOpacity,
                highlightBlur: highlightBlur,
                borderGradient: borderGradient,
                borderWidth: borderWidth,
                tint: tint,
                fallbackColor: fallbackColor
            )
        )
    }

    @ViewBuilder
    func liquidGlassShadow(
        opacity: Double = 0.16,
        radius: CGFloat = 22,
        y: CGFloat = 12
    ) -> some View {
        if #available(macOS 15, *) {
            self.glassShadow()
        } else {
            self.shadow(color: Color.black.opacity(opacity), radius: radius, y: y)
        }
    }
}

private extension LinearGradient {
    static var liquidGlassDefaultBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.6),
                Color.white.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
