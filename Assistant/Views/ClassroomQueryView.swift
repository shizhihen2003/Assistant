//
//  ClassroomQueryView.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import SwiftUI

struct ClassroomQueryView: View {
    @EnvironmentObject var classroomViewModel: ClassroomViewModel
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var isShowingForm = true
    @State private var sortOption = SortOption.name
    @State private var isValidatingSession = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case name = "名称"
        case building = "教学楼"
        case seats = "座位数"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 主内容
                VStack(spacing: 0) {
                    // 查询表单
                    if isShowingForm {
                        QueryFormView(isShowingForm: $isShowingForm)
                            .environmentObject(classroomViewModel)
                            .transition(.move(edge: .top))
                    }
                    
                    // 结果列表
                    ClassroomResultListView(sortOption: $sortOption)
                        .environmentObject(classroomViewModel)
                }
                
                // 悬浮按钮
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                isShowingForm.toggle()
                            }
                        }) {
                            Image(systemName: isShowingForm ? "chevron.up" : "chevron.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // 加载中提示
                if classroomViewModel.isLoading {
                    LoadingView(message: "正在查询空教室...")
                }
                
                // 需要登录提示
                if classroomViewModel.needLogin {
                    NeedLoginView(message: "登录状态已失效，请重新登录") {
                        loginViewModel.logout()
                    }
                }
            }
            .navigationTitle("空教室查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("排序方式", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("排序", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(classroomViewModel.filteredClassrooms.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        classroomViewModel.queryEmptyClassrooms()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(classroomViewModel.isLoading)
                }
            }
            .onAppear {
                // 在页面显示时验证登录状态
                if !isValidatingSession {
                    isValidatingSession = true
                    Task {
                        let isValid = await AuthService.shared.validateSessionState()
                        if !isValid {
                            print("ClassroomQueryView: 登录状态已失效")
                            await MainActor.run {
                                loginViewModel.isLoggedIn = false
                                UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKey.isLoggedIn)
                                UserDefaults.standard.synchronize()
                            }
                        } else {
                            print("ClassroomQueryView: 登录状态有效")
                        }
                        isValidatingSession = false
                    }
                }
            }
        }
    }
}

