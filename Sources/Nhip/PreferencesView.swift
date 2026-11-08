import SwiftUI
import NhipCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var userName = ""
    @State private var preferences = Preferences()
    @State private var newName = ""
    @State private var categoryEditor: Activity?
    @State private var timezone = ""
    @State private var validationError: String?
    private let dayNames = ["", "Chủ nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cài đặt Nhịp").font(.title.bold())
            Picker("Nhóm cài đặt", selection: $model.settingsTab) {
                Text("Cá nhân").tag(3); Text("Nhắc & lịch").tag(0); Text("Hoạt động").tag(1); Text("Dữ liệu").tag(2)
            }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.settingsTab {
                    case 0: reminderSettings
                    case 1: categories
                    case 3: profileSettings
                    default: dataSettings
                    }
                }.padding(2)
            }
        }.padding(24)
            .onAppear { preferences = model.journal.preferences; timezone = preferences.timezone; userName = model.userName; model.refreshAuthorization() }
            .sheet(item: $categoryEditor) { activity in CategoryEditor(model: model, activity: activity) }
            .modifier(FeedbackModifier(model: model))
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
                            Text(reminder.timeLabel).monospacedDigit()
                        }
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
                Button("Thêm") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    model.perform { $0.activities.append(Activity(name: name, color: "6366F1")) }; newName = ""
                }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
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
        var draft = model.journal; draft.preferences = preferences
        do { try Engine.validate(draft); model.updatePreferences(preferences); validationError = nil; model.notice = "Đã lưu cài đặt." }
        catch { validationError = error.localizedDescription }
    }
    private func moveCategory(_ index: Int, _ direction: Int) { model.perform { $0.activities.swapAt(index, index + direction) } }
}

struct CategoryEditor: View {
    @ObservedObject var model: AppModel
    @State var activity: Activity
    @State private var symbolQuery = ""
    @State private var symbolGroup: ActivitySymbolGroup = .all
    @Environment(\.dismiss) private var dismiss
    private var symbols: [ActivitySymbol] { ActivitySymbols.matching(symbolQuery, group: symbolGroup) }
    let colors = ["6366F1", "0EA5A4", "F59E0B", "EC4899", "3B82F6", "A78BFA", "84A65B", "EF4444", "94A3B8"]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sửa hoạt động").font(.title2.bold())
            TextField("Tên", text: $activity.name).textFieldStyle(.roundedBorder)
            Toggle("Hoạt động ưu tiên", isOn: Binding(get: { activity.isPriority == true }, set: { activity.isPriority = $0 }))
            HStack { ForEach(colors, id: \.self) { color in Button { activity.color = color } label: { Circle().fill(Color(hex: color)).frame(width: 28, height: 28).overlay(Circle().stroke(activity.color == color ? Color.primary : .clear, lineWidth: 2).padding(-3)) }.buttonStyle(.plain).accessibilityLabel("Màu \(color)") } }
            symbolPicker
            HStack { Spacer(); Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction); Button("Lưu") {
                activity.name = activity.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if model.perform({ journal in
                    guard let index = journal.activities.firstIndex(where: { $0.id == activity.id }) else {
                        throw JournalError.invalid("Không tìm thấy hoạt động để sửa.")
                    }
                    var updated = activity
                    PersonalTracking.preserveRole(of: journal.activities[index], in: &updated)
                    journal.activities[index] = updated
                }) { dismiss() }
            }.buttonStyle(.borderedProminent).disabled(activity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 620)
    }
    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Biểu tượng").font(.headline)
                Spacer()
                Image(systemName: activity.symbol).foregroundStyle(Color(hex: activity.color))
                Text(ActivitySymbols.all.first { $0.name == activity.symbol }?.title ?? "Hiện tại")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                TextField("Tìm biểu tượng", text: $symbolQuery).textFieldStyle(.roundedBorder).accessibilityLabel("Tìm biểu tượng")
                if !symbolQuery.isEmpty {
                    Button { symbolQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).accessibilityLabel("Xóa tìm kiếm")
                }
                Picker("Nhóm biểu tượng", selection: $symbolGroup) {
                    ForEach(ActivitySymbolGroup.allCases) { group in Text(group.title).tag(group) }
                }.labelsHidden().frame(width: 160).accessibilityLabel("Nhóm biểu tượng")
            }
            Text("\(symbols.count) biểu tượng").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                if symbols.isEmpty {
                    Text("Không tìm thấy biểu tượng").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(symbols) { symbol in
                            Button { activity.symbol = symbol.name } label: {
                                Image(systemName: symbol.name).font(.system(size: 20))
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .foregroundStyle(activity.symbol == symbol.name ? Color(hex: activity.color) : Color.primary)
                                    .background(activity.symbol == symbol.name ? Color(hex: activity.color).opacity(0.15) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(activity.symbol == symbol.name ? Color(hex: activity.color) : .clear, lineWidth: 1.5))
                            }.buttonStyle(.plain).help(symbol.title).accessibilityLabel("Biểu tượng \(symbol.title)")
                                .accessibilityValue(activity.symbol == symbol.name ? "Đang chọn" : "")
                        }
                    }.padding(3)
                }
            }.frame(height: 230)
        }
    }
}
