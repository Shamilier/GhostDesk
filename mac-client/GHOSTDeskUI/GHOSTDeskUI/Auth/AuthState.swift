import Foundation
import Security

@MainActor
final class AuthState: ObservableObject {
    private enum Keys {
        static let isVerified = "AuthState.isVerified"
        static let expiresAt = "AuthState.expiresAt"
    }

    private enum Keychain {
        static let service = Bundle.main.bundleIdentifier ?? "com.ghostdesk.overlay"
        static let account = "AuthState.apiKey"
    }

    @Published var apiKey: String? {
        didSet {
            guard apiKey != oldValue else { return }
            saveKeychainValue(apiKey)
        }
    }

    @Published var isVerified: Bool {
        didSet {
            guard isVerified != oldValue else { return }
            UserDefaults.standard.set(isVerified, forKey: Keys.isVerified)
        }
    }

    @Published var expiresAt: Date? {
        didSet {
            guard expiresAt != oldValue else { return }
            let defaults = UserDefaults.standard
            if let expiresAt {
                defaults.set(expiresAt.timeIntervalSince1970, forKey: Keys.expiresAt)
            } else {
                defaults.removeObject(forKey: Keys.expiresAt)
            }
        }
    }

    init() {
        apiKey = Self.loadKeychainValue()

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.isVerified) != nil {
            isVerified = defaults.bool(forKey: Keys.isVerified)
        } else {
            isVerified = true
            defaults.set(true, forKey: Keys.isVerified)
        }

        if let timestamp = defaults.object(forKey: Keys.expiresAt) as? Double {
            expiresAt = Date(timeIntervalSince1970: timestamp)
        } else {
            expiresAt = nil
        }
    }

    func updateApiKey(_ key: String?) {
        apiKey = key
    }

    func verifyKey() async {
        isVerified = true
        expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }

    private func saveKeychainValue(_ value: String?) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: Keychain.account
        ]

        SecItemDelete(query as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return }

        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save keychain item: \(status)")
        }
    }

    private static func loadKeychainValue() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: Keychain.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
