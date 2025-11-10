import SwiftUI

// Универсальная стеклянная карточка — обновлена под Liquid Glass
public struct GlassCard<Content: View>: View {
    @ViewBuilder private var content: () -> Content
    @Namespace private var glassNamespace
    @ObservedObject private var overlay = OverlayModel.shared

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                GlassEffectContainer {
                    VStack(spacing: 0) { content() }
                        .padding(16)
                        .background(
                            LiquidGlassDecoration(
                                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                                tint: .accentColor,
                                tintOpacity: 0.26,
                                highlightOpacity: 0.2,
                                rimOpacity: 0.48
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 14)
                        )
                        .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 16))
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
    @ObservedObject private var overlay = OverlayModel.shared
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                LiquidIconButton(configuration: configuration)
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

@available(macOS 26.0, *)
private struct LiquidIconButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 9, style: .continuous) }

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 32, height: 32)
            .symbolVariant(.fill)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white.opacity(0.96), Color.white.opacity(0.36))
            .padding(2)
            .background(
                LiquidGlassDecoration(
                    shape: shape,
                    tint: .accentColor,
                    tintOpacity: 0.32,
                    highlightOpacity: 0.22,
                    rimOpacity: 0.52,
                    isPressed: configuration.isPressed,
                    isHovering: hovering
                )
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.22), radius: hovering ? 22 : 18, x: 0, y: 11)
            )
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 9))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: hovering)
            .onHover { hovering = $0 }
    }
}

// Единый стиль для инпутов (TextField/SecureField)
private struct GlassCapsuleFieldModifier: ViewModifier {
    @ObservedObject private var overlay = OverlayModel.shared

    func body(content: Content) -> some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                content
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.clear, in: .capsule)
            } else {
                content
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

public extension View {
    func glassCapsuleField() -> some View {
        modifier(GlassCapsuleFieldModifier())
    }
}

// Секция формы с однотипным стеклянным фоном
public struct GlassSection<Content: View>: View {
    private let title: String?
    @ViewBuilder private var content: () -> Content
    @Namespace private var glassNamespace
    @ObservedObject private var overlay = OverlayModel.shared

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
                if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                    GlassEffectContainer {
                        VStack(spacing: 12) { content() }
                            .padding(16)
                            .background(
                                LiquidGlassDecoration(
                                    shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                                    tint: .accentColor,
                                    tintOpacity: 0.22,
                                    highlightOpacity: 0.18,
                                    rimOpacity: 0.44
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 12)
                            )
                            .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 12))
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
