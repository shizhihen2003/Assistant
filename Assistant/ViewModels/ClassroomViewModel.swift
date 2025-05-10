//
//  ClassroomViewModel.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import Foundation
import SwiftUI

class ClassroomViewModel: ObservableObject {
    // 查询参数
    @Published var selectedTerm: Term = Constants.OptionData.defaultTerms()[0]
    @Published var selectedCampus: Campus = Constants.OptionData.campuses[0]
    @Published var selectedBuilding: Building = Constants.OptionData.mainCampusBuildings[0]
    @Published var selectedRoomType: RoomType = Constants.OptionData.roomTypes[0]
    @Published var selectedWeek: Week = Constants.OptionData.weeks[0]
    @Published var selectedWeekday: Weekday = Constants.OptionData.weekdays[0]
    @Published var selectedStartPeriod: Period = Constants.OptionData.periods[0]
    @Published var selectedEndPeriod: Period = Constants.OptionData.periods[1]
    
    // 下拉选项数据
    @Published var terms: [Term] = Constants.OptionData.defaultTerms()
    @Published var buildings: [Building] = Constants.OptionData.mainCampusBuildings
    @Published var campusList: [Campus] = Constants.OptionData.campuses
    @Published var roomTypes: [RoomType] = Constants.OptionData.roomTypes
    
    // 查询结果
    @Published var classrooms: [EmptyClassroom] = []
    @Published var filteredClassrooms: [EmptyClassroom] = []
    @Published var searchText: String = ""
    
    // 状态
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var needLogin: Bool = false
    
    // 分页
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var totalCount: Int = 0
    
    // 服务依赖
    private let classroomService = ClassroomService.shared
    
    // 本地缓存的UserDefaults键名前缀
    private let buildingsCacheKeyPrefix = "cached_buildings_campus_"
    
    // 初始化
    init() {
        print("ClassroomViewModel初始化...")
        
        // 加载上次使用的主机索引
        let lastHostIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastHostIndex)
        NetworkService.shared.setHost(index: lastHostIndex)
        print("设置教务系统主机索引为: \(lastHostIndex)")
        
        // 设置默认学期
        if !terms.isEmpty {
            selectedTerm = terms[0]
        } else {
            // 如果terms为空，确保selectedTerm有默认值
            selectedTerm = Constants.OptionData.defaultTerms()[0]
        }
        
        // 设置默认周次为当前周
        let currentWeek = classroomService.calculateCurrentWeek()
        if currentWeek > 0 && currentWeek <= Constants.OptionData.weeks.count {
            selectedWeek = Constants.OptionData.weeks[currentWeek - 1]
        }
        
        // 设置默认结束节次为第2节
        if Constants.OptionData.periods.count >= 2 {
            selectedEndPeriod = Constants.OptionData.periods[1]
        }
        
        // 先加载保存的Cookie
        NetworkService.shared.loadCookiesFromStorage()
        
        // 加载上次选择的校区
        loadLastSelectedOptions()
        
