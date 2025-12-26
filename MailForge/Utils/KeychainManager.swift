import Foundation
import Security

/// Secure keychain manager for storing email credentials
final class KeychainManager: @unchecked Sendable {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = KeychainManager()

    private init() {}

    // MARK: - Service Identifier

    private let service = "com.mailforge.app"

    // MARK: - Save Credentials

    /// Save email password to keychain
    /// - Parameters:
    ///   - password: Password to store
    ///   - account: Account identifier (email address or account ID)
    /// - Throws: KeychainError if save fails
    func savePassword(_ password: String, for account: String) throws {
        // Convert password to Data
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Check if password already exists
        if try passwordExists(for: account) {
            // Update existing password
            try updatePassword(password, for: account)
            return
        }

        // Create query for new password
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Save to keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    // MARK: - Load Credentials

    /// Load email password from keychain
    /// - Parameter account: Account identifier
    /// - Returns: Password string
    /// - Throws: KeychainError if load fails or password not found
    func loadPassword(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.passwordNotFound
            }
            throw KeychainError.loadFailed(status: status)
        }

        guard let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return password
    }

    // MARK: - Update Credentials

    /// Update existing password in keychain
    /// - Parameters:
    ///   - password: New password
    ///   - account: Account identifier
    /// - Throws: KeychainError if update fails
    private func updatePassword(_ password: String, for account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: passwordData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.updateFailed(status: status)
        }
    }

    // MARK: - Delete Credentials

    /// Delete password from keychain
    /// - Parameter account: Account identifier
    /// - Throws: KeychainError if delete fails
    func deletePassword(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    // MARK: - Check Password Exists

    /// Check if password exists for account
    /// - Parameter account: Account identifier
    /// - Returns: True if password exists
    private func passwordExists(for account: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            return true
        } else if status == errSecItemNotFound {
            return false
        } else {
            throw KeychainError.checkFailed(status: status)
        }
    }

    // MARK: - OAuth2 Tokens

    /// Save OAuth2 access token to keychain
    /// - Parameters:
    ///   - token: Access token to store
    ///   - account: Account identifier
    /// - Throws: KeychainError if save fails
    func saveOAuth2AccessToken(_ token: String, for account: String) throws {
        try saveOAuth2Token(token, type: "access", for: account)
    }

    /// Save OAuth2 refresh token to keychain
    /// - Parameters:
    ///   - token: Refresh token to store
    ///   - account: Account identifier
    /// - Throws: KeychainError if save fails
    func saveOAuth2RefreshToken(_ token: String, for account: String) throws {
        try saveOAuth2Token(token, type: "refresh", for: account)
    }

    /// Load OAuth2 access token from keychain
    /// - Parameter account: Account identifier
    /// - Returns: Access token string
    /// - Throws: KeychainError if load fails
    func loadOAuth2AccessToken(for account: String) throws -> String {
        try loadOAuth2Token(type: "access", for: account)
    }

    /// Load OAuth2 refresh token from keychain
    /// - Parameter account: Account identifier
    /// - Returns: Refresh token string
    /// - Throws: KeychainError if load fails
    func loadOAuth2RefreshToken(for account: String) throws -> String {
        try loadOAuth2Token(type: "refresh", for: account)
    }

    /// Delete OAuth2 tokens for account
    /// - Parameter account: Account identifier
    /// - Throws: KeychainError if delete fails
    func deleteOAuth2Tokens(for account: String) throws {
        try? deleteOAuth2Token(type: "access", for: account)
        try? deleteOAuth2Token(type: "refresh", for: account)
    }

    // MARK: - OAuth2 Token Helpers

    /// Save OAuth2 token to keychain
    private func saveOAuth2Token(_ token: String, type: String, for account: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let tokenAccount = "\(account).\(type)"

        // Check if token already exists
        if try tokenExists(for: tokenAccount) {
            // Update existing token
            try updateOAuth2Token(token, for: tokenAccount)
            return
        }

        // Create query for new token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    /// Load OAuth2 token from keychain
    private func loadOAuth2Token(type: String, for account: String) throws -> String {
        let tokenAccount = "\(account).\(type)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.passwordNotFound
            }
            throw KeychainError.loadFailed(status: status)
        }

        guard let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return token
    }

    /// Update OAuth2 token in keychain
    private func updateOAuth2Token(_ token: String, for tokenAccount: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.updateFailed(status: status)
        }
    }

    /// Delete OAuth2 token from keychain
    private func deleteOAuth2Token(type: String, for account: String) throws {
        let tokenAccount = "\(account).\(type)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    /// Check if OAuth2 token exists
    private func tokenExists(for tokenAccount: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            return true
        } else if status == errSecItemNotFound {
            return false
        } else {
            throw KeychainError.checkFailed(status: status)
        }
    }

    // MARK: - Delete All Credentials

    /// Delete all passwords from keychain (use with caution!)
    func deleteAllPasswords() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// MARK: - Keychain Error

enum KeychainError: Error, LocalizedError {
    case invalidData
    case passwordNotFound
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case updateFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case checkFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid password data"
        case .passwordNotFound:
            return "Password not found in keychain"
        case .saveFailed(let status):
            return "Failed to save password to keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load password from keychain (status: \(status))"
        case .updateFailed(let status):
            return "Failed to update password in keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete password from keychain (status: \(status))"
        case .checkFailed(let status):
            return "Failed to check password in keychain (status: \(status))"
        }
    }
}

// MARK: - Account Extension

extension Account {

    /// Save password to keychain
    func savePassword(_ password: String) throws {
        try KeychainManager.shared.savePassword(password, for: keychainIdentifier)
    }

    /// Load password from keychain
    func loadPassword() throws -> String {
        return try KeychainManager.shared.loadPassword(for: keychainIdentifier)
    }

    /// Delete password from keychain
    func deletePassword() throws {
        try KeychainManager.shared.deletePassword(for: keychainIdentifier)
    }
}
