//
//  AssistantApp.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import SwiftUI

@main
struct UJNAssistantApp: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        if authService.isLoggedIn {
            TabView {
                ClassroomQueryView()
                    .tabItem {
                        Label("空教室查询", systemImage: "building.2")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
            }
        } else {
            LoginView()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("学号")
                        Spacer()
                        Text(authService.userInfo.studentId)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("姓名")
                        Spacer()
                        Text(authService.userInfo.name)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("入学年份")
                        Spacer()
                        Text(String(authService.userInfo.entranceYear))
                            .foregroundColor(.gray)
                    }
                } header: {
                    Text("账号信息")
                }
                
                Section {
                    Button(action: {
                        authService.logout()
                    }) {
                        Text("退出登录")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
