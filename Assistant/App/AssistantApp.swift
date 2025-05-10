//
//  AssistantApp.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import SwiftUI

@main
struct AssistantApp: App {
    @StateObject private var loginViewModel = LoginViewModel()
    @State private var isInitializing = true // 添加初始化状态
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isInitializing {
                    // 显示一个启动画面
                    LoadingView(message: "正在加载...")
                        .onAppear {
                            Task {
                                // 应用启动时先验证登录状态
                                if loginViewModel.isLoggedIn {
                                    // 设置正确的主机索引
                                    let lastHostIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastHostIndex)
                                    NetworkService.shared.setHost(index: lastHostIndex)
                                    print("应用启动验证：使用主机索引 \(lastHostIndex)")
                                    
                                    let isValid = await AuthService.shared.validateSessionState()
                                    await MainActor.run {
                                        if !isValid {
                                            print("应用启动验证：登录状态已失效")
                                            loginViewModel.isLoggedIn = false
                                            UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKey.isLoggedIn)
                                            UserDefaults.standard.synchronize()
                                        } else {
                                            print("应用启动验证：登录状态有效")
                                            // 刷新用户信息
                                            Task {
                                                await loginViewModel.refreshStudentInfo()
                                            }
                                        }
                                        // 验证完成后设置初始化完成
                                        isInitializing = false
                                    }
                                } else {
                                    // 没有登录状态，直接完成初始化
                                    isInitializing = false
                                }
                            }
                        }
                } else {
                    // 初始化完成后显示相应界面
                    if loginViewModel.isLoggedIn {
                        MainTabView()
                            .environmentObject(loginViewModel)
                    } else {
                        LoginView()
                            .environmentObject(loginViewModel)
                    }
                }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject private var classroomViewModel = ClassroomViewModel()
    @State private var isValidatingSession: Bool = false
    
    var body: some View {
        TabView {
            ClassroomQueryView()
                .environmentObject(classroomViewModel)
                .tabItem {
                    Label("空教室", systemImage: "building.2")
                }
            
            AccountView()
                .environmentObject(loginViewModel)
                .tabItem {
                    Label("账户", systemImage: "person.circle")
                }
        }
        .onAppear {
            // 避免重复验证
            if !isValidatingSession {
                isValidatingSession = true
                
                // 延迟验证以确保登录状态已完全同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task {
                        // 设置正确的主机索引
                        let lastHostIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastHostIndex)
                        NetworkService.shared.setHost(index: lastHostIndex)
                        print("主界面验证：使用主机索引 \(lastHostIndex)")
                        
                        let isValid = await AuthService.shared.validateSessionState()
                        if !isValid {
                            print("主界面验证：登录状态已失效")
                            await MainActor.run {
                                loginViewModel.isLoggedIn = false
                                UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKey.isLoggedIn)
                                UserDefaults.standard.synchronize()
                            }
                        } else {
                            print("主界面验证：登录状态有效")
                        }
                        isValidatingSession = false
                    }
                }
            }
        }
    }
}

struct AccountView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("账号信息")) {
                    HStack {
                        Text("学号")
                        Spacer()
                        Text(loginViewModel.studentId)
                            .foregroundColor(.secondary)
                    }
                    
                    if !loginViewModel.studentName.isEmpty {
                        HStack {
                            Text("姓名")
                            Spacer()
                            Text(loginViewModel.studentName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: loginViewModel.logout) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("账户")
        }
    }
}
