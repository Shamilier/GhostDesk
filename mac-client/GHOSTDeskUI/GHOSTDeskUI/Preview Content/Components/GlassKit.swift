import SwiftUI

// Универсальная стеклянная карточка — обновлена под Liquid Glass
public struct GlassCard<Content: View>: View {
    @ViewBuilder private var content: () -> Content
    @Namespace private var glassNamespace

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer {
                    VStack(spacing: 0) { content() }
                        .padding(12)
                        .glassEffect(.clear, in: .rect(cornerRadius: 16))
                        .glassEffectUnion(id: "card", namespace: glassNamespace)
                        .glassEffectID("card.surface", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                }
            } else {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial, in: shape)
                        .overlay(
                            shape.stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.12)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        )

                    VStack(spacing: 0) { content() }
                        .padding(12)
                }
                .clipShape(shape)
                .contentShape(shape)
            }
        }
    }
}

// Кнопка-иконка (как в AIResponseCard)
public struct MiniIconButton: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                configuration.label
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .glassEffect(.clear, in: .rect(cornerRadius: 7))
                    .scaleEffect(configuration.isPressed ? 0.94 : 1)
            } else {
                configuration.label
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(.white.opacity(0.18), lineWidth: 0.75)
                            )
                    )
                    .scaleEffect(configuration.isPressed ? 0.96 : 1)
            }
        }
    }
}

// Единый стиль для инпутов (TextField/SecureField)
public extension View {
    func glassCapsuleField() -> some View {
        Group {
            if #available(macOS 26.0, *) {
                self
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.clear, in: .capsule)
            } else {
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
    }
}

// Секция формы с однотипным стеклянным фоном
public struct GlassSection<Content: View>: View {
    private let title: String?
    @ViewBuilder private var content: () -> Content
    @Namespace private var glassNamespace

    public init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Group {
                if #available(macOS 26.0, *) {
                    GlassEffectContainer {
                        VStack(spacing: 12) { content() }
                            .padding(12)
                            .glassEffect(.clear, in: .rect(cornerRadius: 12))
                            .glassEffectUnion(id: "section", namespace: glassNamespace)
                            .glassEffectID("section.surface", in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                    }
                } else {
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
    }
}
