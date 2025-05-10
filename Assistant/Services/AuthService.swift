//
//  AuthService.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation

class AuthService {
    // 单例模式
    static let shared = AuthService()
    private init() {}
    
    // 添加公开方法获取学生信息
    func getStudentInfo(studentId: String) async -> String? {
        return await extractStudentInfo(studentId: studentId)
    }
    
    // 优化验证会话是否有效的方法
    func validateSessionState() async -> Bool {
        do {
            print("开始验证会话状态...")
            
            // 先检查Cookie
            let cookies = NetworkService.shared.getCookies()
            if cookies.isEmpty {
                print("验证会话：没有Cookie，会话无效")
                return false
            }
            
            print("验证会话：找到\(cookies.count)个Cookie")
            
            // 获取上次使用的主机索引并设置
            let lastHostIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastHostIndex)
            print("验证会话：使用上次登录的主机索引：\(lastHostIndex)")
            NetworkService.shared.setHost(index: lastHostIndex)
            
            // 尝试获取用户信息 - 这是最可靠的验证方式
            if let studentInfo = await getStudentInfo(studentId: "") {
                print("验证会话：成功获取学生信息 [\(studentInfo)]，会话有效")
                return true
            }
            
            // 如果无法获取用户信息，尝试更基本的页面访问验证
            print("验证会话：无法获取学生信息，尝试验证页面访问...")
            
            let studentInfoPath = Constants.API.studentInfoPath
            print("验证会话：请求学生信息页面: \(studentInfoPath)")
            
            let studentInfoHtml = try await NetworkService.shared.getHtml(path: studentInfoPath)
            
            // 检查HTML内容是否包含登录表单
            let hasLoginForm = studentInfoHtml.contains("id=\"loginForm\"") ||
                              studentInfoHtml.contains("name=\"loginForm\"") ||
                              studentInfoHtml.contains("用户登录")
            
            if hasLoginForm {
                print("验证会话：页面包含登录表单，会话无效")
                return false
            }
            
            // 检查是否包含学生信息标记或菜单标记
            let hasStudentInfo = studentInfoHtml.contains("xh") ||
                                studentInfoHtml.contains("xm") ||
                                studentInfoHtml.contains("学号") ||
                                studentInfoHtml.contains("menuDivId")
            
            if hasStudentInfo {
                print("验证会话：页面包含学生信息标记，会话有效")
                return true
            }
            
            print("验证会话：无法确定会话状态，假定无效")
            return false
        } catch {
            print("验证会话：发生错误 - \(error)")
            return false
        }
    }
    
    // 教务系统登录
    func login(studentId: String, password: String, hostIndex: Int = 0) async throws -> AuthResponse {
        print("\n============ 开始教务系统登录 ============")
        print("学号: \(studentId)")
        print("密码长度: \(password.count)位")
        print("主机索引: \(hostIndex)")
        
        // 设置教务系统主机
        NetworkService.shared.setHost(index: hostIndex)
        
        // 首先检查是否已经登录
        print("检查是否已登录...")
        let isAlreadyLoggedIn = await validateSessionState()
        if isAlreadyLoggedIn {
            print("用户已经处于登录状态，无需重新登录")
            
            // 获取学生信息
            let studentName = await extractStudentInfo(studentId: studentId)
            
            // 返回成功响应
            return AuthResponse(
                success: true,
                message: "已处于登录状态",
                cookies: NetworkService.shared.getCookies(),
                studentName: studentName,
                token: nil
            )
        }
        
        // 清除旧Cookie - 只在未登录时清除，避免破坏有效会话
        print("清除旧Cookie")
        NetworkService.shared.clearCookies()
        
        // 步骤1: 获取登录页面以获取CSRF令牌
        print("\n步骤1: 获取登录页面和CSRF令牌")
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let loginPagePath = "\(Constants.API.eaLoginPath)?time=\(timestamp)"
        
        print("请求登录页面: \(loginPagePath)")
        let loginPageHtml = try await NetworkService.shared.getHtml(path: loginPagePath)
        
        // 检查是否已重定向到登录成功页面
        if loginPageHtml.contains("id=\"menuDivId\"") || loginPageHtml.contains("index_initMenu") {
            print("检测到已重定向到登录成功页面，用户已登录")
            
            // 获取学生信息
            let studentName = await extractStudentInfo(studentId: studentId)
            
            // 保存当前主机索引
            UserDefaults.standard.set(hostIndex, forKey: Constants.UserDefaultsKey.lastHostIndex)
            
            // 返回成功响应
            return AuthResponse(
                success: true,
                message: "登录成功(已登录状态)",
                cookies: NetworkService.shared.getCookies(),
                studentName: studentName,
                token: nil
            )
        }
        
        // 提取CSRF令牌
        guard let csrfToken = extractCSRFToken(from: loginPageHtml) else {
            print("错误: 未找到CSRF令牌")
            throw AuthError.csrfTokenNotFound
        }
        
        print("成功获取CSRF令牌: \(csrfToken)")
        
        // 步骤2: 获取RSA公钥
        print("\n步骤2: 获取RSA公钥")
        let publicKeyPath = Constants.API.eaLoginPublicKeyPath
        let publicKeyParams: [String: Any] = ["time": timestamp, "_": timestamp]
        
        struct PublicKeyResponse: Codable {
            let modulus: String
            let exponent: String
        }
        
        // 设置Referer头
        let publicKeyHeaders = [
            "Referer": NetworkService.shared.getFullUrl(path: loginPagePath)?.absoluteString ?? ""
        ]
        
        print("请求公钥: \(publicKeyPath)")
        let publicKeyResponse = try await NetworkService.shared.get(
            path: publicKeyPath,
            params: publicKeyParams,
            headers: publicKeyHeaders,
            responseType: PublicKeyResponse.self
        )
        
        print("获取到公钥: modulus=\(publicKeyResponse.modulus.prefix(20))... exponent=\(publicKeyResponse.exponent)")
        
        // 步骤3: 加密密码
        print("\n步骤3: 加密密码")
        guard let encryptedPassword = RSAEncryptor.encryptPassword(password, modulus: publicKeyResponse.modulus, exponent: publicKeyResponse.exponent) else {
            print("错误: 密码加密失败")
            throw AuthError.passwordEncryptionFailed
        }
        
        print("密码加密成功")
        
        // 步骤4: 提交登录请求
        print("\n步骤4: 提交登录请求")

        // 创建表单数据 - 参照JavaScript的URLSearchParams实现
        func urlEncodeComponent(_ string: String) -> String {
            // 创建一个比标准URLQueryAllowed更严格的字符集
            // 确保加号(+)、斜杠(/)、等号(=)等都被编码
            var allowedCharacters = CharacterSet.urlQueryAllowed
            allowedCharacters.remove(charactersIn: "+/=,")
            
            return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
        }

        // 构建表单参数，与JavaScript版本的表单处理保持一致
        let formItems = [
            "csrftoken=\(urlEncodeComponent(csrfToken))",
            "yhm=\(urlEncodeComponent(studentId))",
            "mm=\(urlEncodeComponent(encryptedPassword))",
            "mm=\(urlEncodeComponent(encryptedPassword))",  // 重复mm参数与原始一致
            "language=zh_CN"
        ]

        // 将所有参数连接成表单字符串
        let loginFormString = formItems.joined(separator: "&")

        let loginUrl = NetworkService.shared.getFullUrl(path: Constants.API.eaLoginPath)?.absoluteString ?? ""
        let loginHeaders = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Referer": NetworkService.shared.getFullUrl(path: loginPagePath)?.absoluteString ?? "",
            "Origin": NetworkService.shared.getFullUrl(path: "")?.absoluteString ?? "",
            "Upgrade-Insecure-Requests": "1",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Cache-Control": "max-age=0"
        ]

        print("登录请求URL: \(loginUrl)")
        print("登录请求表单数据: \(loginFormString)")

        // 直接发送表单字符串
        let loginResult = try await NetworkService.shared.postRawForm(
            path: Constants.API.eaLoginPath,
            formString: loginFormString,
            headers: loginHeaders
        )
        
        // 步骤5: 分析登录结果
        print("\n步骤5: 分析登录结果")
        print("登录响应状态码: \(loginResult.statusCode)")
        
        // 特别处理JSESSIONID cookie
        if let cookies = loginResult.cookies, !cookies.isEmpty {
            print("登录响应返回的Cookie: \(cookies)")
            
            // 保存所有Cookie - 关键修改点
            NetworkService.shared.setCookies(cookies)
            print("已保存所有登录Cookie到NetworkService")
            
            // 确保持久化到用户默认值
            UserDefaults.standard.synchronize()
            print("已同步Cookie到持久化存储")
        }
        
        // 优先处理302状态码，表示登录成功
        if loginResult.statusCode == 302 {
            print("收到302重定向，登录成功")
            
            if let location = loginResult.headers?["Location"] as? String {
                print("重定向位置: \(location)")
                
                // 尝试跟踪重定向获取更多Cookie
                if !location.isEmpty {
                    try? await followRedirect(location: location)
                }
                
                // 保存当前主机索引
                UserDefaults.standard.set(hostIndex, forKey: Constants.UserDefaultsKey.lastHostIndex)
                
                // 获取学生信息
                let studentName = await extractStudentInfo(studentId: studentId)
                
                // 再次保存最终的Cookie
                let finalCookies = NetworkService.shared.getCookies()
                print("最终Cookie数量: \(finalCookies.count)")
                
                // 返回成功响应
                return AuthResponse(
                    success: true,
                    message: "登录成功",
                    cookies: finalCookies,
                    studentName: studentName,
                    token: nil
                )
            }
        } else {
            print("登录失败，状态码: \(loginResult.statusCode)")
            
            // 备用验证方法: 尝试访问需要登录的页面来验证
            print("\n尝试备用验证方法")
            let personalInfoUrl = "jwglxt/xsxxxggl/xsxxwh_cxCkDgxsxx.html?gnmkdm=N100801"
            
            do {
                // 尝试访问个人信息页面
                let personalInfoHtml = try await NetworkService.shared.getHtml(path: personalInfoUrl)
                
                // 检查页面是否包含学生信息，验证登录状态
                if isValidLoggedInPage(personalInfoHtml) {
                    print("备用验证成功")
                    
                    // 保存当前主机索引
                    UserDefaults.standard.set(hostIndex, forKey: Constants.UserDefaultsKey.lastHostIndex)
                    
                    // 获取学生信息
                    let studentName = await extractStudentInfo(studentId: studentId)
                    
                    // 再次保存Cookie
                    let finalCookies = NetworkService.shared.getCookies()
                    print("备用验证成功后的Cookie数量: \(finalCookies.count)")
                    
                    return AuthResponse(
                        success: true,
                        message: "登录成功（备用验证）",
                        cookies: finalCookies,
                        studentName: studentName,
                        token: nil
                    )
                } else {
                    print("备用验证失败: 页面不包含学生信息")
                }
            } catch {
                print("备用验证失败: \(error)")
            }
            
            // 检查原始响应中是否有错误信息
            if let htmlData = loginResult.data, !htmlData.isEmpty {
                let errorMessage = extractErrorMessage(from: htmlData)
                print("错误信息: \(errorMessage)")
                throw AuthError.loginFailed(errorMessage)
            }
        }
        
        print("登录尝试失败，无法确定具体原因")
        throw AuthError.loginFailed("登录失败，请检查用户名和密码")
    }
    
    // 跟踪重定向
    private func followRedirect(location: String) async throws {
        do {
            print("跟踪重定向: \(location)")
            
            // 构建完整URL
            var redirectUrl = location
            
            // 如果是相对URL，转换为绝对URL
            if !location.hasPrefix("http") {
                if location.hasPrefix("/") {
                    redirectUrl = "\(Constants.API.scheme)://\(NetworkService.shared.currentHost)\(location)"
                } else {
                    redirectUrl = "\(Constants.API.scheme)://\(NetworkService.shared.currentHost)/\(location)"
                }
            }
            
            print("完整重定向URL: \(redirectUrl)")
            
            // 请求重定向URL
            let redirectHtml = try await NetworkService.shared.getHtml(url: redirectUrl)
            
            print("重定向页面获取成功，HTML长度: \(redirectHtml.count)")
            
            // 可能存在二次重定向，如果HTML包含meta refresh或JavaScript跳转
            if redirectHtml.contains("window.location") || redirectHtml.contains("<meta http-equiv=\"refresh\"") {
                print("检测到可能的二次重定向")
                
                // 尝试提取二次重定向URL
                if let secondRedirectUrl = extractRedirectUrl(from: redirectHtml) {
                    print("提取到二次重定向URL: \(secondRedirectUrl)")
                    
                    // 跟踪二次重定向
                    let secondRedirectHtml = try await NetworkService.shared.getHtml(url: secondRedirectUrl)
                    print("二次重定向页面获取成功，HTML长度: \(secondRedirectHtml.count)")
                }
            }
            
            // 确保保存新获取的Cookie
            let currentCookies = NetworkService.shared.getCookies()
            print("重定向后当前Cookie数量: \(currentCookies.count)")
            
            // 持久化保存Cookie
            UserDefaults.standard.synchronize()
        } catch {
            print("跟踪重定向失败: \(error)")
            // 即使重定向失败，登录可能仍然成功，所以只记录错误但不抛出
        }
    }
    
    // 判断页面是否是有效的已登录页面
    private func isValidLoggedInPage(_ pageContent: String) -> Bool {
        return pageContent.count > 0 &&
               !pageContent.contains("无功能权限") &&
               !pageContent.contains("id=\"yhm\"") &&
               !pageContent.contains("name=\"yhm\"") &&
               (pageContent.contains("xh") ||
                pageContent.contains("xm") ||
                pageContent.contains("menuDivId"))
    }
    
    // 提取学生信息
    private func extractStudentInfo(studentId: String) async -> String? {
        do {
            print("尝试获取学生信息")
            let studentInfoPath = Constants.API.studentInfoPath
            
            let studentInfoHtml = try await NetworkService.shared.getHtml(path: studentInfoPath)
            
            if let name = extractStudentName(from: studentInfoHtml) {
                print("从学生信息页面提取到姓名: \(name)")
                return name
            }
            
            // 如果从学生信息页提取失败，从首页提取
            let homeHtml = try await NetworkService.shared.getHtml(path: "jwglxt/xtgl/index_initMenu.html")
            
            // 尝试提取欢迎信息
            let welcomePattern = "欢迎[^，。]*([\\u4e00-\\u9fa5]{2,5})同学"
            if let welcomeRegex = try? NSRegularExpression(pattern: welcomePattern, options: []),
               let match = welcomeRegex.firstMatch(in: homeHtml, options: [], range: NSRange(location: 0, length: homeHtml.utf16.count)),
               let nameRange = Range(match.range(at: 1), in: homeHtml) {
                
                let name = String(homeHtml[nameRange])
                print("从首页欢迎信息提取到姓名: \(name)")
                return name
            }
            
            print("无法提取学生姓名")
            return nil
        } catch {
            print("获取学生信息失败: \(error)")
            return nil
        }
    }
    
    // 提取CSRF令牌
    private func extractCSRFToken(from html: String) -> String? {
        // 尝试多种模式匹配
        let patterns = [
            "<input[^>]+name=\"csrftoken\"[^>]+value=\"([^\"]+)\"",
            "<input[^>]+value=\"([^\"]+)\"[^>]+name=\"csrftoken\"",
            "id=\"csrftoken\"\\s+value=\"([^\"]+)\"",
            "name=\"csrftoken\"\\s+value=\"([^\"]+)\""
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(html.startIndex..<html.endIndex, in: html)
                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    if let tokenRange = Range(match.range(at: 1), in: html) {
                        let token = String(html[tokenRange])
                        print("使用模式 '\(pattern)' 提取到CSRF令牌: \(token)")
                        return token
                    }
                }
            }
        }
        
        print("使用所有模式均未找到CSRF令牌")
        
        // 尝试使用更宽松的搜索 - 查找name为csrftoken的输入框
        if let range = html.range(of: "name=\"csrftoken\"") {
            // 在这附近查找value属性
            let start = html.index(range.lowerBound, offsetBy: -100, limitedBy: html.startIndex) ?? html.startIndex
            let end = html.index(range.upperBound, offsetBy: 100, limitedBy: html.endIndex) ?? html.endIndex
            let snippet = String(html[start..<end])
            
            print("CSRF令牌附近的HTML片段: \(snippet)")
            
            // 在片段中查找value属性
            if let valueRange = snippet.range(of: "value=\"", options: [.caseInsensitive]) {
                let valueStart = valueRange.upperBound
                if let valueEnd = snippet[valueStart...].range(of: "\"") {
                    let token = String(snippet[valueStart..<valueEnd.lowerBound])
                    print("使用宽松搜索找到CSRF令牌: \(token)")
                    return token
                }
            }
        }
        
        return nil
    }
    
    // 提取学生姓名
    private func extractStudentName(from html: String) -> String? {
        // 尝试多种模式匹配
        let patterns = [
            "<input[^>]*id=\"xm\"[^>]*value=\"([^\"]+)\"",
            "<input[^>]*name=\"xm\"[^>]*value=\"([^\"]+)\"",
            "<input[^>]*value=\"([^\"]+)\"[^>]*id=\"xm\"",
            "<span[^>]*id=\"xm\"[^>]*>([^<]+)</span>",
            "<p[^>]*id=\"xm\"[^>]*>([^<]+)</p>",
            "<div[^>]*id=\"xhxm\"[^>]*>([^<]+)</div>",
            "\"xm\":\"([^\"]+)\""
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range) {
                if let nameRange = Range(match.range(at: 1), in: html) {
                    let name = String(html[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    print("使用模式 '\(pattern)' 提取到姓名: \(name)")
                    return name
                }
            }
        }
        
        print("使用所有模式均未找到学生姓名")
        return nil
    }
    
    // 从HTML中提取重定向URL
    private func extractRedirectUrl(from html: String) -> String? {
        // 1. 尝试查找JavaScript重定向
        let jsPatterns = [
            "window.location.href\\s*=\\s*['\"]([^'\"]+)['\"]",
            "window.location\\s*=\\s*['\"]([^'\"]+)['\"]",
            "location.href\\s*=\\s*['\"]([^'\"]+)['\"]",
            "location.replace\\(['\"]([^'\"]+)['\"]\\)"
        ]
        
        for pattern in jsPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let urlRange = Range(match.range(at: 1), in: html) {
                
                let url = String(html[urlRange])
                print("从JavaScript找到重定向URL: \(url)")
                return url
            }
        }
        
        // 2. 尝试查找meta refresh
        let metaPattern = "<meta\\s+http-equiv=['\"]refresh['\"][^>]*content=['\"][^'\"]*url=([^'\"]+)['\"]"
        if let regex = try? NSRegularExpression(pattern: metaPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           let urlRange = Range(match.range(at: 1), in: html) {
            
            let url = String(html[urlRange])
            print("从meta refresh找到重定向URL: \(url)")
            return url
        }
        
        print("未找到重定向URL")
        return nil
    }
    
    // 从HTML中提取错误信息
    private func extractErrorMessage(from html: String) -> String {
        // 尝试从tips div提取错误信息
        if let tipsRegex = try? NSRegularExpression(pattern: "<div[^>]*id=['\"]tips['\"][^>]*>(.*?)</div>", options: []),
           let match = tipsRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           let messageRange = Range(match.range(at: 1), in: html) {
            
            let message = String(html[messageRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !message.isEmpty {
                return message
            }
        }
        
        // 尝试从其他常见错误位置提取
        let errorPatterns = [
            "<div[^>]*class=['\"]alert['\"][^>]*>(.*?)</div>",
            "<span[^>]*class=['\"]error['\"][^>]*>(.*?)</span>",
            "<p[^>]*class=['\"]error['\"][^>]*>(.*?)</p>"
        ]
        
        for pattern in errorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let messageRange = Range(match.range(at: 1), in: html) {
                
                let message = String(html[messageRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !message.isEmpty {
                    return message
                }
            }
        }
        
        return "登录失败，请检查用户名和密码"
    }
}

// 认证错误枚举
enum AuthError: Error {
    case csrfTokenNotFound
    case passwordEncryptionFailed
    case loginFailed(String)
    case userNotFound
    case networkError(String)
    
    var errorMessage: String {
        switch self {
        case .csrfTokenNotFound:
            return "未找到CSRF令牌"
        case .passwordEncryptionFailed:
            return "密码加密失败"
        case .loginFailed(let message):
            return "登录失败: \(message)"
        case .userNotFound:
            return "用户不存在"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}
