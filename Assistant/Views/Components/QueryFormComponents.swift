//
//  QueryFormComponents.swift
//  Assistant
//
//  Created by 辰心 on 2025/5/9.
//

import SwiftUI

// 自定义分段控件
struct SegmentedOptionPicker<T: Identifiable>: View {
    var title: String
    var options: [T]
    @Binding var selectedOption: T
    var displayText: (T) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        Button(action: {
                            selectedOption = option
                        }) {
                            Text(displayText(option))
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedOption.id as AnyObject === option.id as AnyObject ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedOption.id as AnyObject === option.id as AnyObject ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// 自定义选择器（带有标题和图标）
struct FormPickerView<T: Hashable>: View {
    var title: String
    var icon: String
    var options: [T]
    @Binding var selectedOption: T
    var displayText: (T) -> String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Picker(title, selection: $selectedOption) {
                ForEach(options, id: \.self) { option in
                    Text(displayText(option)).tag(option)
                }
            }
            .pickerStyle(DefaultPickerStyle())
        }
    }
}

// 自定义校区选择组件
struct CampusPickerView: View {
    var campuses: [Campus]
    @Binding var selectedCampus: Campus
    var onCampusChanged: () -> Void
    
    var body: some View {
        Section(header: Text("校区选择")) {
            HStack {
                ForEach(campuses) { campus in
                    Button(action: {
                        if selectedCampus.id != campus.id {
                            selectedCampus = campus
                            onCampusChanged()
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "building.2")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                            
                            Text(campus.name)
                                .font(.caption)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedCampus.id == campus.id ? Color.blue.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedCampus.id == campus.id ? .blue : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedCampus.id == campus.id ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// 自定义周次选择组件
struct WeekSelectorView: View {
    @Binding var selectedWeek: Week
    var weeks: [Week]
    var onWeekChanged: () -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        Section(header: Text("选择周次")) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weeks) { week in
                    Button(action: {
                        if selectedWeek.id != week.id {
                            selectedWeek = week
                            onWeekChanged()
                        }
                    }) {
                        Text("\(week.id)")
                            .font(.system(.body, design: .rounded))
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedWeek.id == week.id ? Color.blue : Color.gray.opacity(0.15))
                            .foregroundColor(selectedWeek.id == week.id ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// 自定义星期和节次选择组件
struct TimeSelectView: View {
    @Binding var selectedWeekday: Weekday
    @Binding var selectedStartPeriod: Period
    @Binding var selectedEndPeriod: Period
    var weekdays: [Weekday]
    var periods: [Period]
    
    var body: some View {
        Section(header: Text("选择时间")) {
            // 星期选择
            HStack {
                Text("星期")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(weekdays) { weekday in
                            Button(action: {
                                selectedWeekday = weekday
                            }) {
                                Text(weekday.name.replacingOccurrences(of: "星期", with: ""))
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedWeekday.id == weekday.id ? Color.blue : Color.gray.opacity(0.15))
                                    .foregroundColor(selectedWeekday.id == weekday.id ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            // 节次选择
            HStack {
                Text("节次")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                Picker("开始", selection: $selectedStartPeriod) {
                    ForEach(periods) { period in
                        Text(period.name).tag(period)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 80)
                
                Text("至")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("结束", selection: $selectedEndPeriod) {
                    ForEach(periods) { period in
                        Text(period.name).tag(period)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 80)
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// 自定义查询按钮
struct QueryButton: View {
    var action: () -> Void
    var isLoading: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "magnifyingglass")
                    Text("查询")
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .disabled(isLoading)
    }
}

// 建筑物详情弹窗
struct BuildingInfoSheet: View {
    var building: Building
    var classrooms: [EmptyClassroom]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("教学楼信息")) {
                    HStack {
                        Text("名称")
                        Spacer()
                        Text(building.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("教室数量")
                        Spacer()
                        Text("\(classrooms.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("可用教室列表")) {
                    ForEach(classrooms) { classroom in
                        VStack(alignment: .leading) {
                            Text(classroom.cdmc ?? "未知教室")
                                .font(.headline)
                            
                            HStack {
                                if let seats = classroom.zws {
                                    Label("\(seats)座", systemImage: "person.3")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(classroom.cdlbmc ?? "普通教室")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(building.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 预览
struct QueryFormComponents_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 分段控件预览
            SegmentedOptionPicker(
                title: "选择校区",
                options: Constants.OptionData.campuses,
                selectedOption: .constant(Constants.OptionData.campuses[0]),
                displayText: { $0.name }
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("分段控件")
            
            // 校区选择组件预览
            CampusPickerView(
                campuses: Constants.OptionData.campuses,
                selectedCampus: .constant(Constants.OptionData.campuses[0]),
                onCampusChanged: {}
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("校区选择")
            
            // 周次选择组件预览
            WeekSelectorView(
                selectedWeek: .constant(Constants.OptionData.weeks[0]),
                weeks: Constants.OptionData.weeks,
                onWeekChanged: {}
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("周次选择")
            
            // 查询按钮预览
            QueryButton(
                action: {},
                isLoading: false
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("查询按钮")
        }
    }
}
