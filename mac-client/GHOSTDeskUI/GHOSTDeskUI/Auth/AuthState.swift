import Foundation
import Security

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct UserProfile: Codable, Equatable {
    let token: String
    let plan: String
    let referral: String?
    let createdAt: Date
}

@MainActor
final class AuthState: ObservableObject {
    private enum Keys {
        static let expiresAt = "AuthState.expiresAt"
        static let profile = "AuthState.profile"
    }

    private enum Keychain {
        static let service = Bundle.main.bundleIdentifier ?? "com.ghostdesk.overlay"
        static let accessAccount = "AuthState.accessToken"
        static let refreshAccount = "AuthState.refreshToken"
    }

    @Published private(set) var session: AuthSession?
    @Published private(set) var profile: UserProfile?
    @Published var lastError: String? = nil

    init() {
        restoreSession()
    }

    var accessToken: String? { session?.accessToken }
    var refreshToken: String? { session?.refreshToken }
    var expiresAt: Date? { session?.expiresAt }
    var profileToken: String? { profile?.token }
    var plan: String? { profile?.plan }
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
            return "Выполните вход, чтобы пользоваться GhostDesk."
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
    }

    func updateSession(_ session: AuthSession, _ profile: UserProfile) {
        self.session = session
        self.profile = profile
        lastError = nil
        persistSession(session)
        persistProfile(profile)
    }

    func signOut() {
        session = nil
        profile = nil
        lastError = nil
        persistSession(nil)
        persistProfile(nil)
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

    private func saveKeychainValue(_ value: String?, account: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return }

        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save keychain item: \(status)")
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
}
