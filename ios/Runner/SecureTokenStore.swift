import Foundation
import Security

/// API Key 仅保存在 iOS Keychain，不写入 UserDefaults、日志或仓库。
struct SecureTokenStore: Sendable {
  private let service: String

  init(service: String = "ai.audiobook.credentials") {
    self.service = service
  }

  func save(_ token: String, account: String) throws {
    let data = Data(token.utf8)
    let query = baseQuery(account: account)
    SecItemDelete(query as CFDictionary)
    var item = query
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError(status: status) }
  }

  func read(account: String) throws -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw KeychainError(status: status)
    }
    return String(data: data, encoding: .utf8)
  }

  func delete(account: String) throws {
    let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError(status: status)
    }
  }

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

struct KeychainError: LocalizedError {
  let status: OSStatus
  var errorDescription: String? {
    SecCopyErrorMessageString(status, nil) as String? ?? "Keychain 错误：\(status)"
  }
}
