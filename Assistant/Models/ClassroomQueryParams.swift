//
//  ClassroomQueryParams.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation

// 空教室查询参数
struct ClassroomQueryParams: Codable {
    var xnm: String  // 学年，例如：2024
    var xqm: String  // 学期，例如：3(第一学期)或12(第二学期)
    var xqh_id: String  // 校区ID
    var jxlh: String?  // 教学楼ID
    var cdlb_id: String?  // 场地类别
    var qssd: String  // 起始时间（周几）
    var qsjc: String  // 起始节次
    var jsjc: String  // 结束节次
    var zcd: String  // 周次
    var queryModel: QueryModel
    
    struct QueryModel: Codable {
            var showCount: Int
            var currentPage: Int
            var sortName: String?
            var sortOrder: String?
            
            init(showCount: Int = 100, currentPage: Int = 1, sortName: String? = nil, sortOrder: String? = nil) {
                self.showCount = showCount
                self.currentPage = currentPage
                self.sortName = sortName
                self.sortOrder = sortOrder
            }
        }
        
        init(xnm: String, xqm: String, xqh_id: String, jxlh: String? = nil, cdlb_id: String? = nil, qssd: String, qsjc: String, jsjc: String, zcd: String) {
            self.xnm = xnm
            self.xqm = xqm
            self.xqh_id = xqh_id
            self.jxlh = jxlh
            self.cdlb_id = cdlb_id
            self.qssd = qssd
            self.qsjc = qsjc
            self.jsjc = jsjc
            self.zcd = zcd
            self.queryModel = QueryModel()
        }
        
        // 转换为请求参数字典
        func toDictionary() -> [String: Any] {
            var params: [String: Any] = [
                "xnm": xnm,
                "xqm": xqm,
                "xqh_id": xqh_id,
                "qssd": qssd,             // 星期几
                "qsjc": qsjc,             // 开始节次
                "jsjc": jsjc,             // 结束节次
                "zcd": zcd,               // 周次
                "fwzt": "cx",             // 服务状态：查询 (添加这个参数)
                "jyfs": "0",              // 借用方式：按周次借用 (添加这个参数)
                "queryModel.showCount": queryModel.showCount,
                "queryModel.currentPage": queryModel.currentPage
            ]
            
            if let jxlh = jxlh, !jxlh.isEmpty {
                params["jxlh"] = jxlh
            }
            
            if let cdlb_id = cdlb_id, !cdlb_id.isEmpty {
                params["cdlb_id"] = cdlb_id
            }
            
            if let sortName = queryModel.sortName {
                params["queryModel.sortName"] = sortName
            }
            
            if let sortOrder = queryModel.sortOrder {
                params["queryModel.sortOrder"] = sortOrder
            }
            
            return params
        }
    }

    // 空教室查询结果模型 - 修改为与服务器实际返回结构匹配
    struct ClassroomQueryResponse: Codable {
        let items: [EmptyClassroom]?
        let currentPage: Int?
        
        // 将totalResult定义为Any类型，以便处理不同的响应格式
        private var _totalResult: Any?
        
        // 客户端内部使用的字段
        var success: Bool = true
        var error: String?
        var needLogin: Bool?
        
        // 计算属性 - 转换为整数
        var totalCount: Int? {
            if let strValue = _totalResult as? String {
                return Int(strValue)
            } else if let intValue = _totalResult as? Int {
                return intValue
            }
            return nil
        }
        
        var pageNum: Int? {
            return currentPage
        }
        
        var pageSize: Int? {
            return 100
        }
        
        // 定义编码键
        enum CodingKeys: String, CodingKey {
            case items
            case currentPage
            case totalResult
        }
        
        // 自定义解码
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // 正常解码
            items = try container.decodeIfPresent([EmptyClassroom].self, forKey: .items)
            currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage)
            
            // 尝试解码totalResult字段 - 首先尝试解码为Int
            do {
                let intValue = try container.decode(Int.self, forKey: .totalResult)
                _totalResult = intValue
            } catch {
                // 如果Int解码失败，尝试解码为String
                do {
                    let stringValue = try container.decode(String.self, forKey: .totalResult)
                    _totalResult = stringValue
                } catch {
                    // 如果两次都失败，设为nil（容忍这个字段的缺失）
                    _totalResult = nil
                }
            }
            
            // 客户端内部使用的字段设置默认值
            success = true
            error = nil
            needLogin = false
        }
        
        // 编码方法
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(items, forKey: .items)
            try container.encodeIfPresent(currentPage, forKey: .currentPage)
            
            // 根据类型编码totalResult
            if let intValue = _totalResult as? Int {
                try container.encode(intValue, forKey: .totalResult)
            } else if let stringValue = _totalResult as? String {
                try container.encode(stringValue, forKey: .totalResult)
            }
        }
        
        // 手动创建响应对象的初始化方法
        init(success: Bool, totalCount: Int?, items: [EmptyClassroom]?, pageNum: Int?, pageSize: Int?, error: String?, needLogin: Bool?) {
            self.success = success
            self.items = items
            self.currentPage = pageNum
            
            // 设置totalResult
            if let count = totalCount {
                self._totalResult = count
            } else {
                self._totalResult = nil
            }
            
            self.error = error
            self.needLogin = needLogin
        }
    }

    // 空教室信息模型 - 座位数使用String类型
    struct EmptyClassroom: Codable, Identifiable {
        let id = UUID()
        let cdmc: String?  // 场地名称
        let jxlmc: String?  // 教学楼名称
        let zws: String?  // 座位数 - 使用String类型
        let cdlbmc: String?  // 场地类别名称
        let xqmc: String?  // 校区名称
        
        enum CodingKeys: String, CodingKey {
            case cdmc, jxlmc, zws, cdlbmc, xqmc
        }
        
        // 将座位数转换为Int的便利方法
        var zwsInt: Int {
            return Int(zws ?? "0") ?? 0
        }
    }

    // 校区下拉选项
    struct Campus: Identifiable, Hashable, Equatable {
        let id: String
        let name: String
    }

    // 教学楼下拉选项
struct Building: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let name: String
}

    // 场地类别下拉选项
    struct RoomType: Identifiable, Hashable, Equatable {
        let id: String
        let name: String
    }

    // 学年学期选项
    struct Term: Identifiable, Hashable, Equatable {
        let id: String
        let name: String
        let xnm: String  // 学年
        let xqm: String  // 学期
        
        // 为了遵循 Hashable 协议
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        // 为了遵循 Equatable 协议
        static func == (lhs: Term, rhs: Term) -> Bool {
            return lhs.id == rhs.id
        }
    }

    // 周次选项
    struct Week: Identifiable, Hashable, Equatable {
        let id: Int
        let name: String
    }

    // 节次选项
    struct Period: Identifiable, Hashable, Equatable {
        let id: String
        let name: String
    }

    // 星期选项
    struct Weekday: Identifiable, Hashable, Equatable {
        let id: String
        let name: String
    }
