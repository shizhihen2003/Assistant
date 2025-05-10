//
//  LoginView.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var showPassword: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    // 标题和Logo
                    VStack(spacing: 8) {
                        Image(systemName: "building.columns.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                            .padding(.bottom, 8)
                        
                        Text("济南大学教务助手")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("登录教务系统账号")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 表单区域
                    Form {
                        Section(header: Text("账号信息")) {
                            // 学号输入
                            TextField("学号", text: $viewModel.studentId)
                                .keyboardType(.numberPad)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            // 密码输入
                            HStack {
                                if showPassword {
                                    TextField("密码", text: $viewModel.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("密码", text: $viewModel.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 服务器选择
                            Picker("教务节点", selection: $viewModel.hostIndex) {
                                ForEach(0..<Constants.API.eaHosts.count, id: \.self) { index in
                                    Text("节点\(index + 1)")
                                        .tag(index)
                                }
                            }
                        }
                        
                        Section {
                            // 记住密码和自动登录
                            Toggle("记住密码", isOn: $viewModel.rememberPassword)
                            
                            Toggle("自动登录", isOn: $viewModel.autoLogin)
                                .disabled(!viewModel.rememberPassword)
                        }
                        
                        Section {
                            // 登录按钮
                            Button(action: {
                                Task {
                                    await viewModel.login()
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Text("登录")
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.studentId.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    
                    Spacer()
                    
                    // 底部版权信息
                    VStack(spacing: 5) {
                        Text("济南大学教务助手")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .alert("登录失败", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                // 解决布局约束冲突
                UITextView.appearance().setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                UITextView.appearance().setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(LoginViewModel())
}
