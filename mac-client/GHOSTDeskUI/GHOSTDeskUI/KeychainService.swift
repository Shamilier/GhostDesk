import Security

enum KeychainDebugConfig {
    /// Toggle to clean the keychain every time the app launches while debugging.
    /// Set to `false` to stop wiping stored credentials.
    static let resetOnLaunch: Bool = true
}

func resetKeychain() {
    let secItemClasses: [CFString] = [
        kSecClassGenericPassword,
        kSecClassInternetPassword,
        kSecClassCertificate,
        kSecClassKey,
        kSecClassIdentity
    ]

    for itemClass in secItemClasses {
        let query: [String: Any] = [kSecClass as String: itemClass]
        SecItemDelete(query as CFDictionary)
    }
}
