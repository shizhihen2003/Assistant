//
//  KeychainManager.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation
import Security

class KeychainManager {
    
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case dataConversionError
        case itemNotFound
    }
    
    static func save<T: Codable>(item: T, service: String, account: String) throws {
        // 转换为Data
        guard let data = try? JSONEncoder().encode(item) else {
            throw KeychainError.dataConversionError
        }
        
        // 创建查询字典
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecValueData as String: data as AnyObject
        ]
        
        // 检查该条目是否已存在
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // 如果已存在，则更新
            let updateQuery: [String: AnyObject] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service as AnyObject,
                kSecAttrAccount as String: account as AnyObject
            ]
            
            let updateAttributes: [String: AnyObject] = [
                kSecValueData as String: data as AnyObject
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            
            if updateStatus != errSecSuccess {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }
    
    static func retrieve<T: Codable>(_ type: T.Type, service: String, account: String) throws -> T {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            } else {
                throw KeychainError.unknown(status)
            }
        }
        
        guard let data = result as? Data else {
            throw KeychainError.dataConversionError
        }
        
        do {
            let item = try JSONDecoder().decode(type, from: data)
            return item
        } catch {
            throw KeychainError.dataConversionError
        }
    }
    
    static func delete(service: String, account: String) throws {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
