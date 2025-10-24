import SwiftUI

struct ApiKeyGateView: View {
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var oauth: OAuthCoordinator
    @State private var didAppear = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 32) {
                VStack(spacing: 14) {
                    Text("Добро пожаловать в GhostDesk")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Ваш AI-ассистент прямо на рабочем столе.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: 440)
                }

                VStack(spacing: 16) {
                    AuthPortalButton(flow: .signUp, style: .primary, action: openPortal)
                    AuthPortalButton(flow: .signIn, style: .secondary, action: openPortal)
                }
                .frame(maxWidth: 440)

                if let error = auth.lastError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.98, green: 0.34, blue: 0.33))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                if oauth.isAuthorizing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }

                Text("Powered by GhostDesk AI")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 8)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 48)
            .frame(maxWidth: 600)
            .background(glassBackground)
            .overlay(glassBorder)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 32, x: 0, y: 26)
            .shadow(color: Color(red: 0.73, green: 0.44, blue: 1.0).opacity(0.22), radius: 36, x: 0, y: 0)
            .padding(.horizontal, 40)
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 18)
            .animation(.easeOut(duration: 0.4), value: didAppear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            didAppear = true
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .blur(radius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                    .blendMode(.screen)
            )
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.35), lineWidth: 1.6)
                    .blur(radius: 6)
                    .offset(x: 0, y: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                    )
            )
    }

    private var backgroundLayer: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.05, blue: 0.11), Color(red: 0.10, green: 0.04, blue: 0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(primaryGlow)
                    .opacity(0.35)
                    .frame(width: size.width * 0.65)
                    .blur(radius: 120)
                    .offset(x: -size.width * 0.18, y: -size.height * 0.32)

                Circle()
                    .fill(secondaryGlow)
                    .opacity(0.28)
                    .frame(width: size.width * 0.58)
                    .blur(radius: 140)
                    .offset(x: size.width * 0.24, y: size.height * 0.3)

                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: size.height * 0.4)
                .offset(y: -size.height * 0.33)
            }
        }
    }

    private var primaryGlow: Color {
        Color(red: 0.55, green: 0.70, blue: 1.0)
    }

    private var secondaryGlow: Color {
        Color(red: 0.94, green: 0.50, blue: 0.89)
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

    var body: some View {
        Button {
            action(flow)
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: style == .primary ? 22 : 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, style == .primary ? 22 : 18)
            .padding(.horizontal, 28)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: primaryGlowShadow, radius: style == .primary ? 18 : 0, x: 0, y: style == .primary ? 10 : 0)
            .shadow(color: secondaryGlowShadow, radius: style == .primary ? 22 : 0, x: 0, y: 0)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
#if os(macOS)
        .onHover { hover in
            isHovering = hover
        }
#endif
    }

    @ViewBuilder
    private var background: some View {
        let base = RoundedRectangle(cornerRadius: 22, style: .continuous)

        switch style {
        case .primary:
            base
                .fill(primaryGradient)
                .overlay(
                    base
                        .fill(Color.white.opacity(isHovering ? 0.22 : 0.12))
                        .blendMode(.plusLighter)
                )
        case .secondary:
            base
                .fill(secondaryBase)
                .overlay(
                    base
                        .fill(Color.white.opacity(isHovering ? 0.1 : 0.04))
                        .blendMode(.screen)
                )
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(style == .primary ? Color.white.opacity(0.3) : Color.white.opacity(0.18), lineWidth: 1.2)
            .blendMode(.screen)
    }

    private var subtitle: String {
        switch flow {
        case .signIn:
            return "У меня уже есть аккаунт"
        case .signUp:
            return "Создать аккаунт за минуту"
        }
    }

    private var title: String {
        switch flow {
        case .signIn:
            return "Войти"
        case .signUp:
            return "Зарегистрироваться"
        }
    }

    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.23, blue: 1.0),
                Color(red: 0.30, green: 0.43, blue: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var secondaryBase: Color {
        if isHovering {
            return Color(red: 0.20, green: 0.20, blue: 0.27)
        } else {
            return Color(red: 0.16, green: 0.16, blue: 0.21)
        }
    }

    private var primaryGlowShadow: Color {
        switch style {
        case .primary:
            return Color(red: 0.95, green: 0.23, blue: 1.0, opacity: isHovering ? 0.45 : 0.35)
        case .secondary:
            return .clear
        }
    }

    private var secondaryGlowShadow: Color {
        switch style {
        case .primary:
            return Color(red: 0.30, green: 0.43, blue: 1.0, opacity: isHovering ? 0.24 : 0.18)
        case .secondary:
            return .clear
        }
    }
}
