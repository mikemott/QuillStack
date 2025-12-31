//
//  KeychainService.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import Foundation
import Security
import os.log

// MARK: - Keychain Service

/// Secure credential storage using iOS Keychain
/// Provides encrypted storage for API keys and sensitive data
final class KeychainService {
    static let shared = KeychainService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "Keychain")

    private init() {}

    enum KeychainError: LocalizedError {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            case .invalidData:
                return "Invalid data format"
            }
        }
    }

    // MARK: - Key Identifiers

    enum Key: String {
        case claudeAPIKey = "com.quillstack.claude-api-key"
        case notionAPIKey = "com.quillstack.notion-api-key"
        case gitHubAccessToken = "com.quillstack.github-access-token"

        var service: String { "QuillStack" }
    }

    // MARK: - Public API

    /// Saves a string value to the Keychain
    func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Try to add the item
        var status = SecItemAdd(query as CFDictionary, nil)

        // If it already exists, update it
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: key.service,
                kSecAttrAccount as String: key.rawValue
            ]

            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]

            status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves a string value from the Keychain
    func retrieve(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Deletes a value from the Keychain
    func delete(for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Checks if a key exists in the Keychain
    func exists(for key: Key) -> Bool {
        retrieve(for: key) != nil
    }

    // MARK: - Migration Helper

    /// Migrates a value from UserDefaults to Keychain
    /// Returns true if migration occurred, false if nothing to migrate
    @discardableResult
    func migrateFromUserDefaults(userDefaultsKey: String, to keychainKey: Key) -> Bool {
        let defaults = UserDefaults.standard

        guard let value = defaults.string(forKey: userDefaultsKey), !value.isEmpty else {
            return false
        }

        do {
            try save(value, for: keychainKey)
            // Remove from UserDefaults after successful migration
            defaults.removeObject(forKey: userDefaultsKey)
            return true
        } catch {
            Self.logger.error("Keychain migration failed: \(error.localizedDescription)")
            return false
        }
    }
}
