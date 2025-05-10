//
//  LoginViewModel.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation
import SwiftUI

class LoginViewModel: ObservableObject {
    // 用户输入
    @Published var studentId: String = ""
    @Published var password: String = ""
    @Published var hostIndex: Int = 0
    
    // 用户信息
    @Published var studentName: String = ""
    
    // 状态
    @Published var isLoading: Bool = false
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    
    // 保存密码和自动登录
    @Published var rememberPassword: Bool = true
    @Published var autoLogin: Bool = false
    
    // 网络服务
    private let authService = AuthService.shared
    
    // 初始化
    init() {
        print("LoginViewModel初始化...")
        
        // 加载上次使用的主机索引
        self.hostIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastHostIndex)
        // 设置当前主机
        NetworkService.shared.setHost(index: self.hostIndex)
        
        // 加载保存的凭证 (从KeyChain)
        loadSavedCredentials()
        
        // 加载保存的Cookie
        NetworkService.shared.loadCookiesFromStorage()
        
        // 初始化登录状态 - 仅从UserDefaults读取，验证工作交给App启动流程
        self.isLoggedIn = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.isLoggedIn)
        print("从UserDefaults加载登录状态: \(self.isLoggedIn)")
    }
    
    // 刷新学生信息
    func refreshStudentInfo() async {
        do {
            if let studentInfo = await authService.getStudentInfo(studentId: studentId) {
                await MainActor.run {
                    self.studentName = studentInfo
                    
                    // 更新保存的凭证
                    do {
                        let credential = try KeychainManager.retrieve(
                            UserCredential.self,
                            service: "com.ujn.assistant",
                            account: Constants.KeychainKey.userCredentials
                        )
                        
                        let updatedCredential = UserCredential(
                            studentId: credential.studentId,
                            password: credential.password,
                            token: credential.token,
                            cookies: NetworkService.shared.getCookies(),
                            studentName: studentInfo,
                            entranceYear: credential.entranceYear,
                            lastSelectedHost: self.hostIndex,
                            autoLogin: credential.autoLogin // 保持用户的自动登录设置
                        )
                        
                        try KeychainManager.save(
                            item: updatedCredential,
                            service: "com.ujn.assistant",
                            account: Constants.KeychainKey.userCredentials
                        )
                        
                        print("已更新学生信息: \(studentInfo)")
                    } catch {
                        print("更新凭证失败: \(error)")
                    }
                }
            }
        } catch {
            print("刷新学生信息失败: \(error)")
        }
    }
    
    // 登录方法
    func login() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            showError = false
        }
        
        do {
            print("开始登录流程...")
            let response = try await authService.login(
                studentId: studentId,
                password: password,
                hostIndex: hostIndex
            )
            
            if response.success {
                await MainActor.run {
                    print("登录成功，保存状态...")
                    
                    // 先保存 Cookie 和凭证
                    var cookies = response.cookies ?? []
                    
                    if cookies.isEmpty {
                        cookies = NetworkService.shared.getCookies()
                        print("使用NetworkService中的Cookie: \(cookies.count)个")
                    }
                    
                    if !cookies.isEmpty {
                        NetworkService.shared.setCookies(cookies)
                        print("已设置Cookie到NetworkService: \(cookies.count)个")
                    }
                    
                    // 创建并保存凭证
                    let credential = UserCredential(
                        studentId: self.studentId,
                        password: self.rememberPassword ? self.password : "",
                        token: response.token,
                        cookies: cookies,
                        studentName: response.studentName,
                        entranceYear: nil,
                        lastSelectedHost: self.hostIndex,
                        autoLogin: self.autoLogin
                    )
                    
                    self.saveCredential(credential)
                    print("已保存凭证到KeyChain")
                    
                    // 最后更新UI状态
                    self.studentName = response.studentName ?? ""
                    UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.isLoggedIn)
                    UserDefaults.standard.synchronize()
                    
                    // 确保所有状态都保存后才更新登录状态
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                        self.isLoading = false
                        print("登录流程完成，UI状态已更新")
                    }
                }
            } else {
                await MainActor.run {
                    print("登录失败: \(response.message ?? "未知错误")")
                    self.errorMessage = response.message ?? "登录失败"
                    self.showError = true
                    self.isLoading = false
                }
            }
        } catch let authError as AuthError {
            await MainActor.run {
                print("登录失败(AuthError): \(authError.errorMessage)")
                self.errorMessage = authError.errorMessage
                self.showError = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                print("登录失败(其他错误): \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    // 登出方法
    func logout() {
        print("执行登出...")
        // 清空登录状态
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKey.isLoggedIn)
        UserDefaults.standard.synchronize() // 确保立即保存
        
        // 清空Cookie
        NetworkService.shared.clearCookies()
        
        // 更新凭证
        do {
            // 获取当前凭证
            let credential = try KeychainManager.retrieve(
                UserCredential.self,
                service: "com.ujn.assistant",
                account: Constants.KeychainKey.userCredentials
            )
            
            // 创建新凭证，保留学号但清除Cookie
            let updatedCredential = UserCredential(
                studentId: credential.studentId,
                password: rememberPassword ? credential.password : "",
                token: nil,
                cookies: nil,
                studentName: nil,
                entranceYear: credential.entranceYear,
                lastSelectedHost: hostIndex,
                autoLogin: autoLogin // 保存用户当前的自动登录设置
            )
            
            // 保存更新后的凭证
            try KeychainManager.save(
                item: updatedCredential,
                service: "com.ujn.assistant",
                account: Constants.KeychainKey.userCredentials
            )
            
            print("已清空登录状态并更新凭证")
        } catch {
            print("更新登出状态到凭证失败: \(error)")
            
            // 如果无法获取现有凭证，但仍需保存登出状态
            if !studentId.isEmpty {
                let credential = UserCredential(
                    studentId: studentId,
                    password: rememberPassword ? password : "",
                    token: nil,
                    cookies: nil,
                    studentName: nil,
                    entranceYear: nil,
                    lastSelectedHost: hostIndex,
                    autoLogin: autoLogin // 保存用户当前的自动登录设置
                )
                
                saveCredential(credential)
            }
        }
    }
    
    // 加载保存的凭证
    private func loadSavedCredentials() {
        do {
            print("从KeyChain加载凭证...")
            let credential = try KeychainManager.retrieve(
                UserCredential.self,
                service: "com.ujn.assistant",
                account: Constants.KeychainKey.userCredentials
            )
            
            self.studentId = credential.studentId
            print("已加载学号: \(credential.studentId)")
            
            if credential.password.isEmpty {
                self.rememberPassword = false
                print("未保存密码，禁用记住密码")
            } else {
                self.password = credential.password
                self.rememberPassword = true
                print("已加载保存的密码")
            }
            
            self.studentName = credential.studentName ?? ""
            if !self.studentName.isEmpty {
                print("已加载学生姓名: \(self.studentName)")
            }
            
            if let lastSelectedHost = credential.lastSelectedHost {
                self.hostIndex = lastSelectedHost
                print("已加载上次使用的主机索引: \(lastSelectedHost)")
            }
            
            // 如果有cookie，设置到NetworkService
            if let cookies = credential.cookies, !cookies.isEmpty {
                NetworkService.shared.setCookies(cookies)
                print("已从KeyChain加载Cookie: \(cookies.count)个")
            }
            
            // 加载用户的自动登录选择，如果没有保存则默认为 false
            self.autoLogin = credential.autoLogin ?? false
            print("已加载自动登录设置: \(self.autoLogin)")
            
            // 如果用户选择了自动登录但没有记住密码，或密码为空，则禁用自动登录
            if (self.autoLogin && (!self.rememberPassword || self.password.isEmpty)) {
                self.autoLogin = false
                print("由于未记住密码或密码为空，禁用自动登录")
            }
            
        } catch let keychainError as KeychainManager.KeychainError {
            if case .itemNotFound = keychainError {
                print("KeyChain中未找到凭证，可能是首次使用")
            } else {
                print("加载凭证失败: \(keychainError)")
            }
        } catch {
            print("加载凭证时发生未知错误: \(error)")
        }
    }
    
    // 保存凭证
    private func saveCredentials(response: AuthResponse) {
        print("保存登录凭证到KeyChain...")
        
        // 获取最新Cookie
        var cookies = response.cookies ?? []
        
        // 如果响应中没有Cookie，使用NetworkService中的Cookie
        if cookies.isEmpty {
            cookies = NetworkService.shared.getCookies()
            print("使用NetworkService中的Cookie: \(cookies.count)个")
        }
        
        // 确保有Cookie可保存
        if cookies.isEmpty {
            print("警告: 没有Cookie可保存！")
        }
        
        // 创建凭证对象
        let credential = UserCredential(
            studentId: studentId,
            password: rememberPassword ? password : "",
            token: response.token,
            cookies: cookies,
            studentName: response.studentName,
            entranceYear: nil,
            lastSelectedHost: hostIndex,
            autoLogin: autoLogin // 保存用户的自动登录选择
        )
        
        saveCredential(credential)
        print("已保存凭证到KeyChain")
        
        // 确保Cookie也保存到NetworkService并持久化
        if !cookies.isEmpty {
            NetworkService.shared.setCookies(cookies)
        }
    }
    
    // 保存凭证到钥匙串
    private func saveCredential(_ credential: UserCredential) {
        do {
            try KeychainManager.save(
                item: credential,
                service: "com.ujn.assistant",
                account: Constants.KeychainKey.userCredentials
            )
            print("凭证已成功保存到KeyChain")
        } catch {
            print("保存凭证失败: \(error)")
        }
    }
}
