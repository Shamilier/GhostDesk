import Foundation
import Security

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct UserProfile: Codable, Equatable {
    let email: String
    let token: String
    let plan: String
    let tokenBalance: Int
    let planRenewsAt: Date?
    let freeTokensRefreshAt: Date?
    let referral: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case email
        case token
        case plan
        case tokenBalance = "token_balance"
        case planRenewsAt = "plan_renews_at"
        case freeTokensRefreshAt = "free_tokens_refresh_at"
        case referral
        case createdAt = "created_at"
    }

    init(
        email: String,
        token: String,
        plan: String,
        tokenBalance: Int,
        planRenewsAt: Date?,
        freeTokensRefreshAt: Date?,
        referral: String?,
        createdAt: Date
    ) {
        self.email = email
        self.token = token
        self.plan = plan
        self.tokenBalance = tokenBalance
        self.planRenewsAt = planRenewsAt
        self.freeTokensRefreshAt = freeTokensRefreshAt
        self.referral = referral
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        token = try container.decode(String.self, forKey: .token)
        plan = try container.decode(String.self, forKey: .plan)
        tokenBalance = try container.decodeIfPresent(Int.self, forKey: .tokenBalance) ?? 0
        planRenewsAt = try container.decodeIfPresent(Date.self, forKey: .planRenewsAt)
        freeTokensRefreshAt = try container.decodeIfPresent(Date.self, forKey: .freeTokensRefreshAt)
        referral = try container.decodeIfPresent(String.self, forKey: .referral)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(token, forKey: .token)
        try container.encode(plan, forKey: .plan)
        try container.encode(tokenBalance, forKey: .tokenBalance)
        try container.encodeIfPresent(planRenewsAt, forKey: .planRenewsAt)
        try container.encodeIfPresent(freeTokensRefreshAt, forKey: .freeTokensRefreshAt)
        try container.encodeIfPresent(referral, forKey: .referral)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

@MainActor
final class AuthState: ObservableObject {
    private enum Keys {
        static let expiresAt = "AuthState.expiresAt"
        static let profile = "AuthState.profile"
    }

    private enum Keychain {
        static let service = Bundle.main.bundleIdentifier ?? "com.ghostai.overlay"
        static let accessAccount = "AuthState.accessToken"
        static let refreshAccount = "AuthState.refreshToken"
    }

    @Published private(set) var session: AuthSession?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isRestoring: Bool = false
    @Published var lastError: String? = nil

    private var refreshTask: Task<Void, Never>? = nil

    init() {
        restoreSession()
    }

    deinit {
        refreshTask?.cancel()
    }

    var accessToken: String? { session?.accessToken }
    var refreshToken: String? { session?.refreshToken }
    var expiresAt: Date? { session?.expiresAt }
    var email: String? { profile?.email }
    var profileToken: String? { profile?.token }
    var plan: String? { profile?.plan }
    var tokenBalance: Int? { profile?.tokenBalance }
    var planRenewsAt: Date? { profile?.planRenewsAt }
    var freeTokensRefreshAt: Date? { profile?.freeTokensRefreshAt }
    var referral: String? { profile?.referral }
    var createdAt: Date? { profile?.createdAt }

    var isAuthorized: Bool {
        guard let session, session.expiresAt > Date() else { return false }
        guard profile != nil else { return false }
        return !session.accessToken.isEmpty && !session.refreshToken.isEmpty
    }

    var authorizationIssue: String? {
        if isAuthorized { return nil }
        if let lastError { return lastError }
        guard let session else {
            return "Выполните вход, чтобы пользоваться Ghost AI."
        }
        if session.accessToken.isEmpty || session.refreshToken.isEmpty {
            return "Недействительная сессия. Пожалуйста, войдите снова."
        }
        if session.expiresAt <= Date() {
            return "Срок действия сессии истёк. Войдите снова."
        }
        if profile == nil {
            return "Не удалось загрузить профиль пользователя."
        }
        return nil
    }

    func restoreSession() {
        let access = Self.loadKeychainValue(account: Keychain.accessAccount)
        let refresh = Self.loadKeychainValue(account: Keychain.refreshAccount)

        let defaults = UserDefaults.standard
        let expiresAt: Date?
        if let timestamp = defaults.object(forKey: Keys.expiresAt) as? Double {
            expiresAt = Date(timeIntervalSince1970: timestamp)
        } else {
            expiresAt = nil
        }

        if let access, let refresh, let expiresAt {
            session = AuthSession(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)

            logAccessToken(access, context: "Restored session")

        } else {
            session = nil
        }

        if let profileData = defaults.data(forKey: Keys.profile) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode(UserProfile.self, from: profileData) {
                profile = decoded
            } else {
                profile = nil
                defaults.removeObject(forKey: Keys.profile)
            }
        } else {
            profile = nil
        }

        if let session, profile == nil {
            hydrateProfile(using: session)
        } else {
            isRestoring = false
        }

        scheduleRefreshTask()
    }

    func updateSession(_ session: AuthSession, _ profile: UserProfile) {
        self.session = session
        self.profile = profile
        logAccessToken(session.accessToken, context: "Updated session")
        isRestoring = false
        lastError = nil
        persistSession(session)
        persistProfile(profile)
        scheduleRefreshTask()
    }

    func signOut(reason: String? = nil) {
        session = nil
        profile = nil
        isRestoring = false
        lastError = reason
        persistSession(nil)
        persistProfile(nil)
        refreshTask?.cancel()
        refreshTask = nil
    }

    var currentKey: String? {
        accessToken
    }

    private func persistSession(_ session: AuthSession?) {
        saveKeychainValue(session?.accessToken, account: Keychain.accessAccount)
        saveKeychainValue(session?.refreshToken, account: Keychain.refreshAccount)

        let defaults = UserDefaults.standard
        if let expiresAt = session?.expiresAt {
            defaults.set(expiresAt.timeIntervalSince1970, forKey: Keys.expiresAt)
        } else {
            defaults.removeObject(forKey: Keys.expiresAt)
        }
    }

    private func persistProfile(_ profile: UserProfile?) {
        let defaults = UserDefaults.standard
        guard let profile else {
            defaults.removeObject(forKey: Keys.profile)
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: Keys.profile)
        } else {
            defaults.removeObject(forKey: Keys.profile)
        }
    }

    private func hydrateProfile(using session: AuthSession) {
        guard !isRestoring else { return }
        isRestoring = true

        Task { [weak self] in
            do {
                let fetched = try await AuthAPI.shared.fetchProfile(accessToken: session.accessToken)
                await MainActor.run {
                    guard let self else { return }
                    self.profile = fetched
                    self.persistProfile(fetched)
                    self.isRestoring = false
                    self.lastError = nil
                }
            } catch {
                await MainActor.run {
                    self?.signOut(reason: "Не удалось восстановить профиль. Войдите снова.")
                }
            }
        }
    }

    private func saveKeychainValue(_ value: String?, account: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        // Если пришло nil — значит удаляем
        guard let value, let data = value.data(using: .utf8) else {
            if account == Keychain.accessAccount {
                print("[AuthState] Access token removed from Keychain.")
            }
            return
        }

        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save keychain item: \(status)")
        } else {
            if account == Keychain.accessAccount {
                print("[AuthState] Access token saved to Keychain.")
            }
        }
    }

    private static func loadKeychainValue(account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func logAccessToken(_ token: String, context: String) {
        guard !token.isEmpty else { return }
        let masked = Self.maskToken(token)
        print("[AuthState] Access token (\(context)): \(masked)")
    }

    private static func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "•", count: token.count) }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        return "\(prefix)••••\(suffix)"
    }

    private func scheduleRefreshTask() {
        refreshTask?.cancel()

        guard let session, session.expiresAt > Date(), let refreshToken else { return }

        let leadTime: TimeInterval = 120
        let secondsUntilExpiry = session.expiresAt.timeIntervalSinceNow
        let delay = max(secondsUntilExpiry - leadTime, 5)

        refreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }

            guard let self else { return }
            

            do {
                let newSession = try await AuthAPI.shared.refreshTokens(refreshToken: refreshToken)
                let profile = try await AuthAPI.shared.fetchProfile(accessToken: newSession.accessToken)
                await MainActor.run {
                    self.updateSession(newSession, profile)
                }
            } catch {
                await MainActor.run {
                    self.signOut(reason: "Не удалось обновить сессию. Войдите снова.")
                }
            }
        }
    }
}
