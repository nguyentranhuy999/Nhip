import SwiftUI
import NhipCore

struct PersonalActivitiesView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(InterfaceSection.personal.title(in: model.journal.preferences)).font(.system(size: 29, weight: .bold, design: .rounded))
                SleepTrackingView(model: model)
                TimedActivitiesView(model: model)
            }.padding(28)
        }.modifier(FeedbackModifier(model: model))
    }
}

private struct PersonalTimeDraft: Identifiable {
    let id: UUID
    let title: String
    var start: Date
    var end: Date
    var finishing = false
}

private struct TimedActivitiesView: View {
    @ObservedObject var model: AppModel
    @State private var editor: PersonalTimeDraft?
    @State private var historyLimit = 10
    private var active: PersonalActivitySession? { model.journal.personalHistory?.active }
    private var activities: [Activity] { PersonalTracking.manualActivities(model.journal) }
    private var history: [PersonalActivitySession] {
        (model.journal.personalHistory?.sessions ?? []).filter { $0.end != nil && entry(for: $0) != nil }
            .sorted { (entry(for: $0)?.start ?? $0.start) > (entry(for: $1)?.start ?? $1.start) }
    }
    var body: some View {
        Card(title: "Tự ghi nhận hoạt động") {
            ForEach(activities) { activity in activityRow(activity) }
            if activities.isEmpty {
                Button("Chọn hoạt động trong Cài đặt") { WindowManager.shared.showSettings() }
            }
            if !history.isEmpty {
                Divider()
                ForEach(Array(history.prefix(historyLimit))) { session in
                    if let entry = entry(for: session) {
                        HStack(spacing: 12) {
                            Image(systemName: model.journal.activity(entry.activityID)?.symbol ?? "clock.fill")
                                .foregroundStyle(Color(hex: model.journal.activity(entry.activityID)?.color ?? "6366F1")).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.journal.activity(entry.activityID)?.name ?? "Hoạt động").font(.headline)
                                Text("\(model.dateLabel(entry.start)) \(model.time(entry.start)) – \(model.dateLabel(entry.end)) \(model.time(entry.end))")
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(durationText(entry.seconds)).font(.callout).monospacedDigit()
                            if HistoryProtection.canEdit(entry, journal: model.journal) {
                            Button { edit(session) } label: { Label("Sửa giờ", systemImage: "clock.arrow.circlepath") }
                                .accessibilityLabel("Sửa giờ \(activityName(session).lowercased())")
                            Button(role: .destructive) { model.deletePersonalActivity(session) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).accessibilityLabel("Xóa lần ghi nhận \(activityName(session).lowercased())")
                            } else { Image(systemName: "lock.fill").foregroundStyle(.secondary).help("Ngày đã kết thúc · Chỉ xem") }
                        }.padding(.vertical, 6)
                    }
                }
                if history.count > historyLimit { Button("Xem thêm") { historyLimit += 10 } }
            }
        }
        .sheet(item: $editor) { draft in PersonalTimeEditor(model: model, draft: draft) }
    }
    private func entry(for session: PersonalActivitySession) -> Entry? {
        model.journal.entries.first { $0.id == session.entryID }
    }
    private func activityName(_ session: PersonalActivitySession) -> String {
        model.journal.activity(entry(for: session)?.activityID ?? session.activityID)?.name ?? "Hoạt động"
    }
    private func edit(_ session: PersonalActivitySession) {
        guard let entry = entry(for: session) else { return }
        editor = PersonalTimeDraft(id: session.id, title: activityName(session), start: entry.start, end: entry.end)
    }
    private func activityRow(_ activity: Activity) -> some View {
        let session = active.flatMap { $0.activityID == activity.id ? $0 : nil }
        let accent = Color(hex: activity.color)
        return HStack(spacing: 16) {
            Image(systemName: activity.symbol).font(.system(size: 23)).foregroundStyle(accent)
                .frame(width: 48, height: 48).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(activity.name).font(.headline)
                if let session {
                    Text("Bắt đầu \(model.time(session.start)) · \(model.dateLabel(session.start))")
                        .font(.caption).monospacedDigit().foregroundStyle(accent)
                }
            }
            Spacer(minLength: 8)
            Button { model.startPersonalActivity(activity.id) } label: {
                Label("Bắt đầu", systemImage: "play.fill").frame(width: 90)
            }.buttonStyle(.borderedProminent).tint(accent).controlSize(.large)
                .disabled(model.journal.isRecordingPersonalActivity).accessibilityLabel("Bắt đầu \(activity.name.lowercased())")
            Button {
                guard let session else { return }
                editor = PersonalTimeDraft(id: session.id, title: activity.name, start: session.start, end: Date(), finishing: true)
            } label: {
                Label("Kết thúc", systemImage: "stop.fill").frame(width: 100)
            }.buttonStyle(.bordered).tint(accent).controlSize(.large)
                .disabled(session == nil).accessibilityLabel("Kết thúc \(activity.name.lowercased())")
            Group {
                if let session {
                    Button { model.deletePersonalActivity(session) } label: { Image(systemName: "xmark.circle") }
                        .disabled(HistoryProtection.isPast(session.start, journal: model.journal))
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .accessibilityLabel("Hủy lần ghi nhận \(activity.name.lowercased())")
                        .help("Hủy lần ghi nhận \(activity.name.lowercased())")
                } else { Color.clear }
            }.frame(width: 24)
        }.padding(14).background(accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PersonalTimeEditor: View {
    @ObservedObject var model: AppModel
    @State var draft: PersonalTimeDraft
    @State private var validationError: String?
    @Environment(\.dismiss) private var dismiss
    private var originalStartIsPast: Bool {
        let start = model.journal.personalHistory?.sessions.first(where: { $0.id == draft.id })?.start ?? draft.start
        return HistoryProtection.isPast(start, journal: model.journal)
    }
    private var readOnly: Bool { !draft.finishing && originalStartIsPast }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(draft.finishing ? "Kết thúc" : "Chỉnh thời gian") · \(draft.title)").font(.title2.bold())
            Form {
                DatePicker("Bắt đầu", selection: $draft.start, displayedComponents: [.date, .hourAndMinute])
                    .disabled(originalStartIsPast)
                DatePicker("Kết thúc", selection: $draft.end, displayedComponents: [.date, .hourAndMinute])
                Text("Thời lượng: \(durationText(max(0, draft.end.timeIntervalSince(draft.start))))")
            }.formStyle(.grouped).disabled(readOnly)
            if readOnly { Label("Ngày đã kết thúc · Chỉ xem", systemImage: "lock.fill").foregroundStyle(.secondary) }
            if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(draft.finishing ? "Lưu và kết thúc" : "Lưu giờ") { save() }.buttonStyle(.borderedProminent).tint(.indigo).keyboardShortcut(.defaultAction).disabled(readOnly)
            }
        }.padding(24).frame(width: 560, height: 330)
            .environment(\.timeZone, model.journal.preferences.calendar.timeZone)
    }
    private func save() {
        var candidate = model.journal
        do {
            if draft.finishing {
                guard let active = candidate.personalHistory?.active, active.id == draft.id else {
                    validationError = "Phiên hoạt động này đã được kết thúc hoặc hủy."; return
                }
                try PersonalTracking.finish(&candidate, sessionID: active.id, at: draft.end, start: draft.start, resumeAt: Date())
            } else {
                try PersonalTracking.edit(&candidate, sessionID: draft.id, start: draft.start, end: draft.end)
            }
            try HistoryProtection.validateChange(from: model.journal, to: candidate)
            if model.savePersonalActivity(candidate) { dismiss() }
        } catch { validationError = error.localizedDescription }
    }
}
