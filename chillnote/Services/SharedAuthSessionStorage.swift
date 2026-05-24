import Foundation
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

    func store(key: String, value: Data) throws {
        try primary.store(key: key, value: value)
        try? fallback.store(key: key, value: value)
    }

    func retrieve(key: String) throws -> Data? {
        if let value = try primary.retrieve(key: key) {
            return value
        }

        guard let legacyValue = try fallback.retrieve(key: key) else {
            return nil
        }

        try? primary.store(key: key, value: legacyValue)
        return legacyValue
    }

    func remove(key: String) throws {
        try primary.remove(key: key)
        try? fallback.remove(key: key)
    }
}
