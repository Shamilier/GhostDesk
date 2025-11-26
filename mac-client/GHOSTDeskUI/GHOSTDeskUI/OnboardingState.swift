import Foundation
import Security

final class OnboardingState {
    static let shared = OnboardingState()

    private enum Keychain {
        static let service = Bundle.main.bundleIdentifier ?? "com.ghostai.overlay"
        static let onboardingAccount = "Onboarding.hasCompleted"
    }

    private(set) var hasCompletedOnboarding: Bool

    private init() {
        hasCompletedOnboarding = Self.loadOnboardingFlag()
    }

    func markCompleted() {
        hasCompletedOnboarding = true
        saveOnboardingFlag(true)
    }

    func reset() {
        hasCompletedOnboarding = false
        deleteOnboardingFlag()
    }

    private func saveOnboardingFlag(_ value: Bool) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: Keychain.onboardingAccount
        ]

        SecItemDelete(query as CFDictionary)

        guard let data = (value ? "true" : "false").data(using: .utf8) else { return }
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[OnboardingState] Failed to save onboarding flag: \(status)")
        }
    }

    private func deleteOnboardingFlag() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: Keychain.onboardingAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    private static func loadOnboardingFlag() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keychain.service,
            kSecAttrAccount as String: Keychain.onboardingAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let stringValue = String(data: data, encoding: .utf8) else {
            return false
        }

        return (stringValue as NSString).boolValue
    }
}
