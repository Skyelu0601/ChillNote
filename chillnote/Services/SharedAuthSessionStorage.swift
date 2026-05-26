import Foundation
import OSLog
import Supabase

enum SharedAuthSessionStorage {
    static let keychainAccessGroup = "Y6A6D9322M.com.sponteoai.chillnote.auth"
    static let keychainService = "supabase.gotrue.swift"

    static var sharedKeychain: any AuthLocalStorage {
        KeychainLocalStorage(service: keychainService, accessGroup: keychainAccessGroup)
    }
}

struct MigratingAuthLocalStorage: AuthLocalStorage {
    let primary: any AuthLocalStorage
    let fallback: any AuthLocalStorage
    private let logger = Logger(subsystem: "com.chillnote.app", category: "shared-auth-storage")

    func store(key: String, value: Data) throws {
        try primary.store(key: key, value: value)
        do {
            try fallback.store(key: key, value: value)
        } catch {
            logger.warning("Failed to mirror auth session to fallback storage: \(error.localizedDescription, privacy: .public)")
        }
    }

    func retrieve(key: String) throws -> Data? {
        if let value = try primary.retrieve(key: key) {
            return value
        }

        guard let legacyValue = try fallback.retrieve(key: key) else {
            return nil
        }

        do {
            try primary.store(key: key, value: legacyValue)
        } catch {
            logger.warning("Failed to migrate auth session from fallback storage: \(error.localizedDescription, privacy: .public)")
        }
        return legacyValue
    }

    func remove(key: String) throws {
        try primary.remove(key: key)
        do {
            try fallback.remove(key: key)
        } catch {
            logger.warning("Failed to remove auth session from fallback storage: \(error.localizedDescription, privacy: .public)")
        }
    }
}
