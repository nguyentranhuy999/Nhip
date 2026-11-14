import SwiftUI
import NhipCore

struct GoalProgressRow: View {
    @ObservedObject var model: AppModel
    let goal: Goal
    let date: Date
    let now: Date
    let onDelete: (Goal) -> Void
    var canEdit = true

    var body: some View {
        let activity = model.journal.activity(goal.activityID)
        let progress = GoalReports.progress(goal, journal: model.journal, at: date, now: now)
        let color = Color(hex: activity?.color ?? "6366F1")
        let name = activity?.name ?? "Hoạt động"
        return HStack(alignment: .top, spacing: 15) {
            Toggle("Hoàn thành mục tiêu \(name)", isOn: .constant(progress.isComplete))
                .labelsHidden().toggleStyle(.checkbox).tint(.green)
                .allowsHitTesting(false).focusable(false)
                .accessibilityLabel("Hoàn thành mục tiêu \(name)")
                .help("Tự động cập nhật theo thời gian đã ghi nhận")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(name, systemImage: activity?.symbol ?? "target").font(.headline).foregroundStyle(color)
                    if activity?.archived == true { Text("Đã lưu trữ").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if !goal.isDaily { Text("Mỗi tuần").font(.caption).foregroundStyle(.secondary) }
                }
                if goal.direction == "observe" {
                    Text("Chỉ quan sát · \(durationText(progress.seconds)) đã ghi nhận").font(.callout).foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("\(progress.seconds / 3600, format: .number.precision(.fractionLength(2))) / \(Double(goal.minutes) / 60, format: .number.precision(.fractionLength(2))) giờ").monospacedDigit()
                        Spacer()
                        Text(progress.isComplete ? "Đã hoàn thành" : (goal.direction == "limit" ? (progress.seconds > progress.targetSeconds ? "Đã vượt giới hạn" : "Trong giới hạn") : "Còn \(durationText(max(0, progress.targetSeconds - progress.seconds)))")).foregroundStyle(progress.isComplete ? .green : .secondary)
                    }.font(.callout)
                    ProgressView(value: progress.fraction).tint(progress.isComplete ? .green : color)
                    Text("Đã ghi nhận \(durationText(progress.seconds)) · Mục tiêu \(goal.direction == "limit" ? "tối đa" : "ít nhất") \(durationText(progress.targetSeconds))").font(.caption).foregroundStyle(.secondary)
                }
            }
            if canEdit {
            Button(role: .destructive) { onDelete(goal) } label: { Image(systemName: "trash").padding(5) }
                .buttonStyle(.borderless)
                .accessibilityLabel("Xóa mục tiêu \(goal.isDaily ? "mỗi ngày" : "tuần") \(name)")
                .help("Xóa mục tiêu \(name)")
            } else { Image(systemName: "lock.fill").foregroundStyle(.secondary).help("Ngày đã kết thúc · Chỉ xem") }
        }.padding(16).background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