        // 延迟验证登录状态和加载服务器数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task {
                // 确保验证时使用正确的主机
                let isSessionValid = await self.classroomService.validateSession()
                await MainActor.run {
                    if !isSessionValid {
                        self.needLogin = true
                        self.errorMessage = "登录状态已失效，请重新登录"
                        self.showError = true
                    } else {
                        print("登录状态有效，准备加载教室数据")
                        // 加载服务器数据
                        Task {
                            await self.loadServerData()
                        }
                    }
                }
            }
        }
    }
    
    // 加载上次选择的参数
    private func loadLastSelectedOptions() {
        // 加载上次选择的学期
        if let lastTermId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.lastTermId),
           let term = terms.first(where: { $0.id == lastTermId }) {
            selectedTerm = term
        }
        
        // 加载上次选择的校区
        if let lastCampusId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.lastCampusId),
           let campusIndex = Constants.OptionData.campuses.firstIndex(where: { $0.id == lastCampusId }) {
            selectedCampus = Constants.OptionData.campuses[campusIndex]
            // 加载对应校区的教学楼
            Task {
                await loadBuildingsForCampus(campusId: lastCampusId)
            }
        }
        
        // 加载上次选择的周次
        if let lastWeek = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastSelectedWeek) as Int?,
           lastWeek > 0 && lastWeek <= Constants.OptionData.weeks.count {
            selectedWeek = Constants.OptionData.weeks[lastWeek - 1]
        }
    }
    
    // 加载服务器数据
    private func loadServerData() async {
        // 加载学年学期和校区数据
        await loadTermsAndCampuses()
        
        // 加载场地类别数据
        await loadRoomTypes()
        
        // 加载当前校区的教学楼
        if !self.selectedCampus.id.isEmpty {
            await loadBuildingsForCampus(campusId: self.selectedCampus.id)
        }
    }
    
    // 加载学年学期和校区数据的方法
    private func loadTermsAndCampuses() async {
        do {
            // 获取学年学期数据
            let serverTerms = await classroomService.getTermOptions()
            if !serverTerms.isEmpty {
                await MainActor.run {
                    self.terms = serverTerms
                    
                    // 如果有上次选择的学期，尝试恢复
                    if let lastTermId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.lastTermId),
                       let term = self.terms.first(where: { $0.id == lastTermId }) {
                        self.selectedTerm = term
                    } else if !self.terms.isEmpty {
                        // 否则选择第一个
                        self.selectedTerm = self.terms[0]
                    }
                }
            }
            
            // 获取校区数据
            let serverCampuses = await classroomService.getCampusOptions()
            if !serverCampuses.isEmpty {
                await MainActor.run {
                    // 更新校区列表
                    self.campusList = serverCampuses
                    
                    // 如果有上次选择的校区，尝试恢复
                    if let lastCampusId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.lastCampusId),
                       let campus = self.campusList.first(where: { $0.id == lastCampusId }) {
                        self.selectedCampus = campus
                    } else if !self.campusList.isEmpty {
                        // 否则选择第一个
                        self.selectedCampus = self.campusList[0]
                    }
                }
            }
        } catch {
            print("加载服务器数据失败: \(error)")
        }
    }
    
    // 加载场地类别数据
    private func loadRoomTypes() async {
        do {
            let serverRoomTypes = await classroomService.getRoomTypeOptions()
            if !serverRoomTypes.isEmpty {
                await MainActor.run {
                    self.roomTypes = serverRoomTypes
                    
                    // 默认选择多媒体教室或第一个选项
                    if let multimediaType = self.roomTypes.first(where: { $0.id == "008" }) {
                        self.selectedRoomType = multimediaType
                    } else if !self.roomTypes.isEmpty {
                        self.selectedRoomType = self.roomTypes[0]
                    }
                }
            }
        } catch {
            print("加载场地类别数据失败: \(error)")
        }
    }
    
    // 从缓存加载教学楼数据
    private func loadBuildingsFromCache(campusId: String) -> [Building]? {
        let cacheKey = buildingsCacheKeyPrefix + campusId
        
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            print("未找到校区\(campusId)的缓存教学楼数据")
            return nil
        }
        
        do {
            let buildings = try JSONDecoder().decode([Building].self, from: data)
            print("从缓存加载到校区\(campusId)的\(buildings.count)个教学楼")
            return buildings
        } catch {
            print("读取校区\(campusId)的缓存教学楼数据失败: \(error)")
            return nil
        }
    }
    
    // 将教学楼数据保存到缓存
    private func saveBuildingsToCache(buildings: [Building], campusId: String) {
        let cacheKey = buildingsCacheKeyPrefix + campusId
        
        do {
            let data = try JSONEncoder().encode(buildings)
            UserDefaults.standard.set(data, forKey: cacheKey)
            print("已将校区\(campusId)的\(buildings.count)个教学楼保存到缓存")
        } catch {
            print("保存校区\(campusId)的教学楼数据到缓存失败: \(error)")
        }
    }
    
    // 比较两个教学楼数组是否相同
    private func areBuildingsArraysEqual(_ array1: [Building], _ array2: [Building]) -> Bool {
        guard array1.count == array2.count else { return false }
        
        for i in 0..<array1.count {
            if array1[i].id != array2[i].id || array1[i].name != array2[i].name {
                return false
            }
        }
        
        return true
    }
    
    // 根据校区加载教学楼
    func loadBuildingsForCampus(campusId: String) async {
        // 首先尝试从缓存加载
        if let cachedBuildings = loadBuildingsFromCache(campusId: campusId) {
            // 使用缓存数据更新UI
            await MainActor.run {
                self.buildings = cachedBuildings
                // 确保选中的教学楼仍然存在于新的列表中
                if !self.buildings.contains(where: { $0.id == self.selectedBuilding.id }) {
                    self.selectedBuilding = self.buildings[0]
                }
            }
            print("已从缓存加载校区\(campusId)的教学楼数据")
        } else {
            // 如果没有缓存，使用默认数据并显示加载中状态
            let defaultBuildings = getDefaultBuildings(forCampus: campusId)
            await MainActor.run {
                self.buildings = defaultBuildings
                self.selectedBuilding = self.buildings[0]
            }
            print("未找到缓存，使用默认教学楼数据")
        }
        
        // 无论是否有缓存，都异步请求最新数据
        do {
            // 从API获取教学楼数据
            let apiBuildings = try await classroomService.getBuildingOptions(campusId: campusId)
            
            // 检查新获取的数据与当前显示的数据是否相同
            await MainActor.run {
                if !areBuildingsArraysEqual(apiBuildings, self.buildings) {
                    print("从服务器获取的教学楼数据与当前显示不同，更新UI")
                    self.buildings = apiBuildings
                    // 确保选中的教学楼仍然存在于新的列表中
                    if !self.buildings.contains(where: { $0.id == self.selectedBuilding.id }) {
                        self.selectedBuilding = self.buildings[0]
                    }
                } else {
                    print("从服务器获取的教学楼数据与当前显示相同，不更新UI")
                }
            }
            
            // 无论是否更新UI，都保存最新数据到缓存
            saveBuildingsToCache(buildings: apiBuildings, campusId: campusId)
            
        } catch {
            print("从服务器加载教学楼失败: \(error)")
            // 如果服务器请求失败，但已经有缓存数据，则保持使用缓存数据
            // 如果既没有缓存也请求失败，则已经使用了默认值
        }
    }
    
    // 获取默认教学楼列表
    private func getDefaultBuildings(forCampus campusId: String) -> [Building] {
        switch campusId {
        case "1":
            return Constants.OptionData.mainCampusBuildings
        case "2":
            return Constants.OptionData.shungengCampusBuildings
        case "3":
            return Constants.OptionData.mingshuiCampusBuildings
        default:
            return Constants.OptionData.mainCampusBuildings
        }
    }
    
    // 校区改变时的处理
    func onCampusChanged() {
        // 保存选择的校区
        UserDefaults.standard.set(selectedCampus.id, forKey: Constants.UserDefaultsKey.lastCampusId)
        
        // 加载该校区的教学楼 - 使用Task包装异步调用
        Task {
            await loadBuildingsForCampus(campusId: selectedCampus.id)
        }
    }
    
    // 学期改变时的处理
    func onTermChanged() {
        // 保存选择的学期
        UserDefaults.standard.set(selectedTerm.id, forKey: Constants.UserDefaultsKey.lastTermId)
    }
    
    // 周次改变时的处理
    func onWeekChanged() {
        // 保存选择的周次
        UserDefaults.standard.set(selectedWeek.id, forKey: Constants.UserDefaultsKey.lastSelectedWeek)
    }
    
    // 查询空教室
    func queryEmptyClassrooms() {
        // 验证参数
        if Int(selectedStartPeriod.id) ?? 0 > Int(selectedEndPeriod.id) ?? 0 {
            self.errorMessage = "开始节次不能大于结束节次"
            self.showError = true
            return
        }
        
        // 构建查询参数
        let params = ClassroomQueryParams(
            xnm: selectedTerm.xnm,
            xqm: selectedTerm.xqm,
            xqh_id: selectedCampus.id,
            jxlh: selectedBuilding.id.isEmpty ? nil : selectedBuilding.id,
            cdlb_id: selectedRoomType.id.isEmpty ? nil : selectedRoomType.id,
            qssd: selectedWeekday.id,
            qsjc: selectedStartPeriod.id,
            jsjc: selectedEndPeriod.id,
            zcd: classroomService.generateWeekString(weekId: selectedWeek.id)
        )
        
        // 设置加载状态
        self.isLoading = true
        self.errorMessage = ""
        self.showError = false
        self.needLogin = false
        
        // 执行查询
        Task {
            do {
                // 先验证会话状态
                let isSessionValid = await classroomService.validateSession()
                if !isSessionValid {
                    await MainActor.run {
                        self.isLoading = false
                        self.needLogin = true
                        self.errorMessage = "登录状态已失效，请重新登录"
                        self.showError = true
                    }
                    return
                }
                
                let response = try await classroomService.queryEmptyClassrooms(params: params)
                
                await MainActor.run {
                    self.isLoading = false
                    
                    if response.success {
                        // 查询成功，处理结果
                        self.classrooms = response.items ?? []
                        self.totalCount = response.totalCount ?? 0
                        self.currentPage = response.pageNum ?? 1
                        self.totalPages = (self.totalCount + 99) / 100 // 每页100条数据计算总页数
                        
                        // 如果结果为空，显示友好提示
                        if self.classrooms.isEmpty {
                            self.errorMessage = "未找到符合条件的空教室，请尝试调整查询条件"
                            self.showError = true
                        } else {
                            print("查询成功，找到 \(self.classrooms.count) 个空教室")
                            // 过滤结果
                            self.filterClassrooms()
                        }
                    } else {
                        // 查询失败，显示错误
                        self.errorMessage = response.error ?? "查询失败"
                        self.showError = true
                        
                        // 检查是否需要重新登录
                        if response.needLogin == true {
                            self.needLogin = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    print("查询错误: \(error)")
                }
            }
        }
    }
    
    // 根据搜索文本过滤教室
    func filterClassrooms() {
        if searchText.isEmpty {
            filteredClassrooms = classrooms
        } else {
            filteredClassrooms = classrooms.filter { classroom in
                let roomName = classroom.cdmc?.lowercased() ?? ""
                let buildingName = classroom.jxlmc?.lowercased() ?? ""
                let searchLower = searchText.lowercased()
                
                return roomName.contains(searchLower) || buildingName.contains(searchLower)
            }
        }
    }
    
    // 搜索文本改变的处理
    func onSearchTextChanged() {
        filterClassrooms()
    }
    
    // 根据排序选项对教室进行排序
    func sortClassrooms(by sortOption: String) -> [EmptyClassroom] {
        switch sortOption {
        case "name":
            return filteredClassrooms.sorted {
                ($0.cdmc ?? "") < ($1.cdmc ?? "")
            }
        case "building":
            return filteredClassrooms.sorted {
                ($0.jxlmc ?? "") < ($1.jxlmc ?? "")
            }
        case "seats":
            // 使用zwsInt计算属性进行排序
            return filteredClassrooms.sorted {
                let seats1 = Int($0.zws ?? "0") ?? 0
                let seats2 = Int($1.zws ?? "0") ?? 0
                return seats1 > seats2
            }
        default:
            return filteredClassrooms
        }
    }
}
