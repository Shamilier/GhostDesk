import SwiftUI

public extension View {
    func glassCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(12)
            .liquidGlassBackground(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                highlightOpacity: 0.26,
                highlightBlur: 44,
                fallbackColor: Color.black.opacity(0.72)
            )
    }

    @ViewBuilder
    func glassReadable() -> some View {
        if #available(macOS 15, *) {
            self.glassMaterialOverlay()
        } else {
            self
        }
    }

    func glassLifted() -> some View {
        self.liquidGlassShadow()
    }
}

// Универсальная стеклянная карточка — как в OverlayRootView
public struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    public var body: some View {
        VStack(spacing: 0) { content() }
            .glassCardStyle(cornerRadius: 16)
    }
}

// Кнопка-иконка (как в AIResponseCard)
public struct MiniIconButton: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        let label = configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .frame(width: 28, height: 28)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)

        return label
            .liquidGlassBackground(
                shape,
                highlightOpacity: 0.18,
                highlightBlur: 30,
                tint: .color(Color.white, opacity: 0.10),
                fallbackColor: Color.black.opacity(0.65)
            )
            .glassLifted()
    }
}

// Единый стиль для инпутов (TextField/SecureField)
public extension View {
    func glassCapsuleField() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlassBackground(
                Capsule(style: .continuous),
                highlightOpacity: 0.16,
                highlightBlur: 30,
                tint: .color(Color.white, opacity: 0.08),
                fallbackColor: Color.black.opacity(0.65)
            )
    }
}

// Секция формы с однотипным стеклянным фоном
public struct GlassSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content
    public init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.content = content
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            VStack(spacing: 12) { content() }
                .padding(12)
                .liquidGlassBackground(
                    RoundedRectangle(cornerRadius: 12, style: .continuous),
                    highlightOpacity: 0.18,
                    highlightBlur: 34,
                    tint: .color(Color.white, opacity: 0.09),
                    fallbackColor: Color.black.opacity(0.65)
                )
        }
    }
}
