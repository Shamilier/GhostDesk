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

// MARK: - Glass визуальные токены
private enum Glass {
    static var accent: Color { .accentColor }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.95), accent.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var background: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                Capsule().fill(Color.black.opacity(0.06))
            )
    }
    static var ring: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(colors: [
                    .white.opacity(0.65),
                    .white.opacity(0.18)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
            .blendMode(.overlay)
    }
    static var hairline: Color { .white.opacity(0.22) }
    static var hairlineOverlay: some View {
        Capsule().inset(by: 1.5)
            .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
    }
    static var accentShadow: Color { .accentColor.opacity(0.16) }
}

private struct CommandBar: View {
    var isRecording: Bool
    @Binding var selected: CommandTab
    var onPrimaryTap: () -> Void    // оставим сигнатуру, но не используем
    var onEyeTap: () -> Void
    var onMenuTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // logo
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.75))

            TabSwitcher(
                selected: $selected,
                isRecording: isRecording,
                onTabTap: { onPrimaryTap() }    // ← добавили
            )


            KeyedIconButton(system: "eye",      key: "⌘E", action: onEyeTap)
            Button(action: onMenuTap) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(MiniIconButton())

        }
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
        // УБРАЛИ дымку: либо совсем без тени, либо очень аккуратно:
        // .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
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


                                  
                                  
// MARK: - Правые иконки с «клавишей»
private struct KeyedIconButton: View {
    var system: String
    var key: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
    }
}


private struct KeyPill: View {
    var text: String
    var body: some View {
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
