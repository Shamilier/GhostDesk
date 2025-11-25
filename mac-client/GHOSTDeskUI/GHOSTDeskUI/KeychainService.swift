import Security

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
