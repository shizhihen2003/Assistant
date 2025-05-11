//
//  ClassroomService.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation

class ClassroomService {
    // 单例模式
    static let shared = ClassroomService()
    private init() {}
    
    // 验证会话是否有效
    func validateSession() async -> Bool {
        do {
            print("验证会话是否有效")
            
            // 设置正确的主机索引
            let lastHostIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastHostIndex)
            print("验证会话：使用上次登录的主机索引：\(lastHostIndex)")
            NetworkService.shared.setHost(index: lastHostIndex)
            
            // 尝试访问需要登录的页面来验证会话
            let studentInfoPath = Constants.API.studentInfoPath
            print("验证会话状态: 请求学生信息页面: \(studentInfoPath)")
            
            let studentInfoHtml = try await NetworkService.shared.getHtml(path: studentInfoPath)
            
            // 检查HTML内容是否包含登录表单
            let hasLoginForm = studentInfoHtml.contains("id=\"loginForm\"") ||
                               studentInfoHtml.contains("name=\"loginForm\"") ||
                               studentInfoHtml.contains("用户登录")
            
            if hasLoginForm {
                print("页面包含登录表单，会话无效")
                return false
            }
            
            // 检查是否包含学生信息标记
            let hasStudentInfo = studentInfoHtml.contains("xh") ||
                                 studentInfoHtml.contains("xm") ||
                                 studentInfoHtml.contains("学号")
            
            if hasStudentInfo {
                print("页面包含学生信息标记，会话有效")
                return true
            }
            
            print("无法确定会话状态，假定无效")
            return false
        } catch {
            print("验证会话失败: \(error)")
            return false
        }
    }
    
    // 获取学年学期列表 - 从HTML获取
    func getTermOptions() async -> [Term] {
        do {
            print("从服务器获取学年学期数据")
            
            // 先验证会话状态
            let isSessionValid = await validateSession()
            if !isSessionValid {
                print("会话无效，返回默认学年学期列表")
                return Constants.OptionData.defaultTerms()
            }
            
            // 获取HTML页面
            let html = try await NetworkService.shared.getHtml(path: "cdjy/cdjy_cxKxcdlb.html?gnmkdm=N2155")
            
            // 从HTML中提取学年学期选项 - 使用正则表达式
            let pattern = "<option[^>]*value=['\"]([0-9]+-(?:3|12))['\"][^>]*>([^<]+)</option>"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            var terms: [Term] = []
            
            for match in matches {
                if let valueRange = Range(match.range(at: 1), in: html),
                   let labelRange = Range(match.range(at: 2), in: html) {
                    let value = String(html[valueRange])
                    let label = String(html[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 分割value获取xnm和xqm
                    let parts = value.components(separatedBy: "-")
                    if parts.count == 2 {
                        let term = Term(
                            id: value,
                            name: label,
                            xnm: parts[0],
                            xqm: parts[1]
                        )
                        terms.append(term)
                    }
                }
            }
            
            print("从HTML获取到 \(terms.count) 个学年学期选项")
            
            // 如果没有找到选项，返回默认值
            if terms.isEmpty {
                print("未从HTML找到学年学期选项，使用默认值")
                return Constants.OptionData.defaultTerms()
            }
            
            // 按时间降序排序
            terms.sort { term1, term2 in
                let year1 = Int(term1.xnm) ?? 0
                let term1Val = Int(term1.xqm) ?? 0
                let year2 = Int(term2.xnm) ?? 0
                let term2Val = Int(term2.xqm) ?? 0
                
                if year1 != year2 {
                    return year1 > year2
                }
                return term1Val > term2Val
            }
            
            return terms
        } catch {
            print("获取学年学期数据失败: \(error)")
            // 出错时返回默认值
            return Constants.OptionData.defaultTerms()
        }
    }
    
    // 获取校区列表 - 从HTML获取
    func getCampusOptions() async -> [Campus] {
        do {
            print("从服务器获取校区数据")
            
            // 先验证会话状态
            let isSessionValid = await validateSession()
            if !isSessionValid {
                print("会话无效，返回默认校区列表")
                return Constants.OptionData.campuses
            }
            
            // 获取HTML页面
            let html = try await NetworkService.shared.getHtml(path: "cdjy/cdjy_cxKxcdlb.html?gnmkdm=N2155")
            
            // 从HTML中提取校区选项
            let pattern = "<option[^>]*value=['\"]([^'\"]+)['\"][^>]*>([^<]+)</option>"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            
            // 查找校区下拉框
            let selectPattern = "<select[^>]*id=['\"]xqh_id['\"][^>]*>(.*?)</select>"
            let selectRegex = try NSRegularExpression(pattern: selectPattern, options: [.dotMatchesLineSeparators])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            if let selectMatch = selectRegex.firstMatch(in: html, options: [], range: range),
               let selectRange = Range(selectMatch.range(at: 1), in: html) {
                let selectContent = String(html[selectRange])
                
                // 在下拉框内容中查找选项
                let optionsRange = NSRange(selectContent.startIndex..<selectContent.endIndex, in: selectContent)
                let matches = regex.matches(in: selectContent, options: [], range: optionsRange)
                
                var campuses: [Campus] = []
                
                for match in matches {
                    if let valueRange = Range(match.range(at: 1), in: selectContent),
                       let labelRange = Range(match.range(at: 2), in: selectContent) {
                        let value = String(selectContent[valueRange])
                        let label = String(selectContent[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 过滤掉空选项或"请选择"
                        if !value.isEmpty && !label.contains("请选择") {
                            let campus = Campus(id: value, name: label)
                            campuses.append(campus)
                        }
                    }
                }
                
                print("从HTML获取到 \(campuses.count) 个校区选项")
                
                // 如果没有找到选项，返回默认值
                if campuses.isEmpty {
                    print("未从HTML找到校区选项，使用默认值")
                    return Constants.OptionData.campuses
                }
                
                return campuses
            }
            
            // 如果未找到下拉框，返回默认值
            print("未从HTML找到校区下拉框，使用默认值")
            return Constants.OptionData.campuses
        } catch {
            print("获取校区数据失败: \(error)")
            // 出错时返回默认值
            return Constants.OptionData.campuses
        }
    }
    
    // 查询空教室
    func queryEmptyClassrooms(params: ClassroomQueryParams) async throws -> ClassroomQueryResponse {
        // 首先验证会话是否有效
        let isSessionValid = await validateSession()
        if !isSessionValid {
            print("会话无效，需要重新登录")
            return ClassroomQueryResponse(
                success: false,
                totalCount: nil,
                items: nil,
                pageNum: nil,
                pageSize: nil,
                error: "登录状态已失效，请重新登录",
                needLogin: true
            )
        }
        
        // 获取API路径
        let path = Constants.API.emptyClassroomPath
        
        // 将查询参数转换为字典
        let queryParams = params.toDictionary()
        
        // 设置请求头
        let headers = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "X-Requested-With": "XMLHttpRequest"
        ]
        
        do {
            // 发送POST请求查询空教室
            let response = try await NetworkService.shared.post(
                path: path,
                params: queryParams,
                headers: headers,
                responseType: ClassroomQueryResponse.self
            )
            
            // 检查是否获取到教室数据
            if let items = response.items, !items.isEmpty {
                print("查询成功，返回 \(items.count) 个空教室结果")
                return response
            } else {
                // 空结果
                print("查询成功，但没有找到空教室")
                return ClassroomQueryResponse(
                    success: true,
                    totalCount: 0,
                    items: [],
                    pageNum: 1,
                    pageSize: 100,
                    error: nil,
                    needLogin: false
                )
            }
        } catch let networkError as NetworkError {
            // 处理网络错误
            if case .unauthorized = networkError {
                print("认证失败，需要重新登录")
                return ClassroomQueryResponse(
                    success: false,
                    totalCount: nil,
                    items: nil,
                    pageNum: nil,
                    pageSize: nil,
                    error: "登录状态已失效，请重新登录",
                    needLogin: true
                )
            } else if case .decodingError = networkError {
                // 尝试手动解析响应
                print("解码错误，尝试手动解析响应")
                return ClassroomQueryResponse(
                    success: false,
                    totalCount: nil,
                    items: nil,
                    pageNum: nil,
                    pageSize: nil,
                    error: "响应格式解析错误，请稍后再试",
                    needLogin: false
                )
            }
            
            print("网络错误: \(networkError.errorMessage)")
            return ClassroomQueryResponse(
                success: false,
                totalCount: nil,
                items: nil,
                pageNum: nil,
                pageSize: nil,
                error: networkError.errorMessage,
                needLogin: false
            )
        } catch {
            // 处理其他错误
            print("其他错误: \(error)")
            return ClassroomQueryResponse(
                success: false,
                totalCount: nil,
                items: nil,
                pageNum: nil,
                pageSize: nil,
                error: error.localizedDescription,
                needLogin: false
            )
        }
    }
    
    // 获取教学楼列表 - 修改为从API获取
    func getBuildingOptions(campusId: String) async -> [Building] {
        do {
            print("从服务器获取校区\(campusId)的教学楼数据")
            
            // 先验证会话状态
            let isSessionValid = await validateSession()
            if !isSessionValid {
                print("会话无效，返回默认教学楼列表")
                return getDefaultBuildings(forCampus: campusId)
            }
            
            // 构造请求URL和参数
            let path = "cdjy/cdjy_cxXqjc.html?gnmkdm=N2155"
            let params: [String: Any] = ["xqh_id": campusId]
            
            // 设置请求头
            let headers = [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "X-Requested-With": "XMLHttpRequest"
            ]
            
            // 定义API响应模型
            struct BuildingResponse: Codable {
                let lhList: [BuildingItem]?
                
                struct BuildingItem: Codable {
                    let JXLDM: String
                    let JXLMC: String
                }
            }
            
            // 发送POST请求获取教学楼列表
            let response = try await NetworkService.shared.post(
                path: path,
                params: params,
                headers: headers,
                responseType: BuildingResponse.self
            )
            
            if let buildingItems = response.lhList, !buildingItems.isEmpty {
                // 转换为Building模型
                var buildings = buildingItems.map { item in
                    Building(id: item.JXLDM, name: item.JXLMC)
                }
                
                // 添加"全部"选项
                buildings.insert(Building(id: "", name: "全部"), at: 0)
                
                print("成功从API获取 \(buildings.count-1) 个教学楼")
                return buildings
            } else {
                print("API未返回教学楼数据，尝试从HTML获取")
                
                // 备选方案：尝试从HTML页面提取
                return try await getBuildingsFromHtml(campusId: campusId)
            }
        } catch {
            print("获取教学楼数据失败: \(error)")
            
            // 尝试从HTML获取
            do {
                return try await getBuildingsFromHtml(campusId: campusId)
            } catch {
                print("从HTML获取教学楼数据也失败: \(error)")
                // 最后返回默认值
                return getDefaultBuildings(forCampus: campusId)
            }
        }
    }
    
    // 从HTML获取教学楼数据的辅助方法
    private func getBuildingsFromHtml(campusId: String) async throws -> [Building] {
        // 获取HTML页面
        let html = try await NetworkService.shared.getHtml(path: "cdjy/cdjy_cxKxcdlb.html?gnmkdm=N2155")
        
        // 从HTML中提取教学楼选项
        let pattern = "<option[^>]*value=['\"]([^'\"]+)['\"][^>]*>([^<]+)</option>"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        
        // 查找教学楼下拉框
        let selectPattern = "<select[^>]*id=['\"]lh['\"][^>]*>(.*?)</select>"
        let selectRegex = try NSRegularExpression(pattern: selectPattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let selectMatch = selectRegex.firstMatch(in: html, options: [], range: range),
           let selectRange = Range(selectMatch.range(at: 1), in: html) {
            let selectContent = String(html[selectRange])
            
            // 在下拉框内容中查找选项
            let optionsRange = NSRange(selectContent.startIndex..<selectContent.endIndex, in: selectContent)
            let matches = regex.matches(in: selectContent, options: [], range: optionsRange)
            
            var buildings: [Building] = []
            
            // 添加"全部"选项
            buildings.append(Building(id: "", name: "全部"))
            
            for match in matches {
                if let valueRange = Range(match.range(at: 1), in: selectContent),
                   let labelRange = Range(match.range(at: 2), in: selectContent) {
                    let value = String(selectContent[valueRange])
                    let label = String(selectContent[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 过滤掉空选项或"请选择"
                    if !value.isEmpty && !label.contains("请选择") {
                        let building = Building(id: value, name: label)
                        buildings.append(building)
                    }
                }
            }
            
            print("从HTML获取到 \(buildings.count-1) 个教学楼选项")
            
            if buildings.count > 1 {
                return buildings
            }
        }
        
        // 如果未找到下拉框或选项，返回默认值
        print("未从HTML找到教学楼下拉框或选项，使用默认值")
        return getDefaultBuildings(forCampus: campusId)
    }
    
    // 获取默认教学楼列表的辅助方法
    private func getDefaultBuildings(forCampus campusId: String) -> [Building] {
        switch campusId {
        case "00002":
            return Constants.OptionData.mainCampusBuildings
        case "00005":
            return Constants.OptionData.shungengCampusBuildings
        default:
            return Constants.OptionData.mainCampusBuildings
        }
    }
    
    // 获取场地类别列表
    func getRoomTypeOptions() async -> [RoomType] {
        do {
            print("从服务器获取场地类别数据")
            
            // 先验证会话状态
            let isSessionValid = await validateSession()
            if !isSessionValid {
                print("会话无效，返回默认场地类别列表")
                return Constants.OptionData.roomTypes
            }
            
            // 获取HTML页面
            let html = try await NetworkService.shared.getHtml(path: "cdjy/cdjy_cxKxcdlb.html?gnmkdm=N2155")
            
            // 从HTML中提取场地类别选项
            let pattern = "<option[^>]*value=['\"]([^'\"]+)['\"][^>]*>([^<]+)</option>"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            
            // 查找场地类别下拉框
            let selectPattern = "<select[^>]*id=['\"]cdlb_id['\"][^>]*>(.*?)</select>"
            let selectRegex = try NSRegularExpression(pattern: selectPattern, options: [.dotMatchesLineSeparators])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            if let selectMatch = selectRegex.firstMatch(in: html, options: [], range: range),
               let selectRange = Range(selectMatch.range(at: 1), in: html) {
                let selectContent = String(html[selectRange])
                
                // 在下拉框内容中查找选项
                let optionsRange = NSRange(selectContent.startIndex..<selectContent.endIndex, in: selectContent)
                let matches = regex.matches(in: selectContent, options: [], range: optionsRange)
                
                var roomTypes: [RoomType] = []
                
                for match in matches {
                    if let valueRange = Range(match.range(at: 1), in: selectContent),
                       let labelRange = Range(match.range(at: 2), in: selectContent) {
                        let value = String(selectContent[valueRange])
                        let label = String(selectContent[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 过滤掉空选项或"请选择"
                        if !label.contains("请选择") {
                            let roomType = RoomType(id: value, name: label)
                            roomTypes.append(roomType)
                        }
                    }
                }
                
                print("从HTML获取到 \(roomTypes.count) 个场地类别选项")
                
                // 如果没有找到选项，返回默认值
                if roomTypes.isEmpty {
                    print("未从HTML找到场地类别选项，使用默认值")
                    return Constants.OptionData.roomTypes
                }
                
                return roomTypes
            }
            
            // 如果未找到下拉框，返回默认值
            print("未从HTML找到场地类别下拉框，使用默认值")
            return Constants.OptionData.roomTypes
        } catch {
            print("获取场地类别数据失败: \(error)")
            // 出错时返回默认值
            return Constants.OptionData.roomTypes
        }
    }
    
    // 生成周次字符串 - 修改为与Electron版本兼容的格式
    func generateWeekString(weekId: Int) -> String {
        // 为兼容教务系统，生成二进制表示
        let zcd = 1 << (weekId - 1)  // 二进制表示，第几周就是2的(n-1)次方
        return "\(zcd)"  // 直接返回数值
    }
    
    // 计算最近的周次
    func calculateCurrentWeek() -> Int {
        // 尝试从缓存获取最后选择的周次
        if let lastWeek = UserDefaults.standard.object(forKey: Constants.UserDefaultsKey.lastSelectedWeek) as? Int {
            return lastWeek
        }
        
        // 根据当前日期计算周次
        // 这里简化处理，假设学期从9月第一周开始
        let calendar = Calendar.current
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentWeekOfYear = calendar.component(.weekOfYear, from: currentDate)
        
        if currentMonth >= 9 {
            // 秋季学期，从9月第一周开始计算
            let septemberFirstWeek = 36 // 假设9月第一周是第36周
            return min(currentWeekOfYear - septemberFirstWeek + 1, 20)
        } else if currentMonth >= 2 && currentMonth <= 6 {
            // 春季学期，从2月第一周开始计算
            let februaryFirstWeek = 6 // 假设2月第一周是第6周
            return min(currentWeekOfYear - februaryFirstWeek + 1, 20)
        }
        
        // 默认返回第1周
        return 1
    }
}
