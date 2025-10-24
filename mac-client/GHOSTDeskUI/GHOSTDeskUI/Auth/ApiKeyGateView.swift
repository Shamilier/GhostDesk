import SwiftUI

struct ApiKeyGateView: View {
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var oauth: OAuthCoordinator
    @State private var didAppear = false
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Color.clear

            card
                .scaleEffect(didAppear ? (isBreathing ? 1.01 : 1.0) : 0.98)
                .opacity(didAppear ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: didAppear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            didAppear = true
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                isBreathing.toggle()
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Добро пожаловать в GhostDesk")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text("Ваш AI-ассистент прямо на рабочем столе.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 420)
            }

            VStack(spacing: 16) {
                AuthPortalButton(flow: .signUp, style: .primary, action: openPortal)

                AuthPortalButton(flow: .signIn, style: .secondary, action: openPortal)
            }
            .padding(.top, 24)

            if let error = auth.lastError {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.98, green: 0.34, blue: 0.33))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            if oauth.isAuthorizing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding(.top, auth.lastError == nil ? 12 : 8)
            }

            Text("Powered by GhostDesk AI")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.top, 28)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 56)
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 560)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 60, x: 0, y: 20)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(red: 22 / 255, green: 22 / 255, blue: 26 / 255).opacity(0.72))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .blur(radius: 20)
            )
    }

    private func openPortal(_ flow: OAuthFlowKind) {
        oauth.startAuthorization(flow: flow)
    }
}

private struct AuthPortalButton: View {
    enum Style {
        case primary
        case secondary
    }

    let flow: OAuthFlowKind
    let style: Style
    let action: (OAuthFlowKind) -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            action(flow)
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(AuthCTAButtonStyle(style: style, isHovering: isHovering, isFocused: isFocused))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .focused($isFocused)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
#if os(macOS)
        .onHover { hover in
            isHovering = hover
        }
#endif
        .modifier(DefaultActionShortcut(isPrimary: flow == .signUp))
    }

    private var title: String {
        switch flow {
        case .signIn:
            return "Войти"
        case .signUp:
            return "Зарегистрироваться"
        }
    }

    private var accessibilityLabel: Text {
        Text(title)
    }

    private var accessibilityHint: Text {
        switch flow {
        case .signIn:
            return Text("Кнопка входа")
        case .signUp:
            return Text("Основная кнопка регистрации")
        }
    }
}

private struct AuthCTAButtonStyle: ButtonStyle {
    let style: AuthPortalButton.Style
    let isHovering: Bool
    let isFocused: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(focusRing)
            .shadow(color: shadowColor(isPressed: configuration.isPressed), radius: shadowRadius(isPressed: configuration.isPressed), x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return isEnabled ? .white : Color.white.opacity(0.6)
        case .secondary:
            return isEnabled ? Color.white.opacity(0.92) : Color.white.opacity(0.45)
        }
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        switch style {
        case .primary:
            if isEnabled {
                shape
                    .fill(primaryGradient(isPressed: isPressed))
                    .overlay(primaryOverlay(isPressed: isPressed))
            } else {
                shape
                    .fill(Color(red: 0.36, green: 0.37, blue: 0.45))
            }
        case .secondary:
            shape
                .fill(secondaryColor(isPressed: isPressed))
        }
    }

    private func primaryGradient(isPressed: Bool) -> LinearGradient {
        let start = Color(red: 1.0, green: 0.294, blue: 0.851)
        let end = Color(red: 0.427, green: 0.498, blue: 1.0)

        if isPressed {
            let pressedStart = Color(red: 0.9, green: 0.265, blue: 0.766)
            let pressedEnd = Color(red: 0.384, green: 0.448, blue: 0.9)
            return LinearGradient(colors: [pressedStart, pressedEnd], startPoint: .leading, endPoint: .trailing)
        }

        return LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private func primaryOverlay(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        if isHovering && !isPressed {
            shape
                .fill(Color.white.opacity(0.08))
                .blendMode(.plusLighter)
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .blendMode(.screen)
                )
        }
    }

    private func secondaryColor(isPressed: Bool) -> Color {
        guard isEnabled else { return Color(red: 0.16, green: 0.16, blue: 0.21) }

        if isPressed {
            return Color(red: 0.18, green: 0.18, blue: 0.23)
        }

        return isHovering ? Color(red: 0.20, green: 0.20, blue: 0.27) : Color(red: 0.16, green: 0.16, blue: 0.21)
    }

    private func shadowColor(isPressed: Bool) -> Color {
        guard style == .primary, isEnabled, !isPressed else { return .clear }
        return Color(red: 165 / 255, green: 105 / 255, blue: 1.0).opacity(isHovering ? 0.35 : 0.28)
    }

    private func shadowRadius(isPressed: Bool) -> CGFloat {
        guard style == .primary, isEnabled, !isPressed else { return 0 }
        return isHovering ? 18 : 12
    }

    private var focusRing: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(isFocused ? Color(red: 0.541, green: 0.482, blue: 1.0) : .clear, lineWidth: 2)
            .padding(-3)
    }
}

private struct DefaultActionShortcut: ViewModifier {
    let isPrimary: Bool

    func body(content: Content) -> some View {
        if isPrimary {
            content.keyboardShortcut(.defaultAction)
        } else {
            content
        }
    }
}
