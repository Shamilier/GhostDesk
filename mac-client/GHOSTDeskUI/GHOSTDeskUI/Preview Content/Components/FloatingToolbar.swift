import SwiftUI
import AppKit

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
    @ObservedObject private var overlay = OverlayModel.shared

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
        .onPreferenceChange(ToolbarAnchorPreferenceKey.self) { anchors in
            overlay.updateToolbarAnchors(anchors)
        }
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
        let activeAnchor = overlay.activeTutorialAnchorID
        let toolbarContent = HStack(spacing: 10) {
            // logo
            ToolbarLogo(glassNamespace: glassNamespace)

            TabSwitcher(
                selected: $selected,
                isRecording: isRecording,
                onTabTap: { onPrimaryTap() },
                glassNamespace: glassNamespace,
                activeTutorialAnchorID: activeAnchor
            )


            let eyeIsHighlighted = overlay.isTutorialVisible && activeAnchor == .eye
            KeyedIconButton(
                system: "eye",
                key: "⌘E",
                glassNamespace: glassNamespace,
                isActiveInTutorial: eyeIsHighlighted,
                action: onEyeTap
            )
            .tutorialHighlight(active: eyeIsHighlighted, shape: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(ToolbarAnchorReporter(id: .eye))

            let menuIsHighlighted = overlay.isTutorialVisible && activeAnchor == .menu
            Button(action: onMenuTap) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(MiniIconButton())
            .tutorialHighlight(active: menuIsHighlighted, shape: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background(ToolbarAnchorReporter(id: .menu))

        }
        let toolbarShell = Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 10) {
                    toolbarContent
                        .frame(height: 48)
                        .padding(.horizontal, 14)
                        .glassEffect(.clear, in: .capsule)
                        .overlay(
                          Capsule().stroke(
                            LinearGradient(
                              colors: [Color.white.opacity(0.35), Color.white.opacity(0.10)],
                              startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                          )
                          .blendMode(.screen)
                        )
                        .overlay(
                          Capsule().inset(by: 1.5)
                            .stroke(Color.white.opacity(0.40), lineWidth: 0.6)
                            .blur(radius: 1.0)
                            .opacity(0.7)
                            .blendMode(.screen)
                        )


                        .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
                        .glassEffectID("toolbar.shell", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
                        .overlay(
                          Capsule()
                            .fill(LinearGradient(
                              colors: [Color.indigo.opacity(0.25), Color.purple.opacity(0.18)],
                              startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .blendMode(.softLight)
                            .opacity(0.02)              // ← общая прозрачность слоя ≈ невидимо
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        )


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
        ZStack {
            toolbarShell
            if overlay.isTutorialVisible {
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.28), value: overlay.isTutorialVisible)
        .frame(maxWidth: 560)
        .background(ToolbarAnchorReporter(id: .shell))
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
                    .frame(width: 28, height: 28)
                    .glassEffect(.clear, in: .circle)
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
    var activeTutorialAnchorID: OverlayModel.ToolbarAnchorID?

    private let tabWidth:  CGFloat = 82
    private let tabHeight: CGFloat = 28

    @Namespace private var ns
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        HStack(spacing: 8) {
            TabChip(title: "Listen", icon: "waveform",
                    isActive: selected == .listen,
                    isActiveInTutorial: overlay.isTutorialVisible && activeTutorialAnchorID == .listen,
                    ns: ns,
                    glassNamespace: glassNamespace) {
                selected = .listen
                onTabTap()
            }
            .frame(width: tabWidth, height: tabHeight)
            .background(ToolbarAnchorReporter(id: .listen))

            TabChip(title: "Ask", icon: "bubble.right",
                    isActive: selected == .ask,
                    isActiveInTutorial: overlay.isTutorialVisible && activeTutorialAnchorID == .ask,
                    ns: ns,
                    glassNamespace: glassNamespace) {
                selected = .ask
                onTabTap()
            }
            .frame(width: tabWidth, height: tabHeight)
            .background(ToolbarAnchorReporter(id: .ask))
        }
    }
}

// MARK: - Anchors for tutorial overlay

private struct ToolbarAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [OverlayModel.ToolbarAnchor] = []

    static func reduce(value: inout [OverlayModel.ToolbarAnchor], nextValue: () -> [OverlayModel.ToolbarAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

private struct ToolbarAnchorReporter: View {
    let id: OverlayModel.ToolbarAnchorID

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ToolbarAnchorPreferenceKey.self, value: [
                OverlayModel.ToolbarAnchor(id: id, frameInScreen: frameInScreen(proxy))
            ])
        }
    }

    private func frameInScreen(_ proxy: GeometryProxy) -> CGRect {
        // В SwiftUI `.global` возвращает координаты относительно окна панели (origin вверху слева).
        // Для туториала нужны реальные screen-координаты AppKit (origin внизу слева), поэтому
        // добавляем origin окна и переворачиваем ось Y по высоте окна.
        let frameInWindow = proxy.frame(in: .global)

        guard let window = NSApplication.shared.windows.first(where: { $0 is OverlayPanel }) else {
            return frameInWindow
        }

        let windowFrame = window.frame
        let screenOrigin = CGPoint(
            x: windowFrame.origin.x + frameInWindow.minX,
            y: windowFrame.origin.y + (windowFrame.height - frameInWindow.maxY)
        )

        return CGRect(origin: screenOrigin, size: frameInWindow.size)
    }
}








private struct TabChip: View {
    var title: String
    var icon: String
    var isActive: Bool
    var isActiveInTutorial: Bool
    var ns: Namespace.ID
    var glassNamespace: Namespace.ID
    var onTap: () -> Void
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        Button(action: onTap) {
            Group {
                if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(title)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(
                        isActive ? .regular.tint(.accentColor).interactive() : .clear,
                        in: .capsule
                    )
                    .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
                    .glassEffectID("toolbar.tab.\(title)", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                } else {
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
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .tutorialHighlight(active: isActiveInTutorial, shape: Capsule())
    }
}


                                  
                                  
// MARK: - Правые иконки с «клавишей»
private struct KeyedIconButton: View {
    var system: String
    var key: String
    var glassNamespace: Namespace.ID
    var isActiveInTutorial: Bool
    var action: () -> Void
    @ObservedObject private var overlay = OverlayModel.shared

    var body: some View {
        Button(action: action) {
            Group {
                if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                    HStack(spacing: 6) {
                        Image(systemName: system)
                            .font(.system(size: 13, weight: .semibold))
                        if !key.isEmpty {
                            KeyPill(text: key)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .glassEffect(.clear, in: .rect(cornerRadius: 8))
                    .glassEffectUnion(id: "toolbar.shell", namespace: glassNamespace)
                    .glassEffectID("toolbar.button.\(system)", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: system)
                            .font(.system(size: 13, weight: .semibold))
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
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 0.5))
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .tutorialHighlight(active: isActiveInTutorial, shape: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .glassEffect(.clear, in: .rect(cornerRadius: 4))
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

// MARK: - Tutorial highlight modifier

private struct TutorialHighlightModifier<S: Shape>: ViewModifier {
    var isActive: Bool
    var shape: S

    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .brightness(isActive ? 0.08 : 0)
            .scaleEffect(isActive ? 1.02 : 1.0)
            .overlay(alignment: .center) {
                if isActive {
                    shape
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay(shape.stroke(Color.accentColor.opacity(0.9), lineWidth: 1.1))
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 6)
                        .shadow(color: Color.accentColor.opacity(0.5), radius: 18)
                        .scaleEffect(pulse ? 1.015 : 0.985)
                        .opacity(pulse ? 1 : 0.95)
                        .onAppear { pulse = true }
                        .onDisappear { pulse = false }
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
    }
}

private extension View {
    func tutorialHighlight<S: Shape>(active: Bool, shape: S) -> some View {
        modifier(TutorialHighlightModifier(isActive: active, shape: shape))
    }
}
