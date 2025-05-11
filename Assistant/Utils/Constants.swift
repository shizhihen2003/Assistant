//
//  Constants.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation

struct Constants {
    // API基础配置
    struct API {
        static let eaHosts = [
            "jwglxt.jcut.edu.cn"
        ]
        
        static let scheme = "https"
        
        // 教务系统登录相关
        static let eaLoginPath = "xtgl/login_slogin.html"
        static let eaLoginPublicKeyPath = "xtgl/login_getPublicKey.html"
        
        // 空教室查询
        static let emptyClassroomPath = "cdjy/cdjy_cxKxcdlb.html?doType=query&gnmkdm=N2155"
        
        // 查询学生信息
        static let studentInfoPath = "xsxxxggl/xsxxwh_cxCkDgxsxx.html?gnmkdm=N100801"
    }
    
    // 预设选项数据
    struct OptionData {
        // 校区选项
        static let campuses = [
            Campus(id: "00002", name: "荆楚理工学院(主校区)"),
            Campus(id: "00005", name: "实习医院")
        ]
        
        // 场地类别选项
        static let roomTypes = [
            RoomType(id: "", name: "全部"),
            RoomType(id: "00048", name: "排练室"),
            RoomType(id: "2091D11FAF619542E063B100A8C0A9FD", name: "书法教室"),
            RoomType(id: "00041", name: "语音室1"),
            RoomType(id: "00022", name: "练功房"),
            RoomType(id: "00038", name: "计算机教室"),
            RoomType(id: "00040", name: "田径场"),
            RoomType(id: "00042", name: "练功房1"),
            RoomType(id: "00018", name: "计算机房"),
            RoomType(id: "00045", name: "画室"),
            RoomType(id: "00039", name: "多媒体教室1"),
            RoomType(id: "00046", name: "其它"),
            RoomType(id: "00024", name: "实验室"),
            RoomType(id: "00025", name: "画室1"),
            RoomType(id: "00019", name: "多媒体教室"),
            RoomType(id: "00017", name: "琴房"),
            RoomType(id: "00044", name: "实验室1"),
            RoomType(id: "00047", name: "艺-阶梯教室"),
            RoomType(id: "00016", name: "普通教室"),
            RoomType(id: "00021", name: "语音室"),
            RoomType(id: "AEB160EE2A2235ECE0533C00A8C088D9", name: "工训教室"),
            RoomType(id: "AEB160EE2A2535ECE0533C00A8C088D9", name: "艺术设计教室"),
            RoomType(id: "00036", name: "普通固定教室")
        ]
        
        // 学年学期默认选项
        static func defaultTerms() -> [Term] {
            // 获取当前年份
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            var terms: [Term] = []
            
            // 往前3年，往后1年的学年选项
            for year in (currentYear-3)...(currentYear+1) {
                // 第一学期 (3表示第一学期)
                terms.append(Term(
                    id: "\(year)-3",
                    name: "\(year)-\(year+1)-1",
                    xnm: "\(year)",
                    xqm: "3"
                ))
                
                // 第二学期 (12表示第二学期)
                terms.append(Term(
                    id: "\(year)-12",
                    name: "\(year)-\(year+1)-2",
                    xnm: "\(year)",
                    xqm: "12"
                ))
            }
            
            // 按时间降序排序
            return terms.sorted { term1, term2 in
                let year1 = Int(term1.xnm) ?? 0
                let term1Val = Int(term1.xqm) ?? 0
                let year2 = Int(term2.xnm) ?? 0
                let term2Val = Int(term2.xqm) ?? 0
                
                if year1 != year2 {
                    return year1 > year2
                }
                return term1Val > term2Val
            }
        }
        
        // 周次选项
        static let weeks: [Week] = (1...20).map { week in
            Week(id: week, name: "第\(week)周")
        }
        
        // 星期选项
        static let weekdays = [
            Weekday(id: "1", name: "星期一"),
            Weekday(id: "2", name: "星期二"),
            Weekday(id: "3", name: "星期三"),
            Weekday(id: "4", name: "星期四"),
            Weekday(id: "5", name: "星期五"),
            Weekday(id: "6", name: "星期六"),
            Weekday(id: "7", name: "星期日")
        ]
        
        // 节次选项 - 修改为10节
        static let periods = [
            Period(id: "1", name: "第1节"),
            Period(id: "2", name: "第2节"),
            Period(id: "3", name: "第3节"),
            Period(id: "4", name: "第4节"),
            Period(id: "5", name: "第5节"),
            Period(id: "6", name: "第6节"),
            Period(id: "7", name: "第7节"),
            Period(id: "8", name: "第8节"),
            Period(id: "9", name: "第9节"),
            Period(id: "10", name: "第10节")
        ]
        
        // 主校区默认教学楼（荆楚理工学院校区）
        static let mainCampusBuildings = [
            Building(id: "", name: "全部"),
            Building(id: "00040", name: "02-00实验楼"),
            Building(id: "00010", name: "02-01教学楼B栋"),
            Building(id: "00011", name: "02-02教学楼A栋"),
            Building(id: "00051", name: "02-03教学楼C栋"),
            Building(id: "00013", name: "02-04教学楼D栋"),
            Building(id: "00030", name: "02-07田径场"),
            Building(id: "00042", name: "02-08工训楼G栋"),
            Building(id: "00043", name: "02-09四合院"),
            Building(id: "00045", name: "02-10工业训练中心"),
            Building(id: "00046", name: "02-11理工实验楼A栋"),
            Building(id: "00047", name: "02-12理工实验楼B栋"),
            Building(id: "00052", name: "02-13旧图书馆"),
            Building(id: "00053", name: "02-14解剖实验楼"),
            Building(id: "00054", name: "02-15医训楼"),
            Building(id: "00048", name: "2-13新图书馆"),
            Building(id: "00055", name: "博物馆办公楼"),
            Building(id: "00041", name: "金工实习工厂"),
            Building(id: "00049", name: "图书馆钟楼"),
            Building(id: "00014", name: "行政楼B栋"),
            Building(id: "00044", name: "艺术中心"),
            Building(id: "wlh", name: "无楼号")
        ]
        
        // 其他校区默认教学楼 (实习医院校区)
        static let shungengCampusBuildings = [
            Building(id: "", name: "全部")
            // 实习医院可能没有默认教学楼，但保留结构
        ]
        
        // 保留原始结构，虽然现在只有两个校区
        static let mingshuiCampusBuildings = [
            Building(id: "", name: "全部")
        ]
    }
    
    // KeyChain 存储键
    struct KeychainKey {
        static let userCredentials = "com.ujn.assistant.credentials"
    }
    
    // UserDefaults 键
    struct UserDefaultsKey {
        static let isLoggedIn = "com.ujn.assistant.isLoggedIn"
        static let lastHostIndex = "com.ujn.assistant.lastHostIndex"
        static let lastTermId = "com.ujn.assistant.lastTermId"
        static let lastCampusId = "com.ujn.assistant.lastCampusId"
        static let lastSelectedWeek = "com.ujn.assistant.lastSelectedWeek"
    }
}
