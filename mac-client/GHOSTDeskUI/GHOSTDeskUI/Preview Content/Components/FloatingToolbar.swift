import SwiftUI

// MARK: - Tabs (переименовано, чтобы не конфликтовало)
//public enum CommandTab: String, CaseIterable {
//    case listen = "Listen"
//    case ask    = "Ask"
//    case settings = ""
//}

// MARK: - Публичная оболочка с прежним API
public struct FloatingToolbar: View {
    public var isRecording: Bool
    @Binding public var selected: CommandTab
    public var onPrimaryTap: () -> Void
    public var onEyeTap: () -> Void
    public var onMenuTap: () -> Void
    @Namespace private var toolbarGlassNamespace

    public init(
        isRecording: Bool,
        selected: Binding<CommandTab>,
        onPrimaryTap: @escaping () -> Void,
        onEyeTap: @escaping () -> Void,
        onMenuTap: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self._selected   = selected
        self.onPrimaryTap = onPrimaryTap
        self.onEyeTap     = onEyeTap
        self.onMenuTap    = onMenuTap
    }

    public var body: some View {
        CommandBar(
            isRecording: isRecording,
            selected: $selected,
            glassNamespace: toolbarGlassNamespace,
            onPrimaryTap: onPrimaryTap,
            onEyeTap: onEyeTap,
            onMenuTap: onMenuTap
        )
        .frame(maxWidth: 560)
    }
}

private struct CommandBar: View {
    var isRecording: Bool
    @Binding var selected: CommandTab
    var glassNamespace: Namespace.ID
    var onPrimaryTap: () -> Void    // оставим сигнатуру, но не используем
    var onEyeTap: () -> Void
    var onMenuTap: () -> Void
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        let toolbarContent = HStack(spacing: 10) {
            // logo
            ToolbarLogo(glassNamespace: glassNamespace)

            TabSwitcher(
                selected: $selected,
                isRecording: isRecording,
                onTabTap: { onPrimaryTap() },
                glassNamespace: glassNamespace
            )


            KeyedIconButton(title: "Show/Hide", system: "eye", key: "⌘E", glassNamespace: glassNamespace, action: onEyeTap)
            Button(action: onMenuTap) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(MiniIconButton())

        }
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 10) {
                    toolbarContent
                        .frame(height: 54)
                        .padding(.horizontal, 20)
                        .background(
                            LiquidGlassDecoration(
                                shape: Capsule(),
                                tint: Color.accentColor,
                                tintOpacity: 0.24,
                                highlightOpacity: 0.2,
                                rimOpacity: 0.5
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 16)
                        )
                        .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
                        .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
                        .glassEffectID("toolbar.shell", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                }
            } else {
                toolbarContent
                    .frame(height: 44)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.18)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                    )
            }
        }
        .frame(maxWidth: 560)
    }
}

private struct ToolbarLogo: View {
    var glassNamespace: Namespace.ID
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(
                        LiquidGlassDecoration(
                            shape: Circle(),
                            tint: Color.accentColor,
                            tintOpacity: 0.34,
                            highlightOpacity: 0.22,
                            rimOpacity: 0.52
                        )
                        .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 10)
                    )
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                    .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
                    .glassEffectID("toolbar.logo", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                    .foregroundStyle(Color.accentColor)
            } else {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.75))
            }
        }
    }
}





private struct TabSwitcher: View {
    @Binding var selected: CommandTab
    var isRecording: Bool
    var onTabTap: () -> Void
    var glassNamespace: Namespace.ID
    @ObservedObject private var overlay = OverlayModel.shared

    private let tabWidth:  CGFloat = 82
    private let tabHeight: CGFloat = 28

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 8) {
            TabChip(title: "Listen", icon: "waveform",
                    isActive: selected == .listen,
                    ns: ns,
                    glassNamespace: glassNamespace) {
                selected = .listen
                onTabTap()
            }
            .frame(width: overlay.usesLiquidGlass ? nil : tabWidth,
                   height: overlay.usesLiquidGlass ? nil : tabHeight)

            TabChip(title: "Ask", icon: "bubble.right",
                    isActive: selected == .ask,
                    ns: ns,
                    glassNamespace: glassNamespace) {
                selected = .ask
                onTabTap()
            }
            .frame(width: overlay.usesLiquidGlass ? nil : tabWidth,
                   height: overlay.usesLiquidGlass ? nil : tabHeight)
        }
    }
}





private struct TabChip: View {
    var title: String
    var icon: String
    var isActive: Bool
    var ns: Namespace.ID
    var glassNamespace: Namespace.ID
    var onTap: () -> Void
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(title)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(
                LiquidTabButtonStyle(
                    title: title,
                    isActive: isActive,
                    glassNamespace: glassNamespace
                )
            )
        } else {
            Button(action: onTap) {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .matchedGeometryEffect(id: "tabHilite", in: ns)
                            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(title)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
        }
    }
}

