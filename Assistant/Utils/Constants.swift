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
//            "jwglxt.jcut.edu.cn",
            "jwgl.ujn.edu.cn",
            "jwgl2.ujn.edu.cn",
            "jwgl3.ujn.edu.cn",
            "jwgl4.ujn.edu.cn",
            "jwgl5.ujn.edu.cn",
            "jwgl6.ujn.edu.cn",
            "jwgl7.ujn.edu.cn",
            "jwgl8.ujn.edu.cn",
            "jwgl9.ujn.edu.cn"
        ]
        
        static let scheme = "http"
        
        // 教务系统登录相关
        static let eaLoginPath = "jwglxt/xtgl/login_slogin.html"
//        static let eaLoginPath = "xtgl/login_slogin.html"
        static let eaLoginPublicKeyPath = "jwglxt/xtgl/login_getPublicKey.html"
//        static let eaLoginPublicKeyPath = "xtgl/login_getPublicKey.html"
        
        // 空教室查询
        static let emptyClassroomPath = "jwglxt/cdjy/cdjy_cxKxcdlb.html?doType=query&gnmkdm=N2155"
//        static let emptyClassroomPath = "cdjy/cdjy_cxKxcdlb.html?gnmkdm=N2155&layout=default"
        
        // 查询学生信息
        static let studentInfoPath = "jwglxt/xsxxxggl/xsxxwh_cxCkDgxsxx.html?gnmkdm=N100801"
//        static let studentInfoPath = "xsxxxggl/xsxxwh_cxCkDgxsxx.html?gnmkdm=N100801"
    }
    
    // 预设选项数据
    struct OptionData {
        // 校区选项
        static let campuses = [
            Campus(id: "1", name: "主校区"),
            Campus(id: "3", name: "明水校区"),
            Campus(id: "2", name: "舜耕校区")
        ]
        
        // 场地类别选项
        static let roomTypes = [
            RoomType(id: "", name: "全部"),
            RoomType(id: "008", name: "多媒体教室"),
            RoomType(id: "003", name: "普通教室"),
            RoomType(id: "011", name: "机房"),
            RoomType(id: "014", name: "实验室"),
            RoomType(id: "CED9C1E9C6AF41DEE0530AFDA8C0A999", name: "智慧教室")
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
        
        // 主校区默认教学楼
        static let mainCampusBuildings = [
            Building(id: "", name: "全部"),
            Building(id: "0004", name: "第一教学楼"),
            Building(id: "0002", name: "第四教学楼"),
            Building(id: "0003", name: "第三教学楼"),
            Building(id: "0007", name: "第二教学楼"),
            Building(id: "0016", name: "第五教学楼"),
            Building(id: "0006", name: "第十教学楼"),
            Building(id: "0011", name: "第八教学楼")
        ]
        
        // 舜耕校区默认教学楼
        static let shungengCampusBuildings = [
            Building(id: "", name: "全部"),
            Building(id: "0010", name: "第七教学楼"),
            Building(id: "0023", name: "第九教学楼")
        ]
        
        // 明水校区默认教学楼
        static let mingshuiCampusBuildings = [
            Building(id: "", name: "全部"),
            Building(id: "0008", name: "第十一教学楼")
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