struct QueryFormView: View {
    @EnvironmentObject var viewModel: ClassroomViewModel
    @Binding var isShowingForm: Bool
    @State private var formSubmitted = false
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: Text("学期与校区")) {
                    // 学年学期选择
                    Picker("学年学期", selection: $viewModel.selectedTerm) {
                        ForEach(viewModel.terms) { term in
                            Text(term.name).tag(term)
                        }
                    }
                    .onChange(of: viewModel.selectedTerm) { _ in
                        viewModel.onTermChanged()
                    }
                    
                    // 校区选择器
                    Picker("校区", selection: $viewModel.selectedCampus) {
                        ForEach(viewModel.campusList) { campus in
                            Text(campus.name).tag(campus)
                        }
                    }
                    .onChange(of: viewModel.selectedCampus) { _ in
                        viewModel.onCampusChanged()
                    }
                    
                    // 教学楼选择器
                    Picker("教学楼", selection: $viewModel.selectedBuilding) {
                        ForEach(viewModel.buildings) { building in
                            Text(building.name).tag(building)
                        }
                    }
                    
                    // 场地类别选择器
                    Picker("场地类别", selection: $viewModel.selectedRoomType) {
                        ForEach(viewModel.roomTypes) { roomType in
                            Text(roomType.name).tag(roomType)
                        }
                    }
                }
                
                Section(header: Text("时间与节次")) {
                    // 周次选择
                    Picker("周次", selection: $viewModel.selectedWeek) {
                        ForEach(Constants.OptionData.weeks) { week in
                            Text(week.name).tag(week)
                        }
                    }
                    .onChange(of: viewModel.selectedWeek) { _ in
                        viewModel.onWeekChanged()
                    }
                    
                    // 星期选择
                    Picker("星期", selection: $viewModel.selectedWeekday) {
                        ForEach(Constants.OptionData.weekdays) { weekday in
                            Text(weekday.name).tag(weekday)
                        }
                    }
                }
                
                // 节次多选部分 (新增)
                Section(header: Text("选择节次")) {
                    let columns = [
                        GridItem(.adaptive(minimum: 60))
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Constants.OptionData.periods) { period in
                            Button(action: {
                                viewModel.togglePeriodSelection(period.id)
                            }) {
                                Text(period.name.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "节", with: ""))
                                    .font(.system(.body, design: .rounded))
                                    .frame(minWidth: 44, minHeight: 44)
                                    .background(viewModel.selectedPeriods.contains(period.id) ? Color.blue : Color.gray.opacity(0.15))
                                    .foregroundColor(viewModel.selectedPeriods.contains(period.id) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !viewModel.selectedPeriods.isEmpty {
                        Button("清空选择") {
                            viewModel.clearPeriodSelection()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button(action: {
                        formSubmitted = true
                        viewModel.queryEmptyClassrooms()
                        
                        // 如果有结果，自动隐藏表单
                        withAnimation {
                            isShowingForm = false
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("查询")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            
            // 上次查询条件显示
            if formSubmitted && !isShowingForm && !viewModel.classrooms.isEmpty {
                QuerySummaryBar(showFormAction: {
                    withAnimation {
                        isShowingForm = true
                    }
                })
                .environmentObject(viewModel)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct QuerySummaryBar: View {
    @EnvironmentObject var viewModel: ClassroomViewModel
    var showFormAction: () -> Void
    
    // 格式化选中节次
    private var formattedPeriods: String {
        if viewModel.selectedPeriods.isEmpty {
            return "未选择节次"
        }
        
        let sortedPeriods = viewModel.selectedPeriods
            .compactMap { Int($0) }
            .sorted()
            .map { String($0) }
            .joined(separator: ",")
        
        return "第\(sortedPeriods)节"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 4) {
                HStack {
                    Text("\(viewModel.selectedCampus.name) \(viewModel.selectedBuilding.name == "全部" ? "" : viewModel.selectedBuilding.name)")
                        .font(.footnote)
                        .fontWeight(.medium)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.selectedWeek.name) \(viewModel.selectedWeekday.name)")
                        .font(.footnote)
                        .fontWeight(.medium)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(formattedPeriods)
                        .font(.footnote)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: showFormAction) {
                        Text("修改")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            
            Divider()
        }
    }
}

struct ClassroomResultListView: View {
    @EnvironmentObject var viewModel: ClassroomViewModel
    @Binding var sortOption: ClassroomQueryView.SortOption
    
    // 根据排序选项对教室进行排序
    var sortedClassrooms: [EmptyClassroom] {
        switch sortOption {
        case .name:
            return viewModel.filteredClassrooms.sorted {
                ($0.cdmc ?? "") < ($1.cdmc ?? "")
            }
        case .building:
            return viewModel.filteredClassrooms.sorted {
                ($0.jxlmc ?? "") < ($1.jxlmc ?? "")
            }
        case .seats:
            return viewModel.filteredClassrooms.sorted {
                (Int($0.zws ?? "0") ?? 0) > (Int($1.zws ?? "0") ?? 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索教室名称", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.onSearchTextChanged()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.onSearchTextChanged()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // 结果统计与排序
            if !viewModel.classrooms.isEmpty {
                HStack {
                    Text("共找到 \(viewModel.filteredClassrooms.count) 个空教室")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !viewModel.filteredClassrooms.isEmpty {
                        Text("按\(sortOption.rawValue)排序")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color(.systemGroupedBackground))
            }
            
            // 结果列表
            if viewModel.classrooms.isEmpty && !viewModel.isLoading {
                // 空结果视图
                EmptyResultView(
                    message: "没有符合条件的空教室，请尝试更改查询条件",
                    systemImageName: "building.2.crop.circle",
                    action: {
                        // 不能直接访问isShowingForm，需要使用其他方式
                    },
                    actionTitle: "修改条件"
                )
            } else {
                List {
                    ForEach(sortedClassrooms) { classroom in
                        ClassroomCell(classroom: classroom)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .alert("查询失败", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

struct ClassroomCell: View {
    let classroom: EmptyClassroom
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack(alignment: .center, spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: getIconName())
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(classroom.cdmc ?? "未知教室")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label(classroom.jxlmc ?? "未知教学楼", systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let seatsStr = classroom.zws, let seats = Int(seatsStr), seats > 0 {
                            Label("\(seats)座", systemImage: "person.3")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(classroom.cdlbmc ?? "普通教室")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ClassroomDetailView(classroom: classroom, isPresented: $showingDetail)
        }
    }
    
    // 根据教室类型返回不同的图标
    private func getIconName() -> String {
        if let type = classroom.cdlbmc?.lowercased() {
            if type.contains("机房") {
                return "desktopcomputer"
            } else if type.contains("实验") {
                return "flask"
            } else if type.contains("智慧") {
                return "laptopcomputer"
            } else if type.contains("多媒体") {
                return "tv"
            }
        }
        return "building.2"
    }
}

struct ClassroomDetailView: View {
    let classroom: EmptyClassroom
    @Binding var isPresented: Bool
    @State private var isSaved = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // 教室名称
                    HStack {
                        Text("教室名称")
                        Spacer()
                        Text(classroom.cdmc ?? "未知")
                            .foregroundColor(.secondary)
                    }
                    
                    // 所在教学楼
                    HStack {
                        Text("所在教学楼")
                        Spacer()
                        Text(classroom.jxlmc ?? "未知")
                            .foregroundColor(.secondary)
                    }
                    
                    // 所在校区
                    HStack {
                        Text("所在校区")
                        Spacer()
                        Text(classroom.xqmc ?? "未知")
                            .foregroundColor(.secondary)
                    }
                    
                    // 教室类型
                    HStack {
                        Text("教室类型")
                        Spacer()
                        Text(classroom.cdlbmc ?? "普通教室")
                            .foregroundColor(.secondary)
                    }
                    
                    // 座位数
                    if let seatsStr = classroom.zws, let seats = Int(seatsStr) {
                        HStack {
                            Text("座位数")
                            Spacer()
                            Text("\(seats)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    // 收藏按钮
                    Button(action: {
                        isSaved.toggle()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: isSaved ? "star.fill" : "star")
                                .foregroundColor(isSaved ? .yellow : .blue)
                            Text(isSaved ? "已收藏" : "收藏教室")
                                .foregroundColor(isSaved ? .primary : .blue)
                            Spacer()
                        }
                    }
                    
                    // 共享按钮
                    Button(action: {
                        // 创建共享内容
                        let seatsText = classroom.zws != nil ? (Int(classroom.zws!) ?? 0).description : "未知"
                        let roomInfo = """
                        教室信息：
                        
                        教室名称：\(classroom.cdmc ?? "未知")
                        所在教学楼：\(classroom.jxlmc ?? "未知")
                        所在校区：\(classroom.xqmc ?? "未知")
                        教室类型：\(classroom.cdlbmc ?? "普通教室")
                        座位数：\(seatsText)
                        """
                        
                        let activityVC = UIActivityViewController(
                            activityItems: [roomInfo],
                            applicationActivities: nil
                        )
                        
                        // 显示分享页面
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let controller = windowScene.windows.first?.rootViewController {
                            controller.present(activityVC, animated: true, completion: nil)
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("共享教室信息")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    // 关闭按钮
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack {
                            Spacer()
                            Text("关闭")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("教室详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ClassroomQueryView()
        .environmentObject(ClassroomViewModel())
        .environmentObject(LoginViewModel())
}
