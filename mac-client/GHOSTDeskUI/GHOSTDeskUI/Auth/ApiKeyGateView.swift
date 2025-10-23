import SwiftUI

struct ApiKeyGateView: View {
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var oauth: OAuthCoordinator

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("Добро пожаловать в GhostDesk")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))

                    Text("Для начала авторизуйтесь через портал GhostDesk. Выберите, есть ли у вас уже аккаунт.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 420)
                }

                VStack(spacing: 16) {
                    AuthPortalButton(flow: .signIn, action: openPortal)
                    AuthPortalButton(flow: .signUp, action: openPortal)
                }
                .frame(maxWidth: 420)

                if let error = auth.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                if oauth.isAuthorizing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                }
            }
            .padding(36)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openPortal(_ flow: OAuthFlowKind) {
        oauth.startAuthorization(flow: flow)
    }
}

private struct AuthPortalButton: View {
    let flow: OAuthFlowKind
    let action: (OAuthFlowKind) -> Void

    var body: some View {
        Button {
            action(flow)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(gradient)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
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
        case .signIn: return "key.fill"
        case .signUp: return "sparkles"
        }
    }

    private var gradient: LinearGradient {
        switch flow {
        case .signIn:
            return LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .signUp:
            return LinearGradient(
                colors: [Color.purple, Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
