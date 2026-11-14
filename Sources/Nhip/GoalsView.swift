import SwiftUI
import NhipCore

struct GoalsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedDate = Date()
    @State private var activityID: UUID?
    @State private var hours = "1"
    @State private var validationError: String?
    @State private var message: String?
    @State private var removedChange: DailyPlanChange?
    private var calendar: Calendar { model.journal.preferences.calendar }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            page(now: context.date)
        }
        .onAppear { activityID = model.activeActivities.first?.id; loadTarget() }
        .onChange(of: activityID) { _ in loadTarget() }
        .onChange(of: selectedDate) { _ in clearFeedback(); loadTarget() }
        .onChange(of: model.journal.goals) { _ in loadTarget() }
        .modifier(FeedbackModifier(model: model))
    }
    private func page(now: Date) -> some View {
        let daily = GoalReports.dailyGoals(model.journal, at: selectedDate)
        let sleepGoals = SleepPlan.isEnabled(model.journal) ? SleepReminder.allCases : []
        let completed = daily.filter { GoalReports.progress($0, journal: model.journal, at: selectedDate, now: now).isComplete }.count
            + sleepGoals.filter { SleepPlan.isComplete($0, journal: model.journal, on: selectedDate) }.count
        let future = calendar.startOfDay(for: selectedDate) > now
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(InterfaceSection.goals.customTitle(in: model.journal.preferences) ?? "Mục tiêu theo ngày")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                dateSelector
                if let message {
                    HStack {
                        Text(message).font(.callout)
                        Spacer()
                        if removedChange != nil && !HistoryProtection.isPast(selectedDate, journal: model.journal, now: now) { Button("Hoàn tác xóa") { undoDeletion() } }
                        Button { clearFeedback() } label: { Image(systemName: "xmark") }.help("Đóng thông báo")
                    }.padding(14).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                if HistoryProtection.isPast(selectedDate, journal: model.journal, now: now) {
                    Label("Ngày đã kết thúc · Chỉ xem", systemImage: "lock.fill").font(.callout).foregroundStyle(.secondary)
                } else { editor }
                Card(title: "\(dayTitle(now: now)) · \(model.dateLabel(selectedDate))") {
                    Text(future ? "\(daily.count + sleepGoals.count) mục tiêu đã đặt" : "\(completed)/\(daily.count + sleepGoals.count) mục tiêu đã hoàn thành").font(.headline)
                    Text("Nhiệm vụ trong ngày").font(.headline)
                    if daily.isEmpty {
                        Text("Chưa có nhiệm vụ cho ngày này.").foregroundStyle(.secondary)
                    } else {
                        ForEach(daily) { goal in
                            GoalProgressRow(model: model, goal: goal, date: selectedDate, now: now, onDelete: delete, canEdit: !HistoryProtection.isPast(selectedDate, journal: model.journal, now: now))
                        }
                    }
                    if !sleepGoals.isEmpty {
                        Text("Ngủ & thức dậy").font(.headline).padding(.top, 8)
                        ForEach(sleepGoals) { reminder in sleepGoalRow(reminder) }
                    }
                }
            }.padding(28)
        }
    }
    private var dateSelector: some View {
        HStack(spacing: 12) {
            Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }.help("Ngày trước")
            DatePicker("Ngày nhiệm vụ", selection: $selectedDate, displayedComponents: .date)
                .environment(\.calendar, calendar)
                .environment(\.timeZone, calendar.timeZone)
                .environment(\.locale, Locale(identifier: "vi_VN"))
                .frame(width: 240)
            Button { moveDay(1) } label: { Image(systemName: "chevron.right") }.help("Ngày sau")
            Button("Hôm nay") { selectedDate = Date() }
            Spacer()
        }
    }
    private var editor: some View {
        Card(title: "Đặt nhiệm vụ cho ngày \(model.dateLabel(selectedDate))") {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Hoạt động").font(.caption).foregroundStyle(.secondary)
                    Picker("Hoạt động mục tiêu", selection: $activityID) {
                        Text("Chọn hoạt động").tag(nil as UUID?)
                        ForEach(model.activeActivities) { Text($0.name).tag(Optional($0.id)) }
                    }.labelsHidden().frame(minWidth: 170, maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Số giờ mục tiêu").font(.caption).foregroundStyle(.secondary)
                    TextField("Ví dụ: 1,5", text: $hours).textFieldStyle(.roundedBorder).frame(width: 130).accessibilityLabel("Số giờ mục tiêu trong ngày đã chọn")
                }
                Button("Lưu nhiệm vụ") { save() }.buttonStyle(.borderedProminent).tint(.indigo).disabled(activityID == nil)
            }
            if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
        }
    }
    private func sleepGoalRow(_ reminder: SleepReminder) -> some View {
        let complete = SleepPlan.isComplete(reminder, journal: model.journal, on: selectedDate)
        let event = SleepTracking.eventTime(for: reminder, journal: model.journal, on: selectedDate)
        return HStack(spacing: 15) {
            Toggle("Hoàn thành \(reminder.title)", isOn: .constant(complete))
                .labelsHidden().toggleStyle(.checkbox).tint(.green).allowsHitTesting(false).focusable(false)
            Label(reminder.title, systemImage: reminder.symbol).font(.headline).foregroundStyle(.indigo)
            Spacer()
            if let event { Text(model.time(event)).monospacedDigit().font(.callout).foregroundStyle(.secondary) }
            Text("≤ \(SleepTracking.deadlineTimeLabel(for: reminder, journal: model.journal, on: selectedDate))").monospacedDigit().font(.headline)
            Text(SleepPlan.isInitiallyComplete(reminder, journal: model.journal, on: selectedDate) ? "Hoàn thành" : (complete ? "Đúng giờ" : (event != nil ? "Muộn" : "Chưa ghi nhận"))).font(.callout)
                .foregroundStyle(complete ? .green : (event != nil ? .orange : .secondary)).frame(width: 120, alignment: .trailing)
        }.padding(16).background(.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    private func dayTitle(now: Date) -> String {
        if calendar.isDate(selectedDate, inSameDayAs: now) { return "Hôm nay" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(selectedDate, inSameDayAs: yesterday) { return "Hôm qua" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(selectedDate, inSameDayAs: tomorrow) { return "Ngày mai" }
        return "Nhiệm vụ"
    }
    private func moveDay(_ offset: Int) {
        if let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) { selectedDate = date }
    }
    private func clearFeedback() { message = nil; removedChange = nil; validationError = nil }
    private func loadTarget() {
        if let id = activityID, let existing = GoalReports.dailyGoals(model.journal, at: selectedDate).first(where: { $0.activityID == id }) {
            hours = String(format: "%g", Double(existing.minutes) / 60)
        } else { hours = "1" }
        validationError = nil
    }
    private func save() {
        guard let id = activityID,
              let number = Double(hours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              number.isFinite, number > 0, number <= 24,
              Int((number * 60).rounded()) >= 1 else {
            validationError = "Nhập mục tiêu từ 1 phút đến 24 giờ, ví dụ 1,5 giờ."; return
        }
        if model.perform({ try GoalReports.saveDailyPlan(&$0, activityID: id, minutes: Int((number * 60).rounded()), on: selectedDate) }) {
            validationError = nil; removedChange = nil
            message = "Đã lưu nhiệm vụ \(model.journal.activity(id)?.name ?? "hoạt động") cho ngày \(model.dateLabel(selectedDate))."
        }
    }
    private func delete(_ goal: Goal) {
        var removed: DailyPlanChange?
        if model.perform({ removed = try GoalReports.deleteDailyPlan(&$0, id: goal.id, on: selectedDate) }), let removed {
            removedChange = removed
            message = "Đã xoá nhiệm vụ \(model.journal.activity(goal.activityID)?.name ?? "hoạt động") của ngày \(model.dateLabel(selectedDate))."
            loadTarget()
        }
    }
    private func undoDeletion() {
        guard let change = removedChange else { return }
        if model.perform({ try GoalReports.restoreDailyPlan(&$0, change: change) }) {
            removedChange = nil; message = "Đã khôi phục nhiệm vụ."; loadTarget()
        }
    }
}
