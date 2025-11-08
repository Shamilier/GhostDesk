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
    var onPrimaryTap: () -> Void    // оставим сигнатуру, но не используем
    var onEyeTap: () -> Void
    var onMenuTap: () -> Void

    var body: some View {
        let capsule = Capsule(style: .continuous)

        let bar = HStack(spacing: 10) {
            ZStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 28, height: 28)
            .liquidGlassBackground(
                Circle(),
                highlightColor: Color.accentColor,
                highlightOpacity: 0.32,
                highlightBlur: 42,
                borderGradient: LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.75),
                        Color.accentColor.opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                tint: .gradient(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.45),
                            Color.accentColor.opacity(0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    opacity: 1
                ),
                fallbackColor: Color.accentColor.opacity(0.6)
            )
            .glassLifted()

            TabSwitcher(
                selected: $selected,
                isRecording: isRecording,
                onTabTap: { onPrimaryTap() }
            )

            KeyedIconButton(system: "eye", key: "⌘E", action: onEyeTap)

            Button(action: onMenuTap) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(MiniIconButton())
        }
        .frame(height: 44)
        .padding(.horizontal, 12)

        return bar
            .liquidGlassBackground(
                capsule,
                highlightOpacity: 0.24,
                highlightBlur: 52,
                tint: .gradient(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    opacity: 0.9
                ),
                fallbackColor: Color.black.opacity(0.7)
            )
            .glassLifted()
            .frame(maxWidth: 560)
    }
}





private struct TabSwitcher: View {
    @Binding var selected: CommandTab
    var isRecording: Bool
    var onTabTap: () -> Void

    private let tabWidth:  CGFloat = 82
    private let tabHeight: CGFloat = 28

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 8) {
            TabChip(title: "Listen", icon: "waveform",
                    isActive: selected == .listen, ns: ns) {
                selected = .listen
                onTabTap()
            }
            .frame(width: tabWidth, height: tabHeight)

            TabChip(title: "Ask", icon: "bubble.right",
                    isActive: selected == .ask, ns: ns) {
                selected = .ask
                onTabTap()
            }
            .frame(width: tabWidth, height: tabHeight)
        }
    }
}





private struct TabChip: View {
    var title: String
    var icon: String
    var isActive: Bool
    var ns: Namespace.ID
    var onTap: () -> Void

    var body: some View {
        let shape = Capsule(style: .continuous)

        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .background {
                if isActive {
                    Color.clear
                        .liquidGlassBackground(
                            shape,
                            highlightOpacity: 0.22,
                            highlightBlur: 34,
                            tint: .gradient(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.28),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                opacity: 1
                            ),
                            fallbackColor: Color.white.opacity(0.24)
                        )
                        .matchedGeometryEffect(id: "tabHilite", in: ns)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(shape)
    }
}


                                  
                                  
// MARK: - Правые иконки с «клавишей»
private struct KeyedIconButton: View {
    var system: String
    var key: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            let keyShape = RoundedRectangle(cornerRadius: 4, style: .continuous)
            let buttonShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

            let label = HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 13, weight: .semibold))
                if !key.isEmpty {
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .liquidGlassBackground(
                            keyShape,
                            highlightOpacity: 0.18,
                            highlightBlur: 26,
                            tint: .color(Color.white, opacity: 0.12),
                            fallbackColor: Color.black.opacity(0.6)
                        )
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            label
                .liquidGlassBackground(
                    buttonShape,
                    highlightOpacity: 0.20,
                    highlightBlur: 32,
                    tint: .color(Color.white, opacity: 0.10),
                    fallbackColor: Color.black.opacity(0.6)
                )
                .glassLifted()
        }
        .buttonStyle(.plain)
    }
}


private struct KeyPill: View {
    var text: String
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let label = Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

        label
            .liquidGlassBackground(
                shape,
                highlightOpacity: 0.18,
                highlightBlur: 26,
                tint: .color(Color.white, opacity: 0.12),
                fallbackColor: Color.black.opacity(0.6)
            )
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
