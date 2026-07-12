import Foundation
import Security

struct SecureTokenStore: Sendable {
  let service: String
  init(service: String = "ai.audiobook.credentials") { self.service = service }
  func save(_ token: String, account: String) throws {
    let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    SecItemDelete(base as CFDictionary); var item = base; item[kSecValueData as String] = Data(token.utf8); item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(item as CFDictionary, nil); guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
  }
  func read(account: String) throws -> String? {
    var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var value: CFTypeRef?; let status = SecItemCopyMatching(query as CFDictionary, &value)
    if status == errSecItemNotFound { return nil }; guard status == errSecSuccess, let data = value as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    return String(data: data, encoding: .utf8)
  }
}
