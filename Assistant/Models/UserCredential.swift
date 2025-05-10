//
//  UserCredential.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation

struct UserCredential: Codable {
    let studentId: String
    let password: String
    var token: String?
    var cookies: [String]?
    var studentName: String?
    var entranceYear: Int?
    var lastSelectedHost: Int?
    var autoLogin: Bool? // 新增字段
    
    enum CodingKeys: String, CodingKey {
        case studentId, password, token, cookies, studentName, entranceYear, lastSelectedHost, autoLogin
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String?
    let cookies: [String]?
    let studentName: String?
    let token: String?
}

struct LoginResponse: Decodable {
    let status: Int
    let success: Bool
    let cookies: [String]?
    let data: String?
    let location: String?
    let headers: [String: String]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case status, success, cookies, data, location, headers, error
    }
    
    // 添加自定义初始化方法，处理可能的解码失败
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 0
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        cookies = try container.decodeIfPresent([String].self, forKey: .cookies)
        data = try container.decodeIfPresent(String.self, forKey: .data)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    // 添加常规初始化方法，方便手动创建实例
    init(status: Int, success: Bool, cookies: [String]?, data: String?, location: String?, headers: [String: String]?, error: String?) {
        self.status = status
        self.success = success
        self.cookies = cookies
        self.data = data
        self.location = location
        self.headers = headers
        self.error = error
    }
}
