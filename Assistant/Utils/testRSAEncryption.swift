//
//  testRSAEncryption.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/10.
//

import Foundation

// 测试函数
func testRSAEncryption() {
    // 测试数据 - 使用实际从教务系统获取的值
    let testPassword = "380320911abcABC!"
    let testModulus = "ALWMyEyloIZsayIhjjK49M2BDLzPG7vch7NdSHauTaOXd/yWecHzVMgI+vY9kUjatGw8IVv69RZIZVGb9toka7DEfH+os8/afqc6EsjxDEaNSS+Eq7jzBjQj3RqOyKV5VEWGYHQ93WFQktlkbDsua78P/vb0hS7NM15yTyl/d09X"
    let testExponent = "AQAB"
    
    print("====== RSA加密测试 ======")
    print("密码: \(testPassword)")
    print("模数: \(testModulus.prefix(20))...")
    print("指数: \(testExponent)")
    
    // 执行加密
    let encryptedResult = RSAEncryptor.encryptPassword(testPassword, modulus: testModulus, exponent: testExponent)
    
    print("\n加密结果: \(encryptedResult ?? "加密失败")")
    print("========================")
}

// 在适当的地方调用此函数，例如在登录视图的viewDidAppear中
// testRSAEncryption()
