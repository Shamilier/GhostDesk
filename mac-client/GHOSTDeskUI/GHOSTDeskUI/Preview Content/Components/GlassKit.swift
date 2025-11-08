import SwiftUI

public extension View {
    @ViewBuilder
    func glassCardStyle(cornerRadius: CGFloat = 16) -> some View {
        if #available(macOS 15, *) {
            self
                .padding(12)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .glassBorder()
                .glassContentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(
                        shape.stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                self.padding(12)
            }
            .clipShape(shape)
            .contentShape(shape)
        }
    }

    @ViewBuilder
    func glassReadable() -> some View {
        if #available(macOS 15, *) {
            self.glassMaterialOverlay()
        } else {
            self
        }
    }

    @ViewBuilder
    func glassLifted() -> some View {
        if #available(macOS 15, *) {
            self.glassShadow()
        } else {
            self.shadow(color: .black.opacity(0.10), radius: 6, y: 2)
        }
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

        return Group {
            if #available(macOS 15, *) {
                label
                    .glassBackgroundEffect(in: shape)
                    .glassBorder()
                    .glassContentShape(shape)
                    .glassLifted()
            } else {
                label
                    .background(
                        shape
                            .fill(.thinMaterial)
                            .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.75))
                    )
            }
        }
    }
}

// Единый стиль для инпутов (TextField/SecureField)
public extension View {
    func glassCapsuleField() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
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
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                )
        }
    }
}
