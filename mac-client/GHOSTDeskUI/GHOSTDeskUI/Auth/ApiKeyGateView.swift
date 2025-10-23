import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ApiKeyGateView: View {
    private let portalURL = URL(string: "https://resistible-opinionative-jeanie.ngrok-free.dev")

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
                    AuthPortalButton(kind: .signIn, action: openPortal)
                    AuthPortalButton(kind: .signUp, action: openPortal)
                }
                .frame(maxWidth: 420)
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

    private func openPortal(_ kind: AuthPortalButton.Kind) {
        _ = kind
        guard let url = portalURL else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

private struct AuthPortalButton: View {
    enum Kind {
        case signIn
        case signUp

        var title: String {
            switch self {
            case .signIn: return "Войти"
            case .signUp: return "Зарегистрироваться"
            }
        }

        var subtitle: String {
            switch self {
            case .signIn: return "У меня уже есть аккаунт"
            case .signUp: return "Создать новый профиль"
            }
        }

        var symbolName: String {
            switch self {
            case .signIn: return "key.fill"
            case .signUp: return "sparkles"
            }
        }

        var gradient: LinearGradient {
            switch self {
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

    let kind: Kind
    let action: (Kind) -> Void

    var body: some View {
        Button {
            action(kind)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(kind.subtitle)
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
            .background(kind.gradient)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}
