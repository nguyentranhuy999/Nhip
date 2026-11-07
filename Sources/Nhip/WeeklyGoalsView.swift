import SwiftUI
import NhipCore

struct WeeklyGoalsView: View {
    @ObservedObject var model: AppModel
    let date: Date
    @State private var activityID: UUID?
    @State private var hours = "3"
    @State private var validationError: String?
    @State private var message: String?
    @State private var removedGoals: [Goal] = []
    private var weekStart: Date { model.journal.preferences.calendar.dateInterval(of: .weekOfYear, for: date)!.start }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let goals = GoalReports.weeklyGoals(model.journal, at: date)
            let completed = goals.filter { GoalReports.progress($0, journal: model.journal, at: date, now: context.date).isComplete }.count
            Card(title: "Mục tiêu tuần") {
                if let message {
                    HStack {
                        Text(message).font(.callout)
                        Spacer()
                        if !removedGoals.isEmpty { Button("Hoàn tác xóa") { undoDeletion() } }
                        Button { self.message = nil; removedGoals = [] } label: { Image(systemName: "xmark") }.help("Đóng thông báo")
                    }.padding(12).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Hoạt động").font(.caption).foregroundStyle(.secondary)
                        Picker("Hoạt động mục tiêu tuần", selection: $activityID) {
                            Text("Chọn hoạt động").tag(nil as UUID?)
                            ForEach(model.activeActivities) { Text($0.name).tag(Optional($0.id)) }
                        }.labelsHidden().frame(minWidth: 170, maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Số giờ mỗi tuần").font(.caption).foregroundStyle(.secondary)
                        TextField("Ví dụ: 7", text: $hours).textFieldStyle(.roundedBorder).frame(width: 130).accessibilityLabel("Số giờ mục tiêu mỗi tuần")
                    }
                    Button("Lưu mục tiêu tuần") { save() }.buttonStyle(.borderedProminent).tint(.indigo).disabled(activityID == nil)
                }
                if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
                Divider()
                Text("\(completed)/\(goals.count) mục tiêu đã hoàn thành").font(.headline)
                if goals.isEmpty { Text("Chưa có mục tiêu tuần.").foregroundStyle(.secondary) }
                ForEach(goals) { goal in
                    GoalProgressRow(model: model, goal: goal, date: date, now: context.date, onDelete: delete)
                }
            }
        }
        .onAppear { activityID = model.activeActivities.first?.id; loadTarget() }
        .onChange(of: activityID) { _ in loadTarget() }
        .onChange(of: weekStart) { _ in message = nil; removedGoals = []; validationError = nil; loadTarget() }
    }
    private func loadTarget() {
        if let id = activityID, let existing = GoalReports.weeklyGoals(model.journal, at: date).first(where: { $0.activityID == id }) {
            hours = String(format: "%g", Double(existing.minutes) / 60)
        } else { hours = "3" }
        validationError = nil
    }
    private func save() {
        guard let id = activityID,
              let number = Double(hours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              number.isFinite, number > 0, number <= 168,
              Int((number * 60).rounded()) >= 1 else {
            validationError = "Nhập mục tiêu từ 1 phút đến 168 giờ, ví dụ 7,5 giờ."; return
        }
        model.perform { try GoalReports.saveWeeklyGoal(&$0, activityID: id, minutes: Int((number * 60).rounded()), at: date) }
        if model.error == nil { validationError = nil; removedGoals = []; message = "Đã lưu mục tiêu tuần cho \(model.journal.activity(id)?.name ?? "hoạt động")." }
    }
    private func delete(_ goal: Goal) {
        var removed: [Goal] = []
        model.perform { removed = GoalReports.deleteGoal(&$0, id: goal.id) }
        if model.error == nil { removedGoals = removed; message = "Đã xóa mục tiêu \(model.journal.activity(goal.activityID)?.name ?? "hoạt động")."; loadTarget() }
    }
    private func undoDeletion() {
        model.perform { try GoalReports.restoreGoals(&$0, goals: removedGoals) }
        if model.error == nil { removedGoals = []; message = "Đã khôi phục mục tiêu."; loadTarget() }
    }
}
