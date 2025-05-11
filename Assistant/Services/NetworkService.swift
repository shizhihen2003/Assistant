//
//  NetworkService.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation

class NetworkService {
    // 单例模式
    static let shared = NetworkService()
    private init() {}
    
    // 当前使用的教务系统主机
    private(set) var currentHost = Constants.API.eaHosts[0]
    private var cookies: [String] = []
    
    // Cookie存储的键名
    private let cookieStorageKey = "com.ujn.assistant.cookies"
    
    // 在 NetworkService 类中添加
    private class NoRedirectsDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            // 返回 nil 以阻止重定向
            completionHandler(nil)
        }
    }
    
    // 添加不自动重定向的会话
    private lazy var nonRedirectSession: URLSession = {
        let noRedirectDelegate = NoRedirectsDelegate()
        return URLSession(configuration: .default, delegate: noRedirectDelegate, delegateQueue: nil)
    }()
    
    // 设置当前使用的教务系统主机
    func setHost(index: Int) {
        if index >= 0 && index < Constants.API.eaHosts.count {
            currentHost = Constants.API.eaHosts[index]
            print("已设置教务系统主机为: \(currentHost) (索引 \(index))")
        } else {
            print("警告：主机索引 \(index) 超出范围，使用默认主机")
            currentHost = Constants.API.eaHosts[0]
        }
    }
    
    // 设置Cookie
    func setCookies(_ newCookies: [String]) {
        print("设置Cookie: \(newCookies.count)个")
        
        if newCookies.isEmpty {
            print("没有Cookie可设置")
            return
        }
        
        // 处理所有Cookie
        var processedCookies: [String] = []
        
        for cookie in newCookies {
            // 处理cookie值，确保我们只保留name=value部分
            if let semicolonIndex = cookie.firstIndex(of: ";") {
                let nameValuePair = String(cookie[..<semicolonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if nameValuePair.contains("=") {
                    processedCookies.append(nameValuePair)
                    print("处理Cookie: \(nameValuePair)")
                }
            } else if cookie.contains("=") {
                processedCookies.append(cookie.trimmingCharacters(in: .whitespacesAndNewlines))
                print("处理Cookie: \(cookie.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        // 特别处理JSESSIONID
        let jsessionidCookies = processedCookies.filter { $0.hasPrefix("JSESSIONID=") }
        let otherCookies = processedCookies.filter { !$0.hasPrefix("JSESSIONID=") }
        
        // 确保有有效的Cookie
        if !processedCookies.isEmpty {
            if !jsessionidCookies.isEmpty {
                print("设置包含JSESSIONID的Cookie: \(jsessionidCookies)")
                // JSESSIONID在前
                self.cookies = jsessionidCookies + otherCookies
            } else {
                self.cookies = processedCookies
            }
            
            // 持久化保存
            UserDefaults.standard.set(self.cookies, forKey: cookieStorageKey)
            UserDefaults.standard.synchronize()
            
            print("设置完成，当前共有 \(self.cookies.count) 个Cookie")
            
            // 验证是否包含JSESSIONID
            if self.cookies.contains(where: { $0.hasPrefix("JSESSIONID=") }) {
                print("成功设置包含JSESSIONID的Cookie")
            } else {
                print("警告：设置的Cookie中不包含JSESSIONID")
            }
        }
    }
    
    // 加载Cookie
    func loadCookiesFromStorage() {
        if let savedCookies = UserDefaults.standard.stringArray(forKey: cookieStorageKey) {
            if !savedCookies.isEmpty {
                // 确保只加载有效的Cookie
                let validCookies = savedCookies.filter { $0.contains("=") }
                self.cookies = validCookies
                
                print("从存储加载了 \(self.cookies.count) 个Cookie")
                
                // 检查是否包含JSESSIONID
                if let jsessionid = self.cookies.first(where: { $0.hasPrefix("JSESSIONID=") }) {
                    print("加载的Cookie中包含JSESSIONID: \(jsessionid)")
                } else {
                    print("警告：加载的Cookie中不包含JSESSIONID")
                }
            } else {
                print("存储中的Cookie数组为空")
            }
        } else {
            print("未找到存储的Cookie")
        }
    }
    
    // 添加单个Cookie
    func addCookie(_ cookie: String) {
        // 提取名称=值部分
        var cookieNameValue = cookie
        if let separatorIndex = cookie.firstIndex(of: ";") {
            cookieNameValue = String(cookie[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if cookieNameValue.contains("=") {
            // 获取Cookie名称
            if let equalsIndex = cookieNameValue.firstIndex(of: "=") {
                let cookieName = String(cookieNameValue[..<equalsIndex])
                
                // 检查是否已存在同名Cookie
                if let index = self.cookies.firstIndex(where: { $0.hasPrefix("\(cookieName)=") }) {
                    // 替换已有Cookie
                    self.cookies[index] = cookieNameValue
                    print("替换已有Cookie: \(cookieName)")
                } else {
                    // 添加新Cookie
                    self.cookies.append(cookieNameValue)
                    print("添加新Cookie: \(cookieName)")
                }
                
                // 持久化Cookie到UserDefaults
                UserDefaults.standard.set(self.cookies, forKey: cookieStorageKey)
                UserDefaults.standard.synchronize() // 强制立即保存
            }
        }
    }
    
    // 清除所有Cookie
    func clearCookies() {
        // 清除内存中的cookies
        self.cookies = []
        
        // 清除UserDefaults中保存的cookies
        UserDefaults.standard.removeObject(forKey: cookieStorageKey)
        UserDefaults.standard.synchronize() // 强制立即保存
        
        // 清除系统HTTPCookieStorage中的cookies
        if let cookieStorage = HTTPCookieStorage.shared.cookies {
            for cookie in cookieStorage {
                // 只删除与当前主机相关的cookie
                let domain = cookie.domain
                // 检查域名是否匹配（忽略大小写）
                if domain.lowercased().contains(currentHost.lowercased()) ||
                   currentHost.lowercased().contains(domain.lowercased()) {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                    print("已删除系统Cookie: \(cookie.name) 域名: \(domain)")
                }
            }
        }
        
        print("已清除全部Cookie并从存储中移除")
    }
    
    // 获取当前Cookie
    func getCookies() -> [String] {
        return self.cookies
    }
    
    // 获取Cookie字符串
    func getCookieString() -> String {
        return self.cookies.joined(separator: "; ")
    }
    
    // 组装完整的URL
    func getFullUrl(path: String) -> URL? {
        guard !currentHost.isEmpty else { return nil }
        
        // 确保路径格式正确
        let formattedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(Constants.API.scheme)://\(currentHost)/\(formattedPath)")
    }
    
    // 创建请求
    private func createRequest(url: URL, method: String, params: [String: Any]? = nil, headers: [String: String]? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 设置请求头 - 更改为桌面浏览器UA
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // 添加必要的浏览器类请求头 - 可能的重定向问题
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        if !cookies.isEmpty {
            let cookieString = cookies.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
            print("设置Cookie请求头: \(cookieString)")
        }
        
        // 添加自定义请求头
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 设置请求体参数
        if let params = params, method == "POST" {
            if let contentType = headers?["Content-Type"], contentType.contains("application/json") {
                // JSON格式
                if let jsonData = try? JSONSerialization.data(withJSONObject: params) {
                    request.httpBody = jsonData
                }
            } else {
                // 修复: 表单格式处理，支持重复参数
                let formData = params.map { key, value in
                    let stringValue = "\(value)"
                    let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let escapedValue = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    return "\(escapedKey)=\(escapedValue)"
                }.joined(separator: "&")
                
                request.httpBody = formData.data(using: .utf8)
                
                if headers == nil || headers?["Content-Type"] == nil {
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        
        return request
    }
    
    // 创建表单字符串请求 - 新增，用于处理重复参数
    func createFormStringRequest(url: URL, method: String, formString: String, headers: [String: String]? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 设置请求头 - 桌面浏览器UA
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // 添加必要的浏览器类请求头 - 修复重定向问题
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        if !cookies.isEmpty {
            let cookieString = cookies.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
            print("设置Cookie请求头: \(cookieString)")
        }
        
        // 添加自定义请求头
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 直接设置表单字符串作为请求体
        request.httpBody = formString.data(using: .utf8)
        
        if headers == nil || headers?["Content-Type"] == nil {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    // 添加详细的HTTP请求日志
    private func logRequest(_ request: URLRequest) {
        print("====== HTTP请求 ======")
        print("URL: \(request.url?.absoluteString ?? "无URL")")
        print("方法: \(request.httpMethod ?? "未知")")
        
        print("请求头:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key.lowercased() == "cookie" {
                print("  \(key): [Cookie字符串很长，已省略]")
            } else {
                print("  \(key): \(value)")
            }
        }
        
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            if bodyString.count > 500 {
                print("请求体: \(bodyString.prefix(500))...(已截断)")
            } else {
                print("请求体: \(bodyString)")
            }
        }
        print("======================")
    }

    // 添加详细的HTTP响应日志
    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        print("====== HTTP响应 ======")
        print("URL: \(response.url?.absoluteString ?? "无URL")")
        print("状态码: \(response.statusCode)")
        
        // 特别处理302重定向
        if response.statusCode == 302 {
            print("收到302重定向响应")
            
            if let location = response.allHeaderFields["Location"] as? String {
                print("重定向位置: \(location)")
                
                // 判断是否是登录成功的重定向
                let isLoginSuccess = !location.contains("login")
                print("重定向URL是否不包含login: \(isLoginSuccess)")
            }
        }
        
        print("响应头:")
        for (key, value) in response.allHeaderFields {
            let keyStr = String(describing: key)
            let valueStr = String(describing: value)
            print("  \(keyStr): \(valueStr)")
        }
        
        // 处理响应体
        var bodyPreviewString = "无法解析的数据"
        
        // 尝试作为文本解析
        if let bodyString = String(data: data, encoding: .utf8) {
            if bodyString.count > 1000 {
                bodyPreviewString = "\(bodyString.prefix(1000))...(已截断)"
            } else {
                bodyPreviewString = bodyString
            }
        }
        
        print("响应体(预览):")
        print(bodyPreviewString)
        print("======================")
    }
    
    // 处理和保存响应中的Cookie - 修改后的方法
    private func processCookies(from response: HTTPURLResponse) {
        print("处理响应中的Cookie...")
        
        // 提取所有Set-Cookie头
        var cookieStrings: [String] = []
        
        for (key, value) in response.allHeaderFields {
            let keyString = String(describing: key).lowercased()
            if keyString.contains("set-cookie") {
                let valueString = String(describing: value)
                cookieStrings.append(valueString)
                print("发现Set-Cookie头: \(valueString)")
            }
        }
        
        if cookieStrings.isEmpty {
            print("响应中没有找到Cookie")
            return
        }
        
        // 优先处理包含JSESSIONID的Cookie字符串
        var jsessionidFound = false
        var jsessionidValue = ""
        
        // 首先寻找JSESSIONID
        for cookieString in cookieStrings {
            if cookieString.contains("JSESSIONID=") {
                // 使用正则表达式提取JSESSIONID的值
                let pattern = "JSESSIONID=([^;,]+)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: cookieString, options: [], range: NSRange(cookieString.startIndex..., in: cookieString)),
                   let range = Range(match.range(at: 1), in: cookieString) {
                    jsessionidValue = String(cookieString[range])
                    jsessionidFound = true
                    print("成功提取JSESSIONID值: \(jsessionidValue)")
                    break
                }
            }
        }
        
        // 处理所有Cookie
        var processedCookies: [String] = []
        
        // 如果找到JSESSIONID，将其添加到处理列表
        if jsessionidFound {
            processedCookies.append("JSESSIONID=\(jsessionidValue)")
        }
        
        // 处理其他Cookie
        for cookieString in cookieStrings {
            let parts = splitCookieString(cookieString)
            for part in parts {
                // 排除已添加的JSESSIONID
                if !part.hasPrefix("JSESSIONID=") {
                    processedCookies.append(part)
                }
            }
        }
        
        // 更新Cookie存储
        if !processedCookies.isEmpty {
            self.cookies = processedCookies
            
            // 持久化到UserDefaults
            UserDefaults.standard.set(self.cookies, forKey: cookieStorageKey)
            UserDefaults.standard.synchronize()
            
            print("Cookie处理完成，当前共有 \(self.cookies.count) 个Cookie")
            if jsessionidFound {
                print("成功捕获并保存了JSESSIONID")
            } else {
                print("警告：没有捕获到JSESSIONID")
            }
        }
    }
    
    // 修改后的splitCookieString方法 - 更好地处理复合Cookie字符串
    private func splitCookieString(_ cookieString: String) -> [String] {
        // 如果包含JSESSIONID，直接使用正则表达式提取
        if cookieString.contains("JSESSIONID=") {
            // 专门提取JSESSIONID的正则表达式
            let jsessionidPattern = "JSESSIONID=([^;,]+)"
            if let regex = try? NSRegularExpression(pattern: jsessionidPattern, options: []),
               let match = regex.firstMatch(in: cookieString, options: [], range: NSRange(cookieString.startIndex..., in: cookieString)),
               let range = Range(match.range(at: 1), in: cookieString) {
                let jsessionidValue = String(cookieString[range])
                let jsessionidCookie = "JSESSIONID=\(jsessionidValue)"
                print("成功提取JSESSIONID: \(jsessionidCookie)")
                
                // 寻找其他cookie
                var results = [jsessionidCookie]
                
                // 提取rememberMe cookie如果存在
                if cookieString.contains("rememberMe=") {
                    let rememberMePattern = "rememberMe=([^;,]+)"
                    if let regex = try? NSRegularExpression(pattern: rememberMePattern, options: []),
                       let match = regex.firstMatch(in: cookieString, options: [], range: NSRange(cookieString.startIndex..., in: cookieString)),
                       let range = Range(match.range(at: 1), in: cookieString) {
                        let rememberMeValue = String(cookieString[range])
                        results.append("rememberMe=\(rememberMeValue)")
                    }
                }
                
                return results
            }
        }
        
        // 原有的逻辑作为后备方案
        var result: [String] = []
        // 首先按逗号分割
        let mainParts = cookieString.components(separatedBy: ",")
        
        for part in mainParts {
            // 提取每个部分的name=value
            if let semicolonIndex = part.firstIndex(of: ";") {
                let nameValuePart = part[..<semicolonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if nameValuePart.contains("=") {
                    result.append(String(nameValuePart))
                }
            } else if part.contains("=") {
                result.append(part.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return result
    }
    
    // 辅助函数：从Cookie字符串中提取name=value部分
    private func extractNameValuePair(from cookieString: String) -> String {
        // 首先尝试提取第一个分号前的部分
        if let semicolonIndex = cookieString.firstIndex(of: ";") {
            let nameValuePart = cookieString[..<semicolonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return String(nameValuePart)
        } else {
            // 没有分号，整个字符串就是name=value
            return cookieString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // 特别处理Cookie但保留现有JSESSIONID
    private func processCookiesPreservingJSESSIONID(from response: HTTPURLResponse) {
        print("处理响应中的Cookie - 保留现有JSESSIONID...")
        
        // 从响应头中提取所有Cookie
        var extractedCookies: [String] = []
        
        // 从Set-Cookie头提取
        if let allHeaders = response.allHeaderFields as? [String: Any] {
            for (key, value) in allHeaders {
                let keyString = String(describing: key).lowercased()
                if keyString.contains("set-cookie") {
                    if let cookieString = value as? String {
                        // 只保留非JSESSIONID cookie
                        if !cookieString.contains("JSESSIONID=") {
                            extractedCookies.append(cookieString)
                            print("从响应头提取Cookie(非JSESSIONID): \(cookieString)")
                        } else {
                            print("忽略新的JSESSIONID Cookie: \(cookieString)")
                        }
                    } else if let cookieArray = value as? [String] {
                        for cookie in cookieArray {
                            if !cookie.contains("JSESSIONID=") {
                                extractedCookies.append(cookie)
                                print("从响应头提取Cookie(非JSESSIONID): \(cookie)")
                            } else {
                                print("忽略新的JSESSIONID Cookie: \(cookie)")
                            }
                        }
                    }
                }
            }
        }
        
        if extractedCookies.isEmpty {
            print("响应中没有找到非JSESSIONID Cookie")
            return
        }
        
        print("共提取到 \(extractedCookies.count) 个非JSESSIONID Cookie")
        
        // 处理提取到的所有Cookie
        var processedCookies: [String] = []
        
        for cookieString in extractedCookies {
            // 提取名称=值部分
            if let separatorIndex = cookieString.firstIndex(of: ";") {
                let nameValuePair = String(cookieString[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if nameValuePair.contains("=") && !nameValuePair.hasPrefix("JSESSIONID=") {
                    processedCookies.append(nameValuePair)
                    print("处理非JSESSIONID Cookie: \(nameValuePair)")
                }
            } else if cookieString.contains("=") && !cookieString.hasPrefix("JSESSIONID=") {
                processedCookies.append(cookieString.trimmingCharacters(in: .whitespacesAndNewlines))
                print("处理非JSESSIONID Cookie: \(cookieString.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        // 更新现有Cookie，但保留JSESSIONID
        if !processedCookies.isEmpty {
            // 先保存当前JSESSIONID
            let jsessionidCookies = self.cookies.filter { $0.hasPrefix("JSESSIONID=") }
            let oldOtherCookies = self.cookies.filter { !$0.hasPrefix("JSESSIONID=") }
            
            // 合并现有非JSESSIONID cookie和新的非JSESSIONID cookie
            var newOtherCookies = [String]()
            
            // 添加新cookie，替换同名cookie
            for newCookie in processedCookies {
                if let equalsIndex = newCookie.firstIndex(of: "=") {
                    let name = String(newCookie[..<equalsIndex])
                    
                    // 如果存在同名cookie，则替换
                    if oldOtherCookies.contains(where: { $0.hasPrefix("\(name)=") }) {
                        newOtherCookies.append(newCookie)
                    } else {
                        newOtherCookies.append(newCookie)
                    }
                }
            }
            
            // 添加不在新cookie中的旧cookie
            for oldCookie in oldOtherCookies {
                if let equalsIndex = oldCookie.firstIndex(of: "=") {
                    let name = String(oldCookie[..<equalsIndex])
                    
                    if !newOtherCookies.contains(where: { $0.hasPrefix("\(name)=") }) {
                        newOtherCookies.append(oldCookie)
                    }
                }
            }
            
            // 合并cookie：JSESSIONID优先
            self.cookies = jsessionidCookies + newOtherCookies
            
            // 持久化更新后的Cookie
            UserDefaults.standard.set(self.cookies, forKey: cookieStorageKey)
            UserDefaults.standard.synchronize() // 强制立即保存
            
            print("Cookie处理完成(保留JSESSIONID)，当前共有 \(self.cookies.count) 个Cookie")
        } else {
            print("没有提取到有效非JSESSIONID Cookie")
        }
    }
    
    // 执行请求
    func request<T: Decodable>(method: String, path: String, params: [String: Any]? = nil, headers: [String: String]? = nil, responseType: T.Type) async throws -> T {
        guard let url = getFullUrl(path: path) else {
            throw NetworkError.invalidURL
        }
        
        let request = createRequest(url: url, method: method, params: params, headers: headers)
        
        // 记录请求详情
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("非HTTP响应")
            }
            
            // 记录响应详情
            logResponse(httpResponse, data: data)
            
            // 处理响应头中的Cookie
            processCookies(from: httpResponse)
            
            // 修改: 优先处理302重定向，与Electron版本保持一致
            if httpResponse.statusCode == 302 {
                // 获取重定向位置
                let location = httpResponse.allHeaderFields["Location"] as? String ?? ""
                print("收到302重定向，位置: \(location)")
                
                // 教务系统登录成功后的重定向通常不包含login
                let isLoginSuccess = true // 与Electron版保持一致，任何302都是成功的
                print("判断登录状态: \(isLoginSuccess ? "成功" : "失败")")
                
                // 如果是LoginResponse类型，直接创建并返回响应对象
                if T.self == LoginResponse.self {
                    print("创建LoginResponse对象")
                    let loginResponse = LoginResponse(
                        status: httpResponse.statusCode,
                        success: isLoginSuccess,
                        cookies: self.cookies,
                        data: nil,
                        location: location,
                        headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                        error: nil
                    )
                    return loginResponse as! T
                }
                
                // 其他类型的请求，创建一个通用响应
                let redirectInfo: [String: Any] = [
                    "status": httpResponse.statusCode,
                    "success": isLoginSuccess,
                    "location": location,
                    "cookies": self.cookies,
                    "data": "",
                    "headers": httpResponse.allHeaderFields
                ]
                
                if let redirectData = try? JSONSerialization.data(withJSONObject: redirectInfo) {
                    do {
                        // 尝试解码为请求的类型
                        let result = try JSONDecoder().decode(T.self, from: redirectData)
                        return result
                    } catch {
                        print("重定向信息解码失败: \(error)")
                        throw NetworkError.decodingError
                    }
                }
            }
            
            // 尝试解析响应
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                return decodedResponse
            } catch {
                print("JSON解析错误: \(error)")
                
                // 检查是否是null响应 - 新增处理
                if let dataString = String(data: data, encoding: .utf8), dataString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    print("服务器返回了null值")
                    
                    // 创建一个通用的错误响应
                    let errorInfo: [String: Any] = [
                        "success": false,
                        "error": "服务器返回了空数据，请尝试修改查询条件",
                        "items": [],
                        "totalCount": 0,
                        "pageNum": 1,
                        "pageSize": 100
                    ]
                    
                    if let errorData = try? JSONSerialization.data(withJSONObject: errorInfo) {
                        if let result = try? JSONDecoder().decode(T.self, from: errorData) {
                            return result
                        }
                    }
                }
                
                // 如果响应不是预期的JSON格式，尝试检查是HTML还是其他格式
                if let htmlString = String(data: data, encoding: .utf8) {
                    // 检查是否是HTML
                    if htmlString.contains("<html") || htmlString.contains("<!DOCTYPE") {
                        print("接收到HTML而非JSON")
                        
                        // 检查是否是登录页面
                        if htmlString.contains("name=\"loginForm\"") || htmlString.contains("id=\"loginForm\"") ||
                           htmlString.contains("用户登录") {
                            print("检测到登录表单，登录失败")
                            
                            // 如果是LoginResponse类型，创建失败响应
                            if T.self == LoginResponse.self {
                                let loginResponse = LoginResponse(
                                    status: httpResponse.statusCode,
                                    success: false,
                                    cookies: self.cookies,
                                    data: htmlString,
                                    location: nil,
                                    headers: nil,
                                    error: "用户名或密码错误"
                                )
                                return loginResponse as! T
                            }
                            
                            throw NetworkError.unauthorized
                        }
                        
                        // 检查是否登录成功页面
                        if htmlString.contains("id=\"menuDivId\"") || htmlString.contains("欢迎您") {
                            print("检测到成功登录页面")
                            
                            // 如果是LoginResponse类型，创建成功响应
                            if T.self == LoginResponse.self {
                                let loginResponse = LoginResponse(
                                    status: 200,
                                    success: true,
                                    cookies: self.cookies,
                                    data: htmlString,
                                    location: nil,
                                    headers: nil,
                                    error: nil
                                )
                                return loginResponse as! T
                            }
                        }
                        
                        // 尝试从HTML中提取错误信息
                        var errorMessage = "服务器返回了非预期格式"
                        
                        // 尝试提取教务系统错误提示
                        let errorRegex = try? NSRegularExpression(pattern: "<div[^>]*id=['\"]tips['\"][^>]*>(.*?)</div>", options: [])
                        if let errorMatch = errorRegex?.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.utf16.count)) {
                            if let range = Range(errorMatch.range(at: 1), in: htmlString) {
                                let errorHtml = String(htmlString[range])
                                // 移除HTML标签
                                errorMessage = errorHtml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                if errorMessage.isEmpty {
                                    errorMessage = "服务器返回错误"
                                }
                                
                                print("从HTML提取到错误信息: \(errorMessage)")
                            }
                        }
                        
                        // 如果是LoginResponse类型，创建自定义响应对象
                        if T.self == LoginResponse.self {
                            let loginResponse = LoginResponse(
                                status: httpResponse.statusCode,
                                success: false,
                                cookies: self.cookies,
                                data: htmlString,
                                location: nil,
                                headers: nil,
                                error: errorMessage
                            )
                            return loginResponse as! T
                        }
                        
                        // 创建包含错误信息的通用响应
                        let errorInfo: [String: Any] = [
                            "success": false,
                            "error": errorMessage,
                            "data": htmlString,
                            "status": httpResponse.statusCode
                        ]
                        
                        if let errorData = try? JSONSerialization.data(withJSONObject: errorInfo) {
                            if let result = try? JSONDecoder().decode(T.self, from: errorData) {
                                return result
                            }
                        }
                    }
                }
                
                // 所有尝试都失败，抛出解码错误
                throw NetworkError.decodingError
            }
        } catch let urlError as URLError {
            print("URL错误: \(urlError)")
            throw NetworkError.connectionError(urlError.localizedDescription)
        } catch let networkError as NetworkError {
            print("网络错误: \(networkError)")
            throw networkError
        } catch {
            print("未知错误: \(error)")
            throw NetworkError.unknown(error.localizedDescription)
        }
    }
    
    // 新增: 支持直接提交表单字符串的POST请求
    func postFormString<T: Decodable>(path: String, formString: String, headers: [String: String]? = nil, responseType: T.Type) async throws -> T {
        guard let url = getFullUrl(path: path) else {
            throw NetworkError.invalidURL
        }
        
        let request = createFormStringRequest(url: url, method: "POST", formString: formString, headers: headers)
        
        // 记录请求详情
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("非HTTP响应")
            }
            
            // 记录响应详情
            logResponse(httpResponse, data: data)
            
            // 处理响应头中的Cookie
            processCookies(from: httpResponse)
            
            // 如果是302重定向，直接返回成功
            if httpResponse.statusCode == 302 {
                let location = httpResponse.allHeaderFields["Location"] as? String ?? ""
                print("收到302重定向，位置: \(location)")
                
                // 如果是LoginResponse类型，创建专用对象
                if T.self == LoginResponse.self {
                    let loginResponse = LoginResponse(
                        status: httpResponse.statusCode,
                        success: true,
                        cookies: self.cookies,
                        data: nil,
                        location: location,
                        headers: httpResponse.allHeaderFields as? [String: String],
                        error: nil
                    )
                    return loginResponse as! T
                }
                
                // 创建通用响应对象
                let redirectInfo: [String: Any] = [
                    "status": httpResponse.statusCode,
                    "success": true,
                    "location": location,
                    "cookies": self.cookies
                ]
                
                if let redirectData = try? JSONSerialization.data(withJSONObject: redirectInfo) {
                    if let result = try? JSONDecoder().decode(T.self, from: redirectData) {
                        return result
                    }
                }
            }
            
            // 处理正常响应 - 尝试解析为JSON
            do {
                let result = try JSONDecoder().decode(T.self, from: data)
                return result
            } catch {
                // 检查是否是null响应 - 新增处理
                if let dataString = String(data: data, encoding: .utf8), dataString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    print("服务器返回了null值")
                    
                    // 创建一个通用的错误响应
                    let errorInfo: [String: Any] = [
                        "success": false,
                        "error": "服务器返回了空数据，请尝试修改查询条件",
                        "items": [],
                        "totalCount": 0
                    ]
                    
                    if let errorData = try? JSONSerialization.data(withJSONObject: errorInfo) {
                        if let result = try? JSONDecoder().decode(T.self, from: errorData) {
                            return result
                        }
                    }
                }
                
                // 如果不是JSON，检查是否是HTML
                if let htmlString = String(data: data, encoding: .utf8) {
                    if T.self == LoginResponse.self {
                        // 创建LoginResponse对象
                        let loginResponse = LoginResponse(
                            status: httpResponse.statusCode,
                            success: false,
                            cookies: self.cookies,
                            data: htmlString,
                            location: nil,
                            headers: nil,
                            error: "登录失败，请检查用户名和密码"
                        )
                        return loginResponse as! T
                    }
                }
                throw NetworkError.decodingError
            }
        } catch {
            print("表单请求失败: \(error)")
            throw error
        }
    }
    
    // GET请求封装
    func get<T: Decodable>(path: String, params: [String: Any]? = nil, headers: [String: String]? = nil, responseType: T.Type) async throws -> T {
        return try await request(method: "GET", path: path, params: params, headers: headers, responseType: responseType)
    }
    
    // POST请求封装
    func post<T: Decodable>(path: String, params: [String: Any]? = nil, headers: [String: String]? = nil, responseType: T.Type) async throws -> T {
        return try await request(method: "POST", path: path, params: params, headers: headers, responseType: responseType)
    }
    
    // 获取HTML内容（不解析为JSON）
    func getHtml(path: String, params: [String: Any]? = nil, headers: [String: String]? = nil) async throws -> String {
        guard let url = getFullUrl(path: path) else {
            throw NetworkError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET", params: params, headers: headers)
        
        // 记录请求详情
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("非HTTP响应")
            }
            
            // 记录响应详情 (限制输出大小)
            print("====== HTTP响应(HTML) ======")
            print("URL: \(httpResponse.url?.absoluteString ?? "无URL")")
            print("状态码: \(httpResponse.statusCode)")
            
            print("响应头:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("  \(key): \(value)")
            }
            
            if let previewText = String(data: data, encoding: .utf8)?.prefix(500) {
                print("HTML内容预览(前500字符):")
                print(previewText)
            }
            print("=========================")
            
            // 处理响应头中的Cookie
            processCookies(from: httpResponse)
            
            // 处理重定向情况
            if httpResponse.statusCode >= 300 && httpResponse.statusCode < 400 {
                if let location = httpResponse.allHeaderFields["Location"] as? String {
                    print("HTML请求返回重定向到:", location)
                    
                    // 如果是绝对URL，直接使用
                    if location.lowercased().hasPrefix("http") {
                        print("重定向到绝对URL:", location)
                        
                        // 创建新请求 - 使用完整的浏览器请求头
                        var redirectHeaders: [String: String] = [
                            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                            "Cache-Control": "max-age=0",
                            "Upgrade-Insecure-Requests": "1"
                        ]
                        
                        // 设置Referer
                        redirectHeaders["Referer"] = httpResponse.url?.absoluteString ?? ""
                        
                        let redirectRequest = URLRequest(url: URL(string: location)!)
                        let (redirectData, _) = try await URLSession.shared.data(for: redirectRequest)
                        
                        if let redirectHtml = String(data: redirectData, encoding: .utf8) {
                            return redirectHtml
                        }
                    } else {
                        // 处理相对URL
                        let baseUrl = url.deletingLastPathComponent()
                        if let redirectUrl = URL(string: location, relativeTo: baseUrl) {
                            print("重定向到相对URL:", redirectUrl.absoluteString)
                            
                            // 创建新请求 - 使用完整的浏览器请求头
                            var redirectHeaders: [String: String] = [
                                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                                "Cache-Control": "max-age=0",
                                "Upgrade-Insecure-Requests": "1"
                            ]
                            
                            // 设置Referer
                            redirectHeaders["Referer"] = httpResponse.url?.absoluteString ?? ""
                            
                            let redirectRequest = URLRequest(url: redirectUrl)
                            let (redirectData, _) = try await URLSession.shared.data(for: redirectRequest)
                            
                            if let redirectHtml = String(data: redirectData, encoding: .utf8) {
                                return redirectHtml
                            }
                        }
                    }
                }
            }
            
            if let htmlString = String(data: data, encoding: .utf8) {
                return htmlString
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            print("获取HTML错误: \(error)")
            throw NetworkError.connectionError(error.localizedDescription)
        }
    }
    
    // 通用GET请求（使用任意URL，不仅仅局限于当前host）
    func getHtml(url urlString: String, headers: [String: String]? = nil) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 设置请求头 - 使用桌面User-Agent
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // 添加必要的浏览器类请求头 - 修复重定向问题
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        // 添加Referer
        let refererURL = URL(string: "\(Constants.API.scheme)://\(currentHost)/")
        request.setValue(refererURL?.absoluteString ?? "", forHTTPHeaderField: "Referer")
        
        if !cookies.isEmpty {
            let cookieString = cookies.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        }
        
        // 添加自定义请求头
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 记录请求详情
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("非HTTP响应")
            }
            
            // 记录响应详情
            print("====== HTTP响应(外部HTML) ======")
            print("URL: \(httpResponse.url?.absoluteString ?? "无URL")")
            print("状态码: \(httpResponse.statusCode)")
            
            // 处理响应头中的Cookie - 特别处理：避免覆盖现有JSESSIONID
            // 如果我们已经有JSESSIONID并且响应是200，我们应该保留旧JSESSIONID
            if httpResponse.statusCode == 200 && cookies.contains(where: { $0.contains("JSESSIONID=") }) {
                // 检查响应中是否有新的JSESSIONID
                let hasNewSessionID = httpResponse.allHeaderFields.contains { key, value in
                    let keyStr = String(describing: key).lowercased()
                    let valueStr = String(describing: value)
                    return keyStr.contains("set-cookie") && valueStr.contains("JSESSIONID=")
                }
                
                if hasNewSessionID {
                    print("⚠️ 警告：检测到重定向响应中存在新的JSESSIONID，但我们将保留现有的JSESSIONID")
                    // 处理其他非JSESSIONID cookie
                    processCookiesPreservingJSESSIONID(from: httpResponse)
                } else {
                    // 正常处理cookie
                    processCookies(from: httpResponse)
                }
            } else {
                // 正常处理cookie
                processCookies(from: httpResponse)
            }
            
            if let htmlString = String(data: data, encoding: .utf8) {
                return htmlString
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            print("获取外部HTML错误: \(error)")
            throw NetworkError.connectionError(error.localizedDescription)
        }
    }
    
    // 支持POST请求获取HTML内容
    func postHtml(path: String, params: [String: Any], headers: [String: String]? = nil) async throws -> String {
        guard let url = getFullUrl(path: path) else {
            throw NetworkError.invalidURL
        }
        
        let request = createRequest(url: url, method: "POST", params: params, headers: headers)
        
        // 记录请求详情
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("非HTTP响应")
            }
            
            // 记录响应详情 (限制输出大小)
            print("====== HTTP响应(HTML-POST) ======")
            print("URL: \(httpResponse.url?.absoluteString ?? "无URL")")
            print("状态码: \(httpResponse.statusCode)")
            
            print("响应头:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("  \(key): \(value)")
            }
            
            if let previewText = String(data: data, encoding: .utf8)?.prefix(500) {
                print("HTML内容预览(前500字符):")
                print(previewText)
            }
            print("=========================")
            
            // 处理响应头中的Cookie
            processCookies(from: httpResponse)
            
            // 处理重定向情况
            if httpResponse.statusCode >= 300 && httpResponse.statusCode < 400 {
                if let location = httpResponse.allHeaderFields["Location"] as? String {
                    print("POST返回重定向到:", location)
                    
                    // 如果是相对路径，拼接完整URL
                    var redirectUrl = location
                    if !location.lowercased().hasPrefix("http") {
                        if location.hasPrefix("/") {
                            redirectUrl = "\(Constants.API.scheme)://\(currentHost)\(location)"
                        } else {
                            // 获取当前路径的目录部分
                            let currentPath = url.path
                            let directory = currentPath.contains("/") ? String(currentPath.prefix(upTo: currentPath.lastIndex(of: "/")!)) : ""
                            redirectUrl = "\(Constants.API.scheme)://\(currentHost)\(directory)/\(location)"
                        }
                    }
                    
                    print("重定向到完整URL:", redirectUrl)
                    
                    // 发起GET请求获取重定向内容 - 使用完整的浏览器请求头
                    var redirectHeaders: [String: String] = [
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                        "Cache-Control": "max-age=0",
                        "Upgrade-Insecure-Requests": "1"
                    ]
                    
                    // 设置Referer
                    redirectHeaders["Referer"] = httpResponse.url?.absoluteString ?? ""
                    
                    if let redirectUrl = URL(string: redirectUrl) {
                        let redirectRequest = URLRequest(url: redirectUrl)
                        let (redirectData, _) = try await URLSession.shared.data(for: redirectRequest)
                        
                        if let redirectHtml = String(data: redirectData, encoding: .utf8) {
                            return redirectHtml
                        }
                    }
                }
            }
            
            if let htmlString = String(data: data, encoding: .utf8) {
                return htmlString
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            print("POST获取HTML错误: \(error)")
            throw NetworkError.connectionError(error.localizedDescription)
        }
    }

    // 发送原始表单字符串并处理二进制响应，专门用于处理登录请求
    func postRawForm(path: String, formString: String, headers: [String: String]? = nil) async throws -> (statusCode: Int, headers: [String: Any]?, data: String?, cookies: [String]?) {
        guard let url = getFullUrl(path: path) else {
            throw NetworkError.invalidURL
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置默认请求头
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 添加更多浏览器请求头
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        // 添加自定义请求头
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 设置Cookie
        if !cookies.isEmpty {
            let cookieString = cookies.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
            print("设置Cookie请求头: \(cookieString)")
        }
        
        // 设置请求体
        request.httpBody = formString.data(using: .utf8)
        
        // 记录请求详情
        print("====== 登录请求 ======")
        print("URL: \(request.url?.absoluteString ?? "无URL")")
        print("方法: \(request.httpMethod ?? "未知")")
        print("表单: \(formString)")
        
        print("请求头:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key.lowercased() == "cookie" {
                print("  \(key): [Cookie字符串很长，已省略]")
            } else {
                print("  \(key): \(value)")
            }
        }
        print("======================")
        
        do {
            // 使用不自动重定向的会话执行请求
            let (data, response) = try await nonRedirectSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("非HTTP响应")
            }
            
            // 记录响应
            print("====== 登录响应 ======")
            print("状态码: \(httpResponse.statusCode)")
            
            // 处理响应头中的Cookie
            processCookies(from: httpResponse)
            
            // 转换响应体为字符串
            let responseString = String(data: data, encoding: .utf8)
            
            // 返回状态码、响应头、响应体和Cookie
            return (
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: Any],
                data: responseString,
                cookies: self.cookies
            )
        } catch {
            print("请求失败: \(error)")
            throw error
        }
    }
}

// 网络错误枚举
enum NetworkError: Error {
    case invalidURL
    case decodingError
    case unauthorized
    case connectionError(String)
    case serverError(String)
    case unknown(String)
    
    var errorMessage: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .decodingError:
            return "数据解析错误"
        case .unauthorized:
            return "未授权，请重新登录"
        case .connectionError(let message):
            return "连接错误: \(message)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}
