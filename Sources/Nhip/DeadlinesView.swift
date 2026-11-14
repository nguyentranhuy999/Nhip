import SwiftUI
import NhipCore

struct DeadlinesView: View {
    @ObservedObject var model: AppModel
    @State private var editor: DeadlineDraft?
    @State private var deleting: DeadlinePlan?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(InterfaceSection.deadlines.title(in: model.journal.preferences)).font(.system(size: 29, weight: .bold, design: .rounded))
                        Spacer()
                        Button { editor = DeadlineDraft(calendar: model.journal.preferences.calendar) } label: { Label("Thêm deadline", systemImage: "plus") }
                            .buttonStyle(.borderedProminent).tint(.indigo)
                    }
                    if (model.journal.deadlines ?? []).isEmpty {
                        Card(title: "Deadline của bạn") {
                            emptyState("Chưa có deadline", detail: "Đặt hạn và số giờ dự tính cho những hoạt động cần hoàn thành.")
                        }
                    }
                    ForEach(sortedPlans(now: context.date)) { plan in
                        DeadlineCard(model: model, plan: plan, now: context.date,
                                     edit: { editor = DeadlineDraft(plan: plan) }, delete: { deleting = plan })
                    }
                }.padding(28)
            }
        }
        .sheet(item: $editor) { draft in DeadlineEditor(model: model, draft: draft) }
        .alert("Xoá deadline?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Xoá", role: .destructive) {
                if let plan = deleting { model.perform { Deadlines.delete(&$0, id: plan.id) } }
                deleting = nil
            }
            Button("Huỷ", role: .cancel) { deleting = nil }
        } message: { Text("Chỉ xoá kế hoạch deadline. Thời gian hoạt động đã ghi nhận vẫn được giữ nguyên.") }
        .modifier(FeedbackModifier(model: model))
    }
    private func sortedPlans(now: Date) -> [DeadlinePlan] {
        (model.journal.deadlines ?? []).sorted {
            let a = $0.dueAt > now, b = $1.dueAt > now
            if a != b { return a }
            return a ? $0.dueAt < $1.dueAt : $0.dueAt > $1.dueAt
        }
    }
}

