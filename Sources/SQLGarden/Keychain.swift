import Foundation
import Security
import StudioCore

enum PasswordStore {
    private static let service = "app.sqlgarden.connection"
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private static func perform<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    static func read(_ account: String) async throws -> String? {
        try await perform { try readSynchronously(account) }
    }
    static func save(_ password: String, account: String) async throws {
        try await perform { try saveSynchronously(password, account: account) }
    }
    static func delete(_ account: String) async throws {
        try await perform {
            let status = SecItemDelete(query(account) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw StudioError.message("Não foi possível remover a senha do Chaves (\(status)).")
            }
        }
    }
    private static func readSynchronously(_ account: String) throws -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw StudioError.message("O Chaves não liberou a senha (\(status)). Digite-a manualmente.")
        }
        return String(data: data, encoding: .utf8)
    }
    private static func saveSynchronously(_ password: String, account: String) throws {
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
}
