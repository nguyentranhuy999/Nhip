import SwiftUI
import NhipCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var userName = ""
    @State private var preferences = Preferences()
    @State private var sleepSchedule = SleepSchedule()
    @State private var sleepScheduleError: String?
    @State private var newName = ""
    @State private var newActivityError: String?
    @State private var categoryEditor: Activity?
    @State private var interfaceIconEditor: InterfaceSection?
    @State private var timezone = ""
    @State private var validationError: String?
    private let dayNames = ["", "Chủ nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(InterfaceSection.settings.title(in: model.journal.preferences)) Nhịp").font(.title.bold())
            Picker("Nhóm cài đặt", selection: $model.settingsTab) {
                Text("Cá nhân").tag(3); Text("Nhắc & lịch").tag(0); Text("Hoạt động").tag(1); Text("Giao diện").tag(4); Text("Dashboard").tag(5); Text("Dữ liệu").tag(2)
            }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.settingsTab {
                    case 0: reminderSettings
                    case 1: categories
                    case 3: profileSettings
                    case 4: interfaceSettings
                    case 5: DashboardSettingsView(model: model)
                    default: dataSettings
                    }
                }.padding(2)
            }
        }.padding(24)
            .onAppear { preferences = model.journal.preferences; timezone = preferences.timezone; userName = model.userName; sleepSchedule = SleepPlan.schedule(model.journal); model.refreshAuthorization() }
            .onChange(of: model.journal.sleepReminders?.schedule) { _ in sleepSchedule = SleepPlan.schedule(model.journal) }
            .onChange(of: sleepSchedule) { _ in sleepScheduleError = nil }
            .onChange(of: model.journal.preferences.interfaceTitles) { _ in
                WindowManager.shared.settings?.title = "\(InterfaceSection.settings.title(in: model.journal.preferences)) Nhịp"
            }
            .sheet(item: $categoryEditor) { activity in CategoryEditor(model: model, activity: activity) }
            .sheet(item: $interfaceIconEditor) { section in InterfaceIconEditor(model: model, section: section) }
            .modifier(FeedbackModifier(model: model))
    }
    private var interfaceSettings: some View {
        Card(title: "Các mục giao diện") {
            ForEach(InterfaceSection.allCases) { section in
                HStack(spacing: 12) {
                    Label(section.title(in: model.journal.preferences), systemImage: section.displaySymbol(in: model.journal.preferences))
                        .lineLimit(1).truncationMode(.tail).help(section.title(in: model.journal.preferences))
                    Spacer()
                    Button("Sửa") { interfaceIconEditor = section }
                        .accessibilityLabel("Sửa mục \(section.title)")
                    Button {
                        model.perform { section.setTitle(nil, in: &$0.preferences); section.setSymbol(nil, in: &$0.preferences) }
                    } label: { Image(systemName: "arrow.counterclockwise") }
                        .accessibilityLabel("Khôi phục tên và biểu tượng mục \(section.title)")
                        .help("Khôi phục tên và biểu tượng mặc định")
                        .disabled(model.journal.preferences.interfaceIcons?[section.rawValue] == nil && model.journal.preferences.interfaceTitles?[section.rawValue] == nil)
                }.padding(.vertical, 5)
            }
            Divider()
            Button("Khôi phục tất cả mục về mặc định") {
                model.perform { $0.preferences.interfaceIcons = nil; $0.preferences.interfaceTitles = nil }
            }.disabled(model.journal.preferences.interfaceIcons?.isEmpty != false && model.journal.preferences.interfaceTitles?.isEmpty != false)
        }
    }
    private var profileSettings: some View {
        Card(title: "Thông tin cá nhân") {
            TextField("Tên người dùng", text: $userName).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Tên người dùng")
                .onSubmit { saveUserName() }
            Button("Lưu tên") { saveUserName() }.buttonStyle(.borderedProminent).tint(.indigo)
        }
    }
    private func saveUserName() {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.perform({ $0.preferences.userName = name.isEmpty ? nil : name }) {
            userName = model.userName
            preferences.userName = model.journal.preferences.userName
        }
    }
    private var reminderSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Card(title: "Nhắc nhở ngủ") {
                Toggle("Bật nhắc nhở ngủ", isOn: Binding(get: { SleepPlan.isEnabled(model.journal) }, set: { model.toggleSleepReminders($0) }))
                if SleepPlan.isEnabled(model.journal) {
                    ForEach(SleepReminder.allCases) { reminder in
                        HStack {
                            Label(reminder.title, systemImage: reminder.symbol)
                            Spacer()
                            sleepTimePicker(reminder)
                        }
                    }
                    if let sleepScheduleError { Text(sleepScheduleError).font(.callout).foregroundStyle(.red) }
                    HStack {
                        Button("Lưu giờ nhắc") { saveSleepSchedule() }.buttonStyle(.borderedProminent).tint(.indigo)
                            .disabled(sleepSchedule == SleepPlan.schedule(model.journal))
                        Button("Giờ mặc định") { sleepSchedule = SleepSchedule() }
                            .disabled(sleepSchedule == SleepSchedule())
                    }
                    HStack {
                        Button("Thử lời nhắc ngủ") { model.previewSleepReminder() }
                        if model.authorization == .denied {
                            Button("Cho phép thông báo trong macOS") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                            }
                        }
                    }
                }
            }
            Card(title: "Chu kỳ ghi nhận") {
                Picker("Nhắc sau mỗi", selection: $preferences.intervalMinutes) { ForEach([5,10,15,30,60], id: \.self) { Text("\($0) phút").tag($0) } }.frame(maxWidth: 330)
                Toggle("Phát âm báo", isOn: $preferences.sound)
                HStack {
                    Toggle("Âm thanh khi ghi nhận thành công", isOn: Binding(
                        get: { preferences.isCheckInSuccessSoundEnabled },
                        set: { preferences.checkInSuccessSound = $0 }
                    ))
                    Spacer()
                    Button("Nghe thử") { model.previewCheckInSuccessSound() }
                        .accessibilityLabel("Nghe thử âm thanh ghi nhận thành công")
                }
                Button("Xem thử bảng nhắc nhanh") { model.previewReminder() }
                HStack {
                    Text("Banner macOS (tùy chọn): \(authorizationText)").foregroundStyle(.secondary)
                    Button("Xin quyền / kiểm tra") { model.requestAuthorization() }
                    Button("Gửi thông báo thử") { model.sendTestNotification() }
                }
                Toggle("Mở Nhịp khi đăng nhập máy", isOn: Binding(get: { model.loginEnabled }, set: { model.toggleLogin($0) }))
            }
            Card(title: "Lịch theo dõi") {
                Toggle("Chỉ theo dõi trong khung giờ đã chọn", isOn: $preferences.scheduled)
                if preferences.scheduled {
                    ForEach($preferences.windows) { $window in
                        HStack {
                            Picker("Ngày", selection: $window.weekday) { ForEach([2,3,4,5,6,7,1], id: \.self) { Text(dayNames[$0]).tag($0) } }.labelsHidden().frame(width: 130)
                            minutePicker("Từ", value: $window.startMinute)
                            minutePicker("Đến", value: $window.endMinute)
                            Button { preferences.windows.removeAll { $0.id == window.id } } label: { Image(systemName: "trash") }.accessibilityLabel("Xóa khung giờ")
                        }
                    }
                    Button("Thêm khung giờ") { preferences.windows.append(ScheduleWindow(weekday: 2)) }
                    if preferences.windows.isEmpty { Text("Chưa có khung giờ: app sẽ chờ lịch và không gửi nhắc.").foregroundStyle(.orange).font(.caption) }
                }
            }
            Card(title: "Múi giờ báo cáo") {
                TextField("Ví dụ: Asia/Ho_Chi_Minh", text: $timezone).textFieldStyle(.roundedBorder)
            }
            if let validationError { Text(validationError).foregroundStyle(.red) }
            HStack {
                Button("Lưu cài đặt") { savePreferences() }.buttonStyle(.borderedProminent).tint(.indigo)
                if let notice = model.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func sleepTimePicker(_ reminder: SleepReminder) -> some View {
        let calendar = preferences.calendar
        return DatePicker(reminder.title, selection: Binding(get: {
            let minute = sleepSchedule[reminder]
            // A fixed ordinary date avoids editing a nonexistent hour on a DST transition day.
            return calendar.date(from: DateComponents(year: 2001, month: 1, day: 15, hour: minute / 60, minute: minute % 60))!
        }, set: { date in
            sleepSchedule[reminder] = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }), displayedComponents: .hourAndMinute)
            .labelsHidden().frame(width: 100)
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
            .accessibilityLabel("Giờ nhắc \(reminder.title.lowercased())")
    }
    private func saveSleepSchedule() {
        do {
            try sleepSchedule.validate()
            if model.perform({ try SleepPlan.setSchedule(sleepSchedule, journal: &$0) }) { sleepScheduleError = nil }
        } catch { sleepScheduleError = error.localizedDescription }
    }
    private func minutePicker(_ title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 3) {
            Text(title).font(.caption)
            Picker(title, selection: value) {
                ForEach(0...96, id: \.self) { step in Text(String(format: "%02d:%02d", step / 4, (step % 4) * 15)).tag(step * 15) }
            }.labelsHidden().frame(width: 95)
        }
    }
    private var categories: some View {
        Card(title: "Danh mục của bạn") {
            ForEach(Array(model.journal.activities.enumerated()), id: \.element.id) { index, activity in
                HStack {
                    Image(systemName: activity.symbol).foregroundStyle(Color(hex: activity.color)).frame(width: 25)
                    Text(activity.name)
                    if activity.archived { Text("Đã lưu trữ").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button {
                        model.perform { journal in
                            if let index = journal.activities.firstIndex(where: { $0.id == activity.id }) {
                                journal.activities[index].isPriority = journal.activities[index].isPriority != true
                            }
                        }
                    } label: {
                        Image(systemName: activity.isPriority == true ? "star.fill" : "star")
                            .foregroundStyle(activity.isPriority == true ? Color.orange : Color.secondary)
                            .frame(width: 24, height: 24)
                    }.buttonStyle(.plain).accessibilityLabel("Ưu tiên \(activity.name)")
                        .accessibilityValue(activity.isPriority == true ? "Đã chọn" : "Chưa chọn")
                        .help(activity.isPriority == true ? "Bỏ ưu tiên \(activity.name)" : "Ưu tiên \(activity.name)")
                    if PersonalTracking.isRest(activity, journal: model.journal) {
                        Text("Ghi nhận giấc ngủ").font(.caption).foregroundStyle(.secondary).frame(width: 145)
                    } else {
                        Picker("Cách ghi nhận \(activity.name)", selection: Binding(
                            get: { PersonalTracking.recordingMode(of: model.journal.activity(activity.id) ?? activity) },
                            set: { model.setRecordingMode($0, activityID: activity.id) }
                        )) {
                            ForEach(ActivityRecordingMode.allCases) { mode in Text(mode.title).tag(mode) }
                        }.labelsHidden().frame(width: 145).accessibilityLabel("Cách ghi nhận \(activity.name)")
                    }
                    Button { moveCategory(index, -1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0).help("Đưa lên")
                    Button { moveCategory(index, 1) } label: { Image(systemName: "arrow.down") }.disabled(index == model.journal.activities.count - 1).help("Đưa xuống")
                    Button("Sửa") { categoryEditor = activity }
                    Button(activity.archived ? "Khôi phục" : "Lưu trữ") {
                        if !activity.archived && model.activeActivities.count <= 1 { model.error = "Cần giữ ít nhất một hoạt động để ghi nhận."; return }
                        model.perform { $0.activities[index].archived.toggle() }
                    }
                }
            }
            Divider()
            HStack {
                TextField("Tên hoạt động mới", text: $newName).textFieldStyle(.roundedBorder)
                    .onChange(of: newName) { _ in newActivityError = nil }
                Button("Thêm") { addActivity() }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let newActivityError { Text(newActivityError).font(.callout).foregroundStyle(.red) }
        }
    }
    private func addActivity() {
        var candidate = model.journal
        do {
            try ActivityCatalog.add(&candidate, name: newName)
            if model.perform({ $0 = candidate }) { newName = ""; newActivityError = nil }
        } catch { newActivityError = error.localizedDescription }
    }
    private var dataSettings: some View {
        Card(title: "Dữ liệu nằm trên máy của bạn") {
            Text(model.dataDirectory.path).font(.caption.monospaced()).textSelection(.enabled)
            HStack {
                Button("Mở thư mục dữ liệu") { NSWorkspace.shared.open(model.dataDirectory) }
                Button("Sao lưu JSON…") { model.backup() }
                Button("Khôi phục JSON…") { model.restore() }
                Button("Xuất CSV…") { model.exportCSV(range: Reports.allTimeRange(model.journal)) }
            }
            Divider()
            Button("Hoàn tác lần chỉnh sửa gần nhất") { model.undo() }
            Button("Xóa toàn bộ dữ liệu…", role: .destructive) { model.resetData() }
            if let notice = model.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
        }
    }
    private var authorizationText: String {
        switch model.authorization { case .authorized, .provisional: return "Đã cho phép"; case .denied: return "Đã từ chối trong macOS"; default: return "Chưa yêu cầu" }
    }
    private func savePreferences() {
        preferences.timezone = timezone.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.interfaceIcons = model.journal.preferences.interfaceIcons
        preferences.interfaceTitles = model.journal.preferences.interfaceTitles
        preferences.dashboardActivities = model.journal.preferences.dashboardActivities
        var draft = model.journal; draft.preferences = preferences
        do {
            try SleepPlan.setSchedule(sleepSchedule, journal: &draft)
            try Engine.validate(draft)
            model.updatePreferences(preferences, sleepSchedule: sleepSchedule)
            validationError = nil; model.notice = "Đã lưu cài đặt."
        } catch { validationError = error.localizedDescription }
    }
    private func moveCategory(_ index: Int, _ direction: Int) { model.perform { $0.activities.swapAt(index, index + direction) } }
}

struct CategoryEditor: View {
    @ObservedObject var model: AppModel
    @State var activity: Activity
    @State private var validationError: String?
    @Environment(\.dismiss) private var dismiss
    let colors = ["6366F1", "0EA5A4", "F59E0B", "EC4899", "3B82F6", "A78BFA", "84A65B", "EF4444", "94A3B8"]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sửa hoạt động").font(.title2.bold())
            TextField("Tên", text: $activity.name).textFieldStyle(.roundedBorder)
                .onChange(of: activity.name) { _ in validationError = nil }
            Toggle("Hoạt động ưu tiên", isOn: Binding(get: { activity.isPriority == true }, set: { activity.isPriority = $0 }))
            HStack { ForEach(colors, id: \.self) { color in Button { activity.color = color } label: { Circle().fill(Color(hex: color)).frame(width: 28, height: 28).overlay(Circle().stroke(activity.color == color ? Color.primary : .clear, lineWidth: 2).padding(-3)) }.buttonStyle(.plain).accessibilityLabel("Màu \(color)") } }
            SymbolPicker(selection: $activity.symbol, tint: Color(hex: activity.color))
            if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lưu") { save() }.buttonStyle(.borderedProminent)
                    .disabled(activity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 620)
    }
    private func save() {
        var candidate = model.journal
        do {
            try ActivityCatalog.update(&candidate, activity: activity)
            if model.perform({ $0 = candidate }) { dismiss() }
            else { validationError = model.error ?? "Không thể lưu thay đổi." }
        } catch { validationError = error.localizedDescription }
    }
}