@available(macOS 26.0, *)
private struct LiquidTabButtonStyle: ButtonStyle {
    var title: String
    var isActive: Bool
    var glassNamespace: Namespace.ID

    func makeBody(configuration: Configuration) -> some View {
        LiquidTabButtonBody(
            configuration: configuration,
            title: title,
            isActive: isActive,
            glassNamespace: glassNamespace
        )
    }
}

@available(macOS 26.0, *)
private struct LiquidTabButtonBody: View {
    let configuration: ButtonStyle.Configuration
    var title: String
    var isActive: Bool
    var glassNamespace: Namespace.ID
    @State private var hovering = false

    private var shape: Capsule { Capsule() }

    private var tintOpacity: Double { isActive ? 0.38 : 0.2 }
    private var highlightOpacity: Double { isActive ? 0.22 : 0.16 }
    private var rimOpacity: Double { isActive ? 0.56 : 0.42 }

    var body: some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                LiquidGlassDecoration(
                    shape: shape,
                    tint: Color.accentColor,
                    tintOpacity: tintOpacity,
                    highlightOpacity: highlightOpacity,
                    rimOpacity: rimOpacity,
                    isPressed: configuration.isPressed,
                    isHovering: hovering
                )
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.2), radius: hovering ? 24 : 18, x: 0, y: 12)
            )
            .glassEffect((isActive ? GlassEffect.Style.regular.tint(Color.accentColor).interactive() : .regular), in: .capsule)
            .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
            .glassEffectID("toolbar.tab.\(title)", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: hovering)
            .onHover { hovering = $0 }
    }
}


                                  
                                  
// MARK: - Правые иконки с «клавишей»
private struct KeyedIconButton: View {
    var title: String
    var system: String
    var key: String
    var glassNamespace: Namespace.ID
    var action: () -> Void
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                LiquidKeyButton(
                    title: title,
                    system: system,
                    key: key,
                    glassNamespace: glassNamespace,
                    action: action
                )
            } else {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: system)
                            .font(.system(size: 13, weight: .semibold))
                        if !title.isEmpty {
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        if !key.isEmpty {
                            Text(key)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(.thinMaterial)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.25), lineWidth: 0.5))
                                )
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

@available(macOS 26.0, *)
private struct LiquidKeyButton: View {
    var title: String
    var system: String
    var key: String
    var glassNamespace: Namespace.ID
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: system)
                    .font(.system(size: 13, weight: .semibold))
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                }
                if !key.isEmpty {
                    KeyPill(text: key)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(LiquidKeyButtonStyle(glassNamespace: glassNamespace, system: system))
    }
}

@available(macOS 26.0, *)
private struct LiquidKeyButtonStyle: ButtonStyle {
    var glassNamespace: Namespace.ID
    var system: String

    func makeBody(configuration: Configuration) -> some View {
        LiquidKeyButtonBody(
            configuration: configuration,
            glassNamespace: glassNamespace,
            system: system
        )
    }
}

@available(macOS 26.0, *)
private struct LiquidKeyButtonBody: View {
    let configuration: ButtonStyle.Configuration
    var glassNamespace: Namespace.ID
    var system: String
    @State private var hovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 11, style: .continuous) }

    var body: some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                LiquidGlassDecoration(
                    shape: shape,
                    tint: Color.accentColor,
                    tintOpacity: 0.24,
                    highlightOpacity: 0.2,
                    rimOpacity: 0.5,
                    isPressed: configuration.isPressed,
                    isHovering: hovering
                )
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.22), radius: hovering ? 24 : 18, x: 0, y: 12)
            )
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 11))
            .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
            .glassEffectID("toolbar.button.\(system)", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: hovering)
            .onHover { hovering = $0 }
    }
}


private struct KeyPill: View {
    var text: String
    @ObservedObject private var overlay = OverlayModel.shared
    var body: some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                Text(text)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        LiquidGlassDecoration(
                            shape: RoundedRectangle(cornerRadius: 5, style: .continuous),
                            tint: Color.accentColor,
                            tintOpacity: 0.28,
                            highlightOpacity: 0.22,
                            rimOpacity: 0.52
                        )
                    )
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 5))
            } else {
                Text(text)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
                            )
                    )
            }
        }
    }
}




// MARK: - Пульсирующая точка записи
private struct PulseDot: View {
    @State private var anim = false
    var body: some View {
        ZStack {
            Circle().fill(Color.red).frame(width: 8, height: 8)
            Circle().stroke(Color.red.opacity(0.6), lineWidth: 2)
                .frame(width: 8, height: 8)
                .scaleEffect(anim ? 2.2 : 1.0)
                .opacity(anim ? 0.0 : 0.8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                anim = true
            }
        }
    }
}
