import SwiftUI

struct ApiKeyGateView: View {
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var oauth: OAuthCoordinator

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 32) {
                VStack(spacing: 18) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(gradientPrimary)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(primaryGlow)
                        )

                    Text("Добро пожаловать в GhostDesk")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.95)

                    Text("Подключитесь к вашему AI-ассистенту через портал GhostDesk. Выберите сценарий входа, чтобы синхронизировать историю, подписку и настройки.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: 460)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 18) {
                    AuthPortalButton(flow: .signIn, accent: gradientPrimary, action: openPortal)
                    AuthPortalButton(flow: .signUp, accent: gradientSecondary, action: openPortal)
                }
                .frame(maxWidth: 460)

                if let error = auth.lastError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.98, green: 0.34, blue: 0.33))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }

                if oauth.isAuthorizing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .padding(.vertical, 48)
            .padding(.horizontal, 52)
            .frame(maxWidth: 600)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.22), radius: 32, x: 0, y: 24)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.04))
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

    private var gradientPrimary: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.477, green: 0.666, blue: 0.9), Color(red: 0.36, green: 0.324, blue: 0.873)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientSecondary: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.891, green: 0.396, blue: 0.702), Color(red: 0.603, green: 0.306, blue: 0.891)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

struct SessionRestoreView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        AuthBackdrop {
            VStack(spacing: 28) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)

                VStack(spacing: 10) {
                    Text("Проверяем вашу сессию")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("GhostDesk восстанавливает ваш профиль и ключи доступа. Это займёт всего несколько секунд.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: 360)
                }

                Button {
                    auth.signOut()
                } label: {
                    Label("Войти под другим аккаунтом", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 420)
        }
    }
}

private struct AuthBackdrop<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AuthBackground()

            content
                .padding(.vertical, 48)
                .padding(.horizontal, 52)
                .background(AuthGlass())
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 32, x: 0, y: 24)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AuthGlass: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
    }
}

private struct AuthBackground: View {
    var body: some View {
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
                    .fill(AuthTheme.primaryGlow)
                    .opacity(0.35)
                    .frame(width: size.width * 0.65)
                    .blur(radius: 120)
                    .offset(x: -size.width * 0.18, y: -size.height * 0.32)

                Circle()
                    .fill(AuthTheme.secondaryGlow)
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
}

private enum AuthTheme {
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.477, green: 0.666, blue: 0.9), Color(red: 0.36, green: 0.324, blue: 0.873)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let secondaryGradient = LinearGradient(
        colors: [Color(red: 0.891, green: 0.396, blue: 0.702), Color(red: 0.603, green: 0.306, blue: 0.891)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGlow = Color(red: 0.55, green: 0.70, blue: 1.0)
    static let secondaryGlow = Color(red: 0.94, green: 0.50, blue: 0.89)
}

private struct AuthPortalButton: View {
    let flow: OAuthFlowKind
    let accent: LinearGradient
    let action: (OAuthFlowKind) -> Void

    var body: some View {
        Button {
            action(flow)
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent)
                        .opacity(0.35)
                        .blur(radius: 0.5)

                    Image(systemName: symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(accent)
                        .opacity(0.9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .blendMode(.plusLighter)
                                .opacity(0.4)
                        )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.1)
                    .blendMode(.screen)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 16)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var title: String {
        switch flow {
        case .signIn: return "Войти"
        case .signUp: return "Зарегистрироваться"
        }
    }

    private var subtitle: String {
        switch flow {
        case .signIn: return "У меня уже есть аккаунт"
        case .signUp: return "Создать новый профиль"
        }
    }

    private var symbolName: String {
        switch flow {
        case .signIn: return "rectangle.and.pencil.and.ellipsis"
        case .signUp: return "person.badge.plus"
        }
    }
}
