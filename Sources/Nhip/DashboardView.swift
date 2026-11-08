import SwiftUI
import Charts
import NhipCore

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var period: ReportPeriod = .day
    @State private var selectedDate = Date()
    @State private var filter: UUID?
    @State private var editor: EntryDraft?
    private var calendar: Calendar { model.journal.preferences.calendar }
    private var range: DateInterval { model.showAllTimeSummary ? Reports.allTimeRange(model.journal) : Reports.range(period, date: selectedDate, calendar: calendar) }
    private var report: Report { Reports.summarize(model.journal, range: range, activityID: model.showAllTimeSummary ? nil : filter) }
    private var points: [ChartPoint] { Reports.points(model.journal, range: range, period: period, activityID: filter) }
    private var shownActivities: [Activity] { model.journal.activities.filter { filter == nil || filter == $0.id } }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            if model.showPersonalActivities {
                PersonalActivitiesView(model: model).background(Color(nsColor: .windowBackgroundColor))
            } else if model.showGoals {
                GoalsView(model: model).background(Color(nsColor: .windowBackgroundColor))
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !model.journal.preferences.onboarded { onboarding }
                    if model.storageFailed {
                        Label("Không thể mở hoặc lưu dữ liệu. Hãy sao lưu thư mục dữ liệu và khởi động lại; app đã dừng ghi nhận để bảo vệ lịch sử.", systemImage: "externaldrive.badge.exclamationmark").foregroundStyle(.red)
                    }
                    if model.authorization == .denied {
                        HStack {
                            Label("Banner macOS đang tắt. Bảng ghi nhận nhanh vẫn tự hiện.", systemImage: "bell.slash")
                            Spacer()
                            Button("Mở cài đặt macOS") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!) }
                        }.padding().background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let notice = model.notice {
                        HStack { Text(notice).font(.callout); Spacer(); Button("Đóng") { model.notice = nil } }.padding(12).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    controls
                    if model.showAllTimeSummary { goalCompletionContent }
                    if model.showAllTimeSummary {
                        allTimeContent
                    } else {
                        metrics
                        if period == .day {
                            dayContent
                        }
                        else { trendContent }
                    }
                }.padding(28)
            }.background(Color(nsColor: .windowBackgroundColor))
                .id(model.showAllTimeSummary ? "all-time" : period.rawValue)
            }
        }
        .frame(minWidth: 940, minHeight: 640)
        .environment(\.timeZone, calendar.timeZone)
        .sheet(item: $editor) { draft in EntryEditor(model: model, draft: draft) }
        .modifier(FeedbackModifier(model: model))
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path").font(.title).foregroundStyle(.indigo)
                VStack(alignment: .leading) { Text("Nhịp").font(.title.bold()); Text("Thời gian của bạn").font(.caption).foregroundStyle(.secondary) }
            }.padding(.bottom, 10)
            VStack(spacing: 6) {
                ForEach(ReportPeriod.allCases) { item in
                    Button { model.showPersonalActivities = false; model.showGoals = false; model.showAllTimeSummary = false; period = item } label: {
                        HStack(spacing: 12) { Image(systemName: symbol(item)).frame(width: 20); Text(item.rawValue).fontWeight(.medium); Spacer() }
                            .padding(12).background(!model.showPersonalActivities && !model.showGoals && !model.showAllTimeSummary && period == item ? Color.indigo.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(!model.showPersonalActivities && !model.showGoals && !model.showAllTimeSummary && period == item ? .indigo : .primary)
                    }.buttonStyle(.plain).modifier(SidebarFocusAppearance())
                }
            }
            Divider()
            VStack(spacing: 6) {
            Button { model.showPersonalActivities = false; model.showGoals = false; model.showAllTimeSummary = true } label: {
                HStack(spacing: 12) { Image(systemName: "sum").frame(width: 20); Text("Tổng kết").fontWeight(.medium); Spacer() }
                    .padding(12).background(model.showAllTimeSummary ? Color.indigo.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(model.showAllTimeSummary ? .indigo : .primary)
            }.buttonStyle(.plain).modifier(SidebarFocusAppearance()).help("Tổng số giờ từng hoạt động trong tất cả thời gian")
            Button { model.showPersonalActivities = false; model.showAllTimeSummary = false; model.showGoals = true } label: {
                HStack(spacing: 12) { Image(systemName: "target").frame(width: 20); Text("Mục tiêu").fontWeight(.medium); Spacer() }
                    .padding(12).background(model.showGoals ? Color.indigo.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(model.showGoals ? .indigo : .primary)
            }.buttonStyle(.plain).modifier(SidebarFocusAppearance())
            Button { model.showAllTimeSummary = false; model.showGoals = false; model.showPersonalActivities = true } label: {
                HStack(spacing: 12) { Image(systemName: "figure.walk").frame(width: 20); Text("Hoạt động hàng ngày").fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.8); Spacer() }
                    .padding(12).background(model.showPersonalActivities ? Color.indigo.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(model.showPersonalActivities ? .indigo : .primary)
            }.buttonStyle(.plain).modifier(SidebarFocusAppearance())
            }
            Button { WindowManager.shared.showSettings() } label: { Label("Cài đặt", systemImage: "slider.horizontal.3") }.buttonStyle(.plain)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) { Circle().fill(model.journal.runtime.segmentStart != nil ? .green : .orange).frame(width: 7, height: 7); Text(model.status).font(.caption) }
                if let due = model.journal.runtime.nextDue { Text("Nhắc tiếp lúc \(model.time(due))").font(.caption).foregroundStyle(.secondary) }
                if model.journal.runtime.enabled && model.journal.runtime.pauseUntil == nil {
                    Button("Tạm dừng") { model.pause() }.frame(maxWidth: .infinity)
                } else { Button("Bắt đầu theo dõi") { model.start() }.buttonStyle(.borderedProminent).tint(.indigo) }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            if model.demo { Text("CHẾ ĐỘ MINH HỌA").font(.caption2.bold()).foregroundStyle(.orange) }
        }.padding(22).frame(width: 235).frame(maxHeight: .infinity).background(.ultraThinMaterial)
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headerTitle).font(.system(size: 29, weight: .bold, design: .rounded))
                if !model.showAllTimeSummary && period == .week {
                    Text("Từ \(model.dateLabel(range.start)) đến \(model.dateLabel(range.end.addingTimeInterval(-1))).").foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !model.showAllTimeSummary && period == .day {
                Button { editor = EntryDraft(date: selectedDate, calendar: calendar, activityID: model.activeActivities.first?.id) } label: { Label("Thêm hoạt động", systemImage: "plus") }.buttonStyle(.borderedProminent).tint(.indigo)
            }
        }
    }
    private var headerTitle: String {
        if model.showAllTimeSummary { return "Tổng kết tất cả thời gian" }
        switch period {
        case .day: return "Một ngày của bạn"
        case .week: return "Tổng kết tuần \(periodValue(for: selectedDate))"
        case .month: return "Tổng kết tháng \(model.dateLabel(selectedDate, format: "MM/yyyy"))"
        case .year: return "Tổng kết năm \(model.dateLabel(selectedDate, format: "yyyy"))"
        }
    }
    private var controls: some View {
        HStack(spacing: 12) {
            if model.showAllTimeSummary {
                Text("Xin chào \(model.userName)!").foregroundStyle(.secondary)
            } else {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("\(period.rawValue) trước")
            periodSelector
            Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("\(period.rawValue) sau")
            Button(currentPeriodTitle) { selectedDate = Date() }
            Spacer()
            Picker("Hoạt động", selection: $filter) {
                Text("Tất cả hoạt động").tag(nil as UUID?)
                ForEach(model.journal.activities) { activity in Text(activity.name).tag(Optional(activity.id)) }
            }.labelsHidden().frame(width: 170)
            }
            if model.showAllTimeSummary { Spacer() }
        }
    }
    @ViewBuilder private var periodSelector: some View {
        switch period {
        case .day:
            DatePicker("Ngày", selection: $selectedDate, displayedComponents: .date).labelsHidden().frame(width: 125)
        case .week:
            HStack(spacing: 6) {
                Picker("Tuần", selection: Binding(get: { calendar.component(.weekOfYear, from: selectedDate) }, set: { week in
                    selectedDate = PeriodNavigation.weekDate(year: selectedYear, week: week, calendar: calendar)
                })) {
                    ForEach(1...PeriodNavigation.weeks(in: selectedYear, calendar: calendar), id: \.self) { week in Text("Tuần \(week)").tag(week) }
                }.labelsHidden().frame(width: 105)
                Text("/").foregroundStyle(.secondary)
                yearSelector
            }
        case .month:
            HStack(spacing: 6) {
                Picker("Tháng", selection: Binding(get: { calendar.component(.month, from: selectedDate) }, set: { month in
                    selectedDate = PeriodNavigation.monthDate(year: selectedYear, month: month, calendar: calendar)
                })) {
                    ForEach(1...12, id: \.self) { month in Text(String(format: "%02d", month)).tag(month) }
                }.labelsHidden().frame(width: 65)
                Text("/").foregroundStyle(.secondary)
                yearSelector
            }
        case .year:
            yearSelector
        }
    }
    private var selectedYear: Int {
        calendar.component(period == .week ? .yearForWeekOfYear : .year, from: selectedDate)
    }
    private var selectableYears: [Int] {
        let now = calendar.component(.year, from: Date())
        let firstRecorded = model.journal.entries.min(by: { $0.start < $1.start }).map { calendar.component(.year, from: $0.start) } ?? now
        let lastRecorded = model.journal.entries.max(by: { $0.end < $1.end }).map { calendar.component(.year, from: $0.end) } ?? now
        let first = min(now - 10, min(selectedYear, firstRecorded))
        let last = max(now + 10, max(selectedYear, lastRecorded))
        return Array((first...last).reversed())
    }
    private var yearSelector: some View {
        Picker(period == .week ? "Năm của tuần" : "Năm", selection: Binding(get: { selectedYear }, set: { year in
            if period == .week {
                selectedDate = PeriodNavigation.weekDate(year: year, week: calendar.component(.weekOfYear, from: selectedDate), calendar: calendar)
            } else {
                selectedDate = PeriodNavigation.monthDate(year: year, month: period == .year ? 1 : calendar.component(.month, from: selectedDate), calendar: calendar)
            }
        })) {
            ForEach(selectableYears, id: \.self) { year in Text(String(year)).tag(year) }
        }.labelsHidden().frame(width: 90)
    }
    private var currentPeriodTitle: String {
        switch period {
        case .day: return "Hôm nay"
        case .week: return "Tuần này"
        case .month: return "Tháng này"
        case .year: return "Năm nay"
        }
    }
    private func periodValue(for date: Date) -> String {
        switch period {
        case .day: return model.dateLabel(date)
        case .week: return "\(calendar.component(.weekOfYear, from: date))/\(calendar.component(.yearForWeekOfYear, from: date))"
        case .month: return model.dateLabel(date, format: "MM/yyyy")
        case .year: return model.dateLabel(date, format: "yyyy")
        }
    }
    private var metrics: some View {
        // Overview totals always cover the whole selected period,
        // independently of the activity filter used by the detailed charts.
        let totals = Reports.summarize(model.journal, range: range).totals
        return Group {
            if model.showAllTimeSummary {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                    metric("Học", seconds: summarySeconds(named: "Học", totals: totals), icon: "book.fill", color: .indigo)
                    metric("Nghiên cứu", seconds: summarySeconds(named: "Nghiên cứu", totals: totals), icon: "magnifyingglass", color: .teal)
                    metric("Làm việc", seconds: summarySeconds(named: "Công việc", totals: totals) + summarySeconds(named: "Làm việc", totals: totals), icon: "briefcase.fill", color: .blue)
                    metric("Tập thể thao", seconds: summarySeconds(named: "Tập thể thao", totals: totals), icon: "figure.run", color: .orange)
                    metric("Nghỉ ngơi", seconds: summarySeconds(named: "Nghỉ ngơi", totals: totals), icon: "cup.and.saucer.fill", color: Color(hex: "84A65B"))
                    metric("Giải trí", seconds: summarySeconds(named: "Giải trí", totals: totals), icon: "gamecontroller.fill", color: .pink)
                }
            } else {
                HStack(spacing: 14) {
                    metric("Học", seconds: summarySeconds(named: "Học", totals: totals), icon: "book.fill", color: .indigo)
                    metric("Nghiên cứu", seconds: summarySeconds(named: "Nghiên cứu", totals: totals), icon: "magnifyingglass", color: .teal)
                    metric("Tập thể thao", seconds: summarySeconds(named: "Tập thể thao", totals: totals), icon: "figure.run", color: .orange)
                }
            }
        }
    }
    private func summarySeconds(named name: String, totals: [UUID: Double]) -> Double {
        model.journal.activities.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).compare(name, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN")) == .orderedSame
        }.reduce(0) { $0 + totals[$1.id, default: 0] }
    }
    private func metric(_ title: String, seconds: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.callout).foregroundStyle(color)
            Text("\(seconds / 3600, format: .number.precision(.fractionLength(2))) giờ")
                .font(.system(size: 24, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.65)
            Text(durationText(seconds)).font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .help(model.showAllTimeSummary ? "Tổng thời gian \(title.lowercased()) trong toàn bộ lịch sử" : "Tổng thời gian \(title.lowercased()) trong kỳ \(period.rawValue.lowercased()) đang xem")
    }
    private var allTimeContent: some View {
        let summary = report
        let totals = summary.totals
        let total = summary.total
        let activities = model.journal.activities.enumerated().sorted { lhs, rhs in
            let left = totals[lhs.element.id, default: 0], right = totals[rhs.element.id, default: 0]
            return left == right ? lhs.offset < rhs.offset : left > right
        }.map(\.element)
        return Card(title: "Thời gian theo từng hoạt động") {
            metrics
            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tổng cộng").font(.callout).foregroundStyle(.secondary)
                    Text("\(total / 3600, format: .number.precision(.fractionLength(2))) giờ").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(durationText(total)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !model.journal.entries.isEmpty {
                    Text("\(model.dateLabel(range.start)) – \(model.dateLabel(range.end))").font(.callout).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack(spacing: 16) {
                Text("Hoạt động").frame(maxWidth: .infinity, alignment: .leading)
                Text("Tổng giờ").frame(width: 115, alignment: .trailing)
                Text("Thời lượng").frame(width: 145, alignment: .trailing)
                Text("Tỷ trọng").frame(width: 70, alignment: .trailing)
            }.font(.caption).foregroundStyle(.secondary)
            ForEach(activities) { activity in
                let seconds = totals[activity.id, default: 0]
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Label(activity.name, systemImage: activity.symbol).foregroundStyle(Color(hex: activity.color)).fontWeight(.medium)
                            if activity.archived { Text("Đã lưu trữ").font(.caption2).foregroundStyle(.secondary) }
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: activity.color).opacity(0.09))
                                if seconds > 0 { Capsule().fill(Color(hex: activity.color)).frame(width: max(3, geometry.size.width * seconds / max(1, total))) }
                            }
                        }.frame(height: 5)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(seconds / 3600, format: .number.precision(.fractionLength(2))) giờ").fontWeight(.semibold).monospacedDigit().frame(width: 115, alignment: .trailing)
                    Text(durationText(seconds)).foregroundStyle(.secondary).frame(width: 145, alignment: .trailing)
                    Text("\(total > 0 ? seconds / total : 0, format: .percent.precision(.fractionLength(0)))").foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
                }.padding(.vertical, 9)
            }
        }
    }
    private var goalCompletionContent: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let summary = GoalReports.completionSummary(model.journal, now: context.date)
            Card(title: "Nhiệm vụ đã hoàn thành") {
                HStack(alignment: .top, spacing: 16) {
                    goalCompletionMetric("Nhiệm vụ ngày", count: summary.daily, icon: "sun.max.fill", color: .indigo)
                    goalCompletionMetric("Nhiệm vụ tuần", count: summary.weekly, icon: "calendar", color: .teal)
                }
            }
        }
    }
    private func goalCompletionMetric(_ title: String, count: GoalCompletionCount, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
            Text("\(count.completed)/\(count.total)").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
            Text(count.total == 0 ? "Chưa có nhiệm vụ" : "nhiệm vụ đã hoàn thành").font(.callout).foregroundStyle(.secondary)
            HStack {
                Text("Tỷ lệ hoàn thành").foregroundStyle(.secondary)
                Spacer()
                if let rate = count.rate { Text(rate, format: .percent.precision(.fractionLength(1))).fontWeight(.semibold) }
                else { Text("—") }
            }.font(.callout)
            ProgressView(value: count.rate ?? 0).tint(color)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
    private var onboarding: some View {
        Card(title: "Chào bạn, đây là Nhịp") {
            Text("Sau mỗi 5 phút, bảng ghi nhận nhanh tự hiện. Bấm vào ô hoạt động để ghi nhận ngay; bỏ qua thì khoảng đó được để trống. Dữ liệu chỉ lưu trên máy.").foregroundStyle(.secondary)
            HStack {
                Button("Cho phép banner macOS (tùy chọn)") { model.requestAuthorization() }
                Button("Bắt đầu") {
                    model.start()
                }.buttonStyle(.borderedProminent).tint(.indigo)
                Button("Để tôi thiết lập trước") { WindowManager.shared.showSettings() }
            }
        }
    }
    private var dayContent: some View {
        VStack(spacing: 22) {
            Card(title: "Dòng thời gian · \(model.dateLabel(selectedDate))") {
                DayTimeline(model: model, range: range, filter: filter)
            }
            dailyPriorityContent
            Card(title: "Thời gian theo hoạt động") { activityBreakdown }
            Card(title: "Chi tiết hoạt động") {
                let entries = model.journal.entries.filter { $0.end > range.start && $0.start < range.end && (filter == nil || filter == $0.activityID) }.sorted { $0.start < $1.start }
                if entries.isEmpty { emptyState("Chưa có hoạt động", detail: "Bắt đầu theo dõi hoặc thêm một hoạt động để tạo nhật ký đầu tiên.") }
                else {
                    ForEach(entries) { entry in entryRow(entry) }
                }
            }
        }
    }
    private var activityBreakdown: some View {
        VStack(spacing: 14) {
            if report.total == 0 { emptyState("Chưa có dữ liệu", detail: "Thời lượng sẽ xuất hiện sau khi bạn xác nhận hoạt động.") }
            ForEach(shownActivities.filter { report.totals[$0.id, default: 0] > 0 }.sorted { report.totals[$0.id, default: 0] > report.totals[$1.id, default: 0] }) { activity in
                HStack(spacing: 14) {
                    Label(activity.name, systemImage: activity.symbol).frame(width: 160, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: activity.color).opacity(0.10))
                            Capsule().fill(Color(hex: activity.color)).frame(width: max(4, geo.size.width * report.totals[activity.id, default: 0] / max(1, report.total)))
                        }
                    }.frame(height: 8)
                    Text(durationText(report.totals[activity.id, default: 0])).monospacedDigit().frame(width: 125, alignment: .trailing)
                    Text(String(format: "%.0f%%", report.totals[activity.id, default: 0] / max(1, report.total) * 100)).font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }.font(.callout)
            }
        }
    }
    private func entryRow(_ entry: Entry) -> some View {
        let activity = model.journal.activity(entry.activityID)
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: activity?.color ?? "94A3B8")).frame(width: 4, height: 36)
            Text("\(model.time(max(entry.start, range.start)))–\(model.time(min(entry.end, range.end)))").font(.system(.callout, design: .monospaced)).frame(width: 112, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(activity?.name ?? "Khác").fontWeight(.medium)
                if !entry.note.isEmpty { Text(entry.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            Text(durationText(overlap(entry.start, entry.end, range.start, range.end))).font(.callout).foregroundStyle(.secondary)
            Button { editor = EntryDraft(entry: entry) } label: { Image(systemName: "pencil") }.help("Sửa hoặc tách khoảng")
        }
    }
    private var trendContent: some View {
        VStack(spacing: 22) {
            if period == .week { WeeklyGoalsView(model: model, date: selectedDate) }
            Card(title: "\(period.rawValue) · \(periodValue(for: selectedDate))") {
                if points.isEmpty { emptyState("Chưa có dữ liệu trong kỳ này", detail: "Bạn có thể chọn một kỳ khác hoặc thêm hoạt động.") }
                else {
                    Chart(points) { point in
                        BarMark(x: .value("Ngày", point.date, unit: period == .year ? .month : .day), y: .value("Giờ", point.seconds / 3600))
                            .foregroundStyle(by: .value("Hoạt động", model.journal.activity(point.activityID)?.name ?? "Khác"))
                            .annotation(position: .overlay) { EmptyView() }
                    }
                    .chartForegroundStyleScale(domain: shownActivities.map(\.name), range: shownActivities.map { Color(hex: $0.color) })
                    .chartXScale(domain: range.start...range.end)
                    .chartYAxisLabel("Giờ đã ghi nhận")
                    .frame(height: 255)
                }
                comparison
            }
            if period == .month { heatmap }
            if period == .year { yearlyAverage }
            Card(title: "Tổng hợp theo hoạt động") { activityBreakdown }
        }
    }
    private var comparison: some View {
        let now = Date()
        let priority = Reports.priorityComparison(model.journal, period: period, date: selectedDate, now: now)
        let delta = priority.deltaSeconds
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            if priority.activityIDs.isEmpty {
                HStack {
                    Text("Chưa chọn hoạt động ưu tiên").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Chọn trong Cài đặt") { WindowManager.shared.showSettings(tab: 1) }
                }
            } else {
                HStack {
                    Image(systemName: delta > 0 ? "arrow.up.right" : (delta < 0 ? "arrow.down.right" : "equal")).foregroundStyle(.indigo)
                    if delta == 0 {
                        Text("Thời gian ưu tiên bằng kỳ trước").font(.callout.bold())
                    } else {
                        Text("\(delta > 0 ? "Tăng" : "Giảm") \(durationText(abs(delta))) ưu tiên so với kỳ trước").font(.callout.bold())
                    }
                    if let change = priority.changeFraction { Text(String(format: "(%+.1f%%)", change * 100)).font(.callout).foregroundStyle(.secondary) }
                }
                if priority.changeFraction == nil { Text("Không đủ cơ sở tính %.").font(.caption).foregroundStyle(.secondary) }
                Text("So sánh \(period.rawValue.lowercased()) \(periodValue(for: priority.currentRange.start)) với \(period.rawValue.lowercased()) \(periodValue(for: priority.previousRange.start)).\(range.contains(now) ? " Cùng phần thời gian đã trôi qua." : "")").font(.caption).foregroundStyle(.secondary)
                Text("Kỳ này: \(durationText(priority.currentSeconds)) · Kỳ trước: \(durationText(priority.previousSeconds))").font(.caption).foregroundStyle(.secondary)
                Text("Trung bình/ngày: \(durationText(priority.currentSeconds / dayCount(priority.currentRange))) và \(durationText(priority.previousSeconds / dayCount(priority.previousRange))).").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var dailyPriorityContent: some View {
        let priority = Reports.dailyPriorityTotals(model.journal, date: selectedDate)
        return Card(title: "Tổng thời gian ưu tiên") {
            if priority.activityIDs.isEmpty {
                HStack {
                    Text("Chưa chọn hoạt động ưu tiên").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Chọn trong Cài đặt") { WindowManager.shared.showSettings(tab: 1) }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hôm nay").font(.callout).foregroundStyle(.secondary)
                    Label {
                        Text("\(priority.currentSeconds / 3600, format: .number.precision(.fractionLength(2))) giờ")
                    } icon: { Image(systemName: "star.fill").foregroundStyle(.orange) }
                    .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("\(durationText(priority.currentSeconds)) · ≈ \(priority.currentSeconds / 86400, format: .percent.precision(.fractionLength(1))) của 24 giờ")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Text("Hôm qua").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(priority.previousSeconds / 3600, format: .number.precision(.fractionLength(2))) giờ").font(.headline).monospacedDigit()
                        Text("\(durationText(priority.previousSeconds)) · ≈ \(priority.previousSeconds / 86400, format: .percent.precision(.fractionLength(1))) của 24 giờ")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack {
                    Image(systemName: priority.deltaSeconds > 0 ? "arrow.up.right" : (priority.deltaSeconds < 0 ? "arrow.down.right" : "equal"))
                    if priority.deltaSeconds == 0 {
                        Text("Bằng hôm qua")
                    } else {
                        Text("\(priority.deltaSeconds > 0 ? "Nhiều hơn" : "Ít hơn") hôm qua \(durationText(abs(priority.deltaSeconds)))")
                        if let change = priority.changeFraction { Text(String(format: "(%+.1f%%)", change * 100)) }
                    }
                }.font(.callout.bold())
                    .foregroundStyle(priority.deltaSeconds > 0 ? Color.green : (priority.deltaSeconds < 0 ? Color.orange : Color.secondary))
            }
        }
    }
    private var heatmap: some View {
        let days = Int(calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30)
        let offset = (calendar.component(.weekday, from: range.start) + 5) % 7
        return Card(title: "Nhịp hoạt động trong tháng") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(["T2","T3","T4","T5","T6","T7","CN"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                // One sequence gives every grid cell a unique identity. Separate
                // 0-based spacer/day loops caused the first dates to disappear.
                ForEach(0..<(offset + days), id: \.self) { cell in
                    if cell < offset {
                        Color.clear.frame(height: 48).accessibilityHidden(true)
                    } else {
                    let day = cell - offset
                    let start = calendar.date(byAdding: .day, value: day, to: range.start)!
                    let end = calendar.date(byAdding: .day, value: 1, to: start)!
                    let r = Reports.summarize(model.journal, range: DateInterval(start: start, end: end))
                    let seconds = filter.map { r.totals[$0, default: 0] } ?? r.total
                    let hasData = r.total > 0
                    Button { selectedDate = start; period = .day } label: {
                        VStack(spacing: 3) {
                            Text("\(day + 1)").font(.caption.bold())
                            Text(hasData ? durationText(seconds) : "—").font(.system(size: 9))
                        }.frame(maxWidth: .infinity).frame(height: 48)
                            .background(hasData ? Color.indigo.opacity(min(0.85, 0.1 + seconds / 36000)) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).help(hasData ? durationText(seconds) : "Chưa có hoạt động")
                        .accessibilityLabel("Ngày \(day + 1), \(model.dateLabel(start, format: "MM/yyyy"))")
                    }
                }
            }
        }
    }
    private var yearlyAverage: some View {
        let grouped = Dictionary(grouping: points, by: \.date)
        let dates = grouped.keys.sorted()
        return Card(title: "Trung bình mỗi ngày trong tháng") {
            Chart(dates, id: \.self) { date in
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: date)!
                let elapsedEnd = min(monthEnd, Date())
                let days = dayCount(DateInterval(start: date, end: max(date, elapsedEnd)))
                let hours = grouped[date, default: []].reduce(0) { $0 + $1.seconds } / 3600 / days
                LineMark(x: .value("Tháng", date), y: .value("Giờ/ngày", hours)).foregroundStyle(.indigo).symbol(.circle)
            }.chartYAxisLabel("Giờ / ngày lịch").frame(height: 170)
        }
    }
    private func symbol(_ p: ReportPeriod) -> String { switch p { case .day: return "sun.max"; case .week: return "calendar"; case .month: return "square.grid.3x3"; case .year: return "chart.xyaxis.line" } }
    private func move(_ direction: Int) { selectedDate = PeriodNavigation.move(period, from: selectedDate, by: direction, calendar: calendar) }
    private func dayCount(_ range: DateInterval) -> Double { max(1, Double(calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 1) + (calendar.startOfDay(for: range.end) < range.end ? 1 : 0)) }
}

private struct SidebarFocusAppearance: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            // Keep keyboard focus, but use the selected row's background instead of a native ring.
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

func emptyState(_ title: String, detail: String) -> some View {
    VStack(spacing: 9) {
        Image(systemName: "clock.badge.questionmark").font(.system(size: 30)).foregroundStyle(.secondary)
        Text(title).font(.headline)
        Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }.padding(28).frame(maxWidth: .infinity)
}

struct DayTimeline: View {
    @ObservedObject var model: AppModel
    let range: DateInterval
    let filter: UUID?
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.04))
                    ForEach(model.journal.entries.filter { $0.end > range.start && $0.start < range.end && (filter == nil || filter == $0.activityID) }) { entry in
                        segment(start: entry.start, end: entry.end, width: geometry.size.width, color: Color(hex: model.journal.activity(entry.activityID)?.color ?? "94A3B8"))
                            .help("\(model.time(entry.start))–\(model.time(entry.end)) · \(model.journal.activity(entry.activityID)?.name ?? "") · \(durationText(entry.seconds))")
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 8))
            }.frame(height: 38)
            HStack { ForEach(["00:00","06:00","12:00","18:00","24:00"], id: \.self) { label in Text(label); if label != "24:00" { Spacer() } } }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
    private func segment(start: Date, end: Date, width: CGFloat, color: Color) -> some View {
        let a = max(start, range.start), b = min(end, range.end)
        return Rectangle().fill(color).frame(width: max(1, width * b.timeIntervalSince(a) / range.duration)).offset(x: width * a.timeIntervalSince(range.start) / range.duration)
    }
}
