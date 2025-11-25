import Foundation
import AppKit
import CryptoKit
import Security
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

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

@MainActor
final class OAuthCoordinator: ObservableObject {
    static let shared = OAuthCoordinator()

    private static let pendingTTL: TimeInterval = 15 * 60

    @Published private(set) var isAuthorizing: Bool = false

    private let api: AuthAPI
    private weak var authState: AuthState?

    private var pendingState: String?
    private var pendingCodeVerifier: String?
    private var cachedConfiguration: OAuthConfiguration?
    private var cachedConfigurationBaseURL: URL?
    private let pendingStorage = PendingAuthorizationStorage()

    #if canImport(AuthenticationServices)
    private var webAuthSession: ASWebAuthenticationSession?
    private let webAuthContextProvider = WebAuthenticationPresentationProvider()
    #endif

    private init(api: AuthAPI = .shared) {
        self.api = api
    }

    func configure(authState: AuthState?) {
        self.authState = authState
    }

    func startAuthorization(flow: OAuthFlowKind) {
        assert(authState != nil, "OAuthCoordinator.configure(authState:) must be called before starting authorization.")
        guard let authState else { return }
        guard !isAuthorizing else { return }

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

                let authorizationURL = try Self.buildAuthorizationURL(
                    baseURL: self.api.baseURL,
                    configuration: configuration,
                    state: state,
                    codeChallenge: challenge,
                    prompt: prompt
                )

                self.resetPending()
                self.pendingCodeVerifier = verifier
                self.pendingState = state
                self.pendingStorage.save(state: state, verifier: verifier, timestamp: Date())

                await self.launchAuthorization(at: authorizationURL, redirectURI: configuration.redirectUri)
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
        guard let authState else { return }

        if pendingState == nil || pendingCodeVerifier == nil {
            switch pendingStorage.load(maxAgeSeconds: Self.pendingTTL) {
            case .restored(let restoredState, let verifier):
                pendingState = restoredState
                pendingCodeVerifier = verifier
            case .expired:
                resetPending()
                isAuthorizing = false
                if authState.isAuthorized { return }
                authState.signOut(reason: "Сессия авторизации истекла. Попробуйте снова.")
                return
            case .missing:
                resetPending()
                isAuthorizing = false
                if authState.isAuthorized { return }
                authState.signOut(reason: "Сессия авторизации не найдена. Попробуйте снова.")
                return
            }
        }

        guard let expectedState = pendingState,
              let verifier = pendingCodeVerifier else {
            resetPending()
            isAuthorizing = false
            if authState.isAuthorized { return }
            authState.signOut(reason: "Сессия авторизации не найдена. Попробуйте снова.")
            return
        }

        guard expectedState == state else {
            authState.signOut(reason: "Безопасность: состояние запроса не совпадает. Попробуйте снова.")
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
        let baseURL = api.baseURL
        if let cachedConfiguration,
           let cachedBaseURL = cachedConfigurationBaseURL,
           cachedBaseURL == baseURL {
            return cachedConfiguration
        }

        let configuration = try await api.fetchOAuthConfiguration()
        cachedConfiguration = configuration
        cachedConfigurationBaseURL = baseURL
        return configuration
    }

    private func resetPending() {
        pendingState = nil
        pendingCodeVerifier = nil
        pendingStorage.clear()
    #if canImport(AuthenticationServices)
        if #available(macOS 10.15, *) {
            webAuthSession?.cancel()
        }
        webAuthSession = nil
    #endif
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

    private func launchAuthorization(at url: URL, redirectURI: String) async {
    #if canImport(AuthenticationServices)
        if #available(macOS 10.15, *) {
            if let scheme = Self.callbackScheme(from: redirectURI) {
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                    guard let self else { return }
                    Task { @MainActor in
                        self.webAuthSession = nil

                        if let error = error {
                            if let authError = error as? ASWebAuthenticationSessionError,
                               authError.code == .canceledLogin {
                                self.isAuthorizing = false
                                if self.authState?.isAuthorized != true {
                                    self.authState?.lastError = "Авторизация отменена."
                                }
                                self.resetPending()
                                return
                            }

                            self.isAuthorizing = false
                            self.authState?.signOut(reason: Self.format(error: error))
                            self.resetPending()
                            return
                        }

                        guard let callbackURL,
                              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                            self.isAuthorizing = false
                            self.authState?.signOut(reason: "Не удалось обработать ответ авторизации. Попробуйте снова.")
                            self.resetPending()
                            return
                        }

                        self.handleCallback(code: code, state: state)
                    }
                }

                session.prefersEphemeralWebBrowserSession = true
                session.presentationContextProvider = webAuthContextProvider

                if session.start() {
                    webAuthSession = session
                    return
                } else {
                    webAuthSession = nil
                }
            }
        }
    #endif

        NSWorkspace.shared.open(url)
    }

    private static func callbackScheme(from redirectURI: String) -> String? {
        guard let url = URL(string: redirectURI) else { return nil }
        return url.scheme
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
        if let decodingError = error as? DecodingError {
            return "Не удалось разобрать ответ сервера (\(decodingError)). Попробуйте снова."
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

private struct PendingAuthorizationStorage {
    enum LoadResult {
        case restored(state: String, verifier: String)
        case expired
        case missing
    }

    private enum DefaultsKeys {
        static let state = "OAuthCoordinator.pending.state"
        static let timestamp = "OAuthCoordinator.pending.timestamp"
    }

    private let defaults = UserDefaults.standard
    private let keychainService = Bundle.main.bundleIdentifier ?? "com.ghostai.overlay"
    private let keychainAccount = "OAuthCoordinator.pending.codeVerifier"

    func save(state: String, verifier: String, timestamp: Date) {
        defaults.set(state, forKey: DefaultsKeys.state)
        defaults.set(timestamp.timeIntervalSince1970, forKey: DefaultsKeys.timestamp)
        saveVerifier(verifier)
    }

    func load(maxAgeSeconds: TimeInterval) -> LoadResult {
        guard let state = defaults.string(forKey: DefaultsKeys.state) else {
            clear()
            return .missing
        }

        guard let timestampValue = defaults.object(forKey: DefaultsKeys.timestamp) as? Double else {
            clear()
            return .missing
        }

        guard let verifier = loadVerifier() else {
            clear()
            return .missing
        }

        let age = Date().timeIntervalSince1970 - timestampValue
        guard age <= maxAgeSeconds else {
            clear()
            return .expired
        }

        return .restored(state: state, verifier: verifier)
    }

    func clear() {
        defaults.removeObject(forKey: DefaultsKeys.state)
        defaults.removeObject(forKey: DefaultsKeys.timestamp)
        clearVerifier()
    }

    private func saveVerifier(_ verifier: String) {
        let data = Data(verifier.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[OAuthCoordinator] Failed to persist code verifier: \(status)")
        }
    }

    private func loadVerifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func clearVerifier() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }
}

#if canImport(AuthenticationServices)
private final class WebAuthenticationPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }
        if let mainWindow = NSApplication.shared.mainWindow {
            return mainWindow
        }
        if let anyWindow = NSApplication.shared.windows.first {
            return anyWindow
        }
        return NSWindow()
    }
}
#endif