private struct DeadlineCard: View {
    @ObservedObject var model: AppModel
    let plan: DeadlinePlan
    let now: Date
    let edit: () -> Void
    let delete: () -> Void
    @State private var cachedSample: DeadlineSample?
    private var forecast: DeadlineForecast { Deadlines.forecast(plan, journal: model.journal, now: now, previousSample: cachedSample) }
    var body: some View {
        let report = forecast
        return Card(title: plan.title) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hạn: \(model.dateLabel(plan.dueAt)) · \(model.time(plan.dueAt))").font(.headline)
                    Text("Bắt đầu theo dõi: \(model.dateLabel(plan.createdAt)) · \(model.time(plan.createdAt))").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !report.isExpired { Button("Sửa", action: edit) }
                Button(role: .destructive, action: delete) { Image(systemName: "trash") }.buttonStyle(.borderless).help("Xoá deadline")
            }
            DeadlineCountdown(dueAt: plan.dueAt)
            status(report)
            HStack(spacing: 16) {
                metric("Dự tính", seconds: report.targetSeconds)
                metric("Đã ghi nhận", seconds: report.recordedSeconds)
                metric(report.isExpired ? "Kết quả đến hạn" : "Dự báo đến hạn", seconds: report.projectedSeconds)
            }.padding(.vertical, 8)
            ForEach(report.activities) { item in activity(item, expired: report.isExpired) }
            if let next = report.nextSampleAt {
                Text(report.sample.map { "Mẫu lúc \(model.time($0.sampledAt)) · Tiếp theo \(model.time(next))" }
                     ?? "Đang thu thập dữ liệu · lấy mẫu lúc \(model.time(next))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if report.isEarlyEstimate && report.projectedSeconds != nil {
                Text("Ước tính ban đầu · chưa đủ 24 giờ theo dõi").font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { cachedSample = report.sample }
        .onChange(of: report.sample) { cachedSample = $0 }
    }
    @ViewBuilder private func status(_ report: DeadlineForecast) -> some View {
        if report.isComplete {
            Label("Đã đủ số giờ dự tính", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else if report.isExpired {
            Label("Đã đến hạn · chưa đủ số giờ ở \(report.atRiskCount) hoạt động", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        } else if report.atRiskCount > 0 {
            Label("Theo nhịp hiện tại, \(report.atRiskCount) hoạt động có nguy cơ thiếu giờ", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        } else if report.projectedSeconds != nil {
            Label("Theo nhịp hiện tại, dự báo đủ số giờ", systemImage: "checkmark.circle").foregroundStyle(.green)
        }
    }
    private func activity(_ item: DeadlineActivityForecast, expired: Bool) -> some View {
        let activity = model.journal.activity(item.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(activity?.name ?? "Hoạt động", systemImage: activity?.symbol ?? "clock")
                    .font(.headline).foregroundStyle(Color(hex: activity?.color ?? "6366F1"))
                if activity?.archived == true { Text("Đã lưu trữ").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text("\(hours(item.recordedSeconds)) / \(hours(item.target.seconds)) giờ").monospacedDigit().font(.callout)
            }
            ProgressView(value: item.fraction).tint(item.isComplete ? .green : (item.isAtRisk ? .orange : .indigo))
            HStack(spacing: 16) {
                metric("Trung bình/ngày", seconds: item.averageSecondsPerDay)
                metric(expired ? "Kết quả đến hạn" : "Dự báo đến hạn", seconds: item.projectedSeconds)
                metric("Cần/ngày theo mẫu", seconds: item.requiredSecondsPerDay)
            }
            if let shortage = item.projectedShortfall, shortage > 0.001 {
                Text("\(expired ? "Còn thiếu" : "Dự báo thiếu") \(hours(shortage)) giờ so với dự tính.")
                    .font(.callout).foregroundStyle(expired ? .red : .orange)
            }
        }.padding(16).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
    private func metric(_ title: String, seconds: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(seconds.map { hours($0) + " giờ" } ?? "—").font(.callout.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func hours(_ seconds: Double) -> String { String(format: "%.2f", seconds / 3600).replacingOccurrences(of: ".", with: ",") }
}

private struct DeadlineCountdown: View {
    let dueAt: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(min(Double(Int.max / 2), ceil(dueAt.timeIntervalSince(context.date)))))
            Label(remaining > 0 ? "Còn \(remaining / 86400) ngày · \(String(format: "%02d:%02d:%02d", (remaining % 86400) / 3600, (remaining % 3600) / 60, remaining % 60))" : "Đã đến hạn", systemImage: "hourglass")
                .font(.system(size: 23, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(remaining > 0 ? Color.indigo : Color.secondary)
        }
    }
}

private struct DeadlineDraft: Identifiable {
    var id = UUID()
    var originalID: UUID?
    var title = ""
    var dueAt: Date
    var selected: Set<UUID> = []
    var hours: [UUID: String] = [:]
    init(calendar: Calendar) {
        let day = calendar.date(byAdding: .day, value: 7, to: Date())!
        dueAt = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)!
    }
    init(plan: DeadlinePlan) {
        originalID = plan.id; title = plan.title; dueAt = plan.dueAt
        selected = Set(plan.targets.map(\.activityID))
        hours = Dictionary(uniqueKeysWithValues: plan.targets.map { ($0.activityID, String(format: "%g", Double($0.minutes) / 60)) })
    }
}

private struct DeadlineEditor: View {
    @ObservedObject var model: AppModel
    @State var draft: DeadlineDraft
    @State private var validationError: String?
    @Environment(\.dismiss) private var dismiss
    private var activities: [Activity] { model.journal.activities.filter { !$0.archived || draft.selected.contains($0.id) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.originalID == nil ? "Thêm deadline" : "Sửa deadline").font(.title2.bold())
            TextField("Tên deadline", text: $draft.title).textFieldStyle(.roundedBorder).accessibilityLabel("Tên deadline")
            DatePicker("Hạn hoàn thành", selection: $draft.dueAt, displayedComponents: [.date, .hourAndMinute])
            HStack { Text("Hoạt động cần thực hiện").font(.headline); Spacer(); Text("Số giờ dự tính").font(.caption).foregroundStyle(.secondary) }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(activities) { activity in
                        HStack {
                            Button {
                                if draft.selected.contains(activity.id) { draft.selected.remove(activity.id) }
                                else { draft.selected.insert(activity.id); if draft.hours[activity.id] == nil { draft.hours[activity.id] = "1" } }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: draft.selected.contains(activity.id) ? "checkmark.circle.fill" : "circle")
                                    Label(activity.name, systemImage: activity.symbol).foregroundStyle(Color(hex: activity.color))
                                    Spacer()
                                }.padding(.vertical, 9).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            if draft.selected.contains(activity.id) {
                                TextField("Giờ", text: Binding(get: { draft.hours[activity.id] ?? "" }, set: { draft.hours[activity.id] = $0 }))
                                    .textFieldStyle(.roundedBorder).frame(width: 95).accessibilityLabel("Số giờ dự tính cho \(activity.name)")
                            }
                        }.padding(.horizontal, 10).background(draft.selected.contains(activity.id) ? Color.indigo.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }.frame(minHeight: 180, maxHeight: 300)
            if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Huỷ") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lưu deadline") { save() }.buttonStyle(.borderedProminent).tint(.indigo).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 590)
            .environment(\.calendar, model.journal.preferences.calendar)
            .environment(\.timeZone, model.journal.preferences.calendar.timeZone)
            .environment(\.locale, Locale(identifier: "vi_VN"))
    }
    private func save() {
        do {
            let targets = try activities.filter { draft.selected.contains($0.id) }.map { activity -> DeadlineTarget in
                let text = (draft.hours[activity.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                guard let number = Double(text), number.isFinite, number > 0, number <= 100_000, (number * 60).rounded() >= 1 else {
                    throw JournalError.invalid("Nhập số giờ hợp lệ cho \(activity.name), tối thiểu 1 phút.")
                }
                return DeadlineTarget(activityID: activity.id, minutes: Int((number * 60).rounded()))
            }
            var candidate = model.journal
            if let id = draft.originalID { try Deadlines.update(&candidate, id: id, title: draft.title, dueAt: draft.dueAt, targets: targets) }
            else { try Deadlines.create(&candidate, title: draft.title, dueAt: draft.dueAt, targets: targets) }
            if model.perform({ $0 = candidate }) { dismiss() }
        } catch { validationError = error.localizedDescription }
    }
}
