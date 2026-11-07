import SwiftUI
import NhipCore

struct GoalsView: View {
    @ObservedObject var model: AppModel
    @State private var activityID: UUID?
    @State private var hours = "1"
    @State private var validationError: String?
    @State private var message: String?
    @State private var removedGoals: [Goal] = []

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            page(now: context.date)
        }
        .onAppear { activityID = model.activeActivities.first?.id; loadTarget() }
        .onChange(of: activityID) { _ in loadTarget() }
        .modifier(FeedbackModifier(model: model))
    }
    private func page(now: Date) -> some View {
        let daily = GoalReports.dailyGoals(model.journal, at: now)
        let sleepGoals = SleepPlan.isEnabled(model.journal) ? SleepReminder.allCases : []
        let completed = daily.filter { GoalReports.progress($0, journal: model.journal, at: now, now: now).isComplete }.count
            + sleepGoals.filter { SleepPlan.isComplete($0, journal: model.journal, on: now) }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mục tiêu mỗi ngày").font(.system(size: 29, weight: .bold, design: .rounded))
                }
                if let message {
                    HStack {
                        Text(message).font(.callout)
                        Spacer()
                        if !removedGoals.isEmpty { Button("Hoàn tác xóa") { undoDeletion() } }
                        Button { self.message = nil; removedGoals = [] } label: { Image(systemName: "xmark") }.help("Đóng thông báo")
                    }.padding(14).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                Card(title: "Đặt mục tiêu hằng ngày") {
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Hoạt động").font(.caption).foregroundStyle(.secondary)
                            Picker("Hoạt động mục tiêu", selection: $activityID) {
                                Text("Chọn hoạt động").tag(nil as UUID?)
                                ForEach(model.activeActivities) { Text($0.name).tag(Optional($0.id)) }
                            }.labelsHidden().frame(minWidth: 170, maxWidth: .infinity)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Số giờ mỗi ngày").font(.caption).foregroundStyle(.secondary)
                            TextField("Ví dụ: 1,5", text: $hours).textFieldStyle(.roundedBorder).frame(width: 130).accessibilityLabel("Số giờ mục tiêu mỗi ngày")
                        }
                        Button("Lưu mục tiêu mỗi ngày") { save(now: now) }.buttonStyle(.borderedProminent).tint(.indigo).disabled(activityID == nil)
                    }
                    if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
                }
                Card(title: "Hôm nay · \(model.dateLabel(now))") {
                    Text("\(completed)/\(daily.count + sleepGoals.count) mục tiêu đã hoàn thành").font(.headline)
                    if daily.isEmpty && sleepGoals.isEmpty {
                        emptyState("Chưa có mục tiêu mỗi ngày", detail: "Thêm một hoạt động và số giờ bạn muốn đạt ở phía trên.")
                    } else {
                        ForEach(daily) { goal in goalRow(goal, now: now) }
                    }
                    if !sleepGoals.isEmpty {
                        Text("Ngủ & thức dậy").font(.headline).padding(.top, daily.isEmpty ? 0 : 8)
                        ForEach(sleepGoals) { reminder in sleepGoalRow(reminder, now: now) }
                    }
                }
            }.padding(28)
        }
    }
    private func goalRow(_ goal: Goal, now: Date) -> some View {
        GoalProgressRow(model: model, goal: goal, date: now, now: now, onDelete: delete)
    }
    private func sleepGoalRow(_ reminder: SleepReminder, now: Date) -> some View {
        let complete = SleepPlan.isComplete(reminder, journal: model.journal, on: now)
        let event = SleepTracking.eventTime(for: reminder, journal: model.journal, on: now)
        return HStack(spacing: 15) {
            Toggle("Hoàn thành \(reminder.title)", isOn: .constant(complete))
                .labelsHidden().toggleStyle(.checkbox).tint(.green).allowsHitTesting(false).focusable(false)
            Label(reminder.title, systemImage: reminder.symbol).font(.headline).foregroundStyle(.indigo)
            Spacer()
            if let event { Text(model.time(event)).monospacedDigit().font(.callout).foregroundStyle(.secondary) }
            Text("≤ \(reminder.timeLabel)").monospacedDigit().font(.headline)
            Text(complete ? "Đúng giờ" : (event != nil ? "Muộn" : "Chưa ghi nhận")).font(.callout)
                .foregroundStyle(complete ? .green : (event != nil ? .orange : .secondary)).frame(width: 120, alignment: .trailing)
        }.padding(16).background(.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    private func loadTarget() {
        if let id = activityID, let existing = model.journal.goals.first(where: { $0.isDaily && $0.activityID == id }) {
            hours = String(format: "%g", Double(existing.minutes) / 60)
        } else { hours = "1" }
        validationError = nil
    }
    private func save(now: Date) {
        guard let id = activityID,
              let number = Double(hours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              number.isFinite, number > 0, number <= 24,
              Int((number * 60).rounded()) >= 1 else {
            validationError = "Nhập mục tiêu từ 1 phút đến 24 giờ, ví dụ 1,5 giờ."; return
        }
        model.perform { try GoalReports.saveDailyGoal(&$0, activityID: id, minutes: Int((number * 60).rounded()), at: now) }
        if model.error == nil {
            validationError = nil; removedGoals = []
            message = "Đã lưu mục tiêu mỗi ngày cho \(model.journal.activity(id)?.name ?? "hoạt động")."
        }
    }
    private func delete(_ goal: Goal) {
        var removed: [Goal] = []
        model.perform { removed = GoalReports.deleteGoal(&$0, id: goal.id) }
        if model.error == nil {
            removedGoals = removed
            message = "Đã xóa mục tiêu \(model.journal.activity(goal.activityID)?.name ?? "hoạt động")."
            loadTarget()
        }
    }
    private func undoDeletion() {
        model.perform { try GoalReports.restoreGoals(&$0, goals: removedGoals) }
        if model.error == nil { removedGoals = []; message = "Đã khôi phục mục tiêu."; loadTarget() }
    }
}
