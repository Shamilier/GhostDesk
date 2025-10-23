import Foundation
import AppKit
import CryptoKit
import Security

@MainActor
final class OAuthCoordinator: ObservableObject {
    static let shared = OAuthCoordinator()

    @Published private(set) var isAuthorizing: Bool = false

    private let api: AuthAPI
    private weak var authState: AuthState?

    private var pendingState: String?
    private var pendingCodeVerifier: String?
    private var cachedConfiguration: OAuthConfiguration?

    private init(api: AuthAPI = .shared) {
        self.api = api
    }

    func configure(authState: AuthState?) {
        self.authState = authState
    }

    func startAuthorization(flow: OAuthFlowKind) {
        guard let authState else { return }
        authState.lastError = nil
        isAuthorizing = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let configuration = try await self.fetchConfiguration()
                let verifier = try Self.makeCodeVerifier()
                let challenge = Self.makeCodeChallenge(verifier)
                let state = Self.makeState()
                let prompt = Self.prompt(for: flow) ?? configuration.defaultPrompt

                self.pendingCodeVerifier = verifier
                self.pendingState = state

                let authorizationURL = try Self.buildAuthorizationURL(
                    baseURL: self.api.baseURL,
                    configuration: configuration,
                    state: state,
                    codeChallenge: challenge,
                    prompt: prompt
                )

                await MainActor.run {
                    NSWorkspace.shared.open(authorizationURL)
                }
            } catch {
                await MainActor.run {
                    self.isAuthorizing = false
                    self.authState?.signOut(reason: Self.format(error: error))
                    self.resetPending()
                }
            }
        }
    }

    func handleCallback(code: String, state: String) {
        guard let expectedState = pendingState,
              let verifier = pendingCodeVerifier else {
            authState?.signOut(reason: "Сессия авторизации не найдена. Попробуйте снова.")
            resetPending()
            isAuthorizing = false
            return
        }

        guard expectedState == state else {
            authState?.signOut(reason: "Безопасность: состояние запроса не совпадает. Попробуйте снова.")
            resetPending()
            isAuthorizing = false
            return
        }

        isAuthorizing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let configuration = try await self.fetchConfiguration()
                let session = try await self.api.exchangeAuthorizationCode(
                    code,
                    codeVerifier: verifier,
                    configuration: configuration
                )
                let profile = try await self.api.fetchProfile(accessToken: session.accessToken)

                await MainActor.run {
                    self.authState?.updateSession(session, profile)
                    self.resetPending()
                    self.isAuthorizing = false
                }
            } catch {
                await MainActor.run {
                    let message = Self.format(error: error)
                    self.authState?.signOut(reason: message)
                    self.resetPending()
                    self.isAuthorizing = false
                }
            }
        }
    }

    private func fetchConfiguration() async throws -> OAuthConfiguration {
        if let cachedConfiguration {
            return cachedConfiguration
        }
        let configuration = try await api.fetchOAuthConfiguration()
        cachedConfiguration = configuration
        return configuration
    }

    private func resetPending() {
        pendingState = nil
        pendingCodeVerifier = nil
    }

    private static func makeCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw OAuthError.cryptoFailure
        }
        return base64URLEncode(Data(bytes))
    }

    private static func makeCodeChallenge(_ verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    private static func makeState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func buildAuthorizationURL(
        baseURL: URL,
        configuration: OAuthConfiguration,
        state: String,
        codeChallenge: String,
        prompt: String?
    ) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("/oauth/authorize"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectUri),
            URLQueryItem(name: "scope", value: configuration.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        if let prompt {
            queryItems.append(URLQueryItem(name: "prompt", value: prompt))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else { throw OAuthError.invalidAuthorizationURL }
        return url
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func prompt(for flow: OAuthFlowKind) -> String? {
        switch flow {
        case .signIn:
            return "login"
        case .signUp:
            return "signup"
        }
    }

    private static func format(error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Не удалось выполнить авторизацию: \(error.localizedDescription)"
    }
}

enum OAuthError: LocalizedError {
    case invalidAuthorizationURL
    case cryptoFailure

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            return "Не удалось сформировать ссылку для авторизации. Попробуйте позже."
        case .cryptoFailure:
            return "Сбой генерации параметров безопасности. Попробуйте снова."
        }
    }
}

struct OAuthConfiguration: Decodable {
    let clientId: String
    let redirectUri: String
    let scope: String
    let defaultPrompt: String?

    private enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case scope
        case defaultPrompt = "prompt"
    }
}

enum OAuthFlowKind {
    case signIn
    case signUp
}
