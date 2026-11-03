import Foundation
import Security
import StudioCore

enum PasswordStore {
    private static let service = "app.sqlgarden.connection"
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    static func read(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ password: String, account: String) throws {
        let q = query(account)
        let values = [kSecValueData as String: Data(password.utf8)]
        let status = SecItemUpdate(q as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = Data(password.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let create = SecItemAdd(item as CFDictionary, nil)
            guard create == errSecSuccess else { throw StudioError.message("Não foi possível salvar a senha no Chaves (\(create)).") }
        } else if status != errSecSuccess { throw StudioError.message("Não foi possível atualizar a senha no Chaves (\(status)).") }
    }
    static func delete(_ account: String) { SecItemDelete(query(account) as CFDictionary) }
}
