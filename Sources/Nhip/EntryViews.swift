import SwiftUI
import NhipCore

struct QuickCheckInView: View {
    @ObservedObject var model: AppModel
    @State private var note = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "waveform.path").foregroundStyle(.indigo)
                Text("Ghi nhận nhanh").font(.headline)
                Spacer()
            }
            Text("Bạn vừa làm gì?").font(.system(size: 27, weight: .bold, design: .rounded))
            if let span = model.currentInterval {
                Text("\(model.dateLabel(span.start)) · \(model.time(span.start))–\(model.time(span.end)) · \(durationText(span.seconds))").foregroundStyle(.secondary)
                if model.previewInterval != nil {
                    Label("Xem thử · không lưu vào nhật ký", systemImage: "eye").font(.caption).foregroundStyle(.indigo)
                }
                if model.previewInterval == nil && Engine.isAnswered(model.journal, interval: span) {
                    Label("Khoảng này đã được ghi nhận.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button("Xem hoặc chỉnh sửa trong dashboard") { WindowManager.shared.showDashboard(); WindowManager.shared.quick?.close() }
                } else {
                    Text("Bấm vào ô hoạt động để ghi nhận ngay.").font(.caption).foregroundStyle(.secondary)
                    TextField("Ghi chú trước khi chọn (tùy chọn)", text: $note).textFieldStyle(.roundedBorder)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(model.quickActivities) { activity in
                                Button { record(span, id: activity.id) } label: {
                                    Label(activity.name, systemImage: activity.symbol)
                                        .font(.callout.weight(.medium)).lineLimit(2)
                                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                                        .padding(12)
                                        .foregroundStyle(Color(hex: activity.color))
                                        .background(Color(hex: activity.color).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(ActivityTileButtonStyle())
                                .accessibilityLabel(activity.name)
                                .help("Bấm vào ô để ghi nhận \(activity.name)")
                            }
                        }
                    }.frame(maxHeight: 245)
                    HStack {
                        if let id = model.journal.runtime.lastActivityID, let activity = model.quickActivities.first(where: { $0.id == id }) {
                            Button("Giống lần trước: \(activity.name)") { record(span, id: id) }.font(.caption)
                        }
                        Spacer()
                        Button("Bỏ qua") {
                            if model.previewInterval != nil { WindowManager.shared.quick?.close() }
                            else { model.skip(span) }
                        }
                    }
                }
            } else {
                Text("Chưa có lượt ghi nhận mới. Nhịp sẽ hỏi bạn khi hết một chu kỳ theo dõi.").foregroundStyle(.secondary)
                if !model.journal.runtime.enabled { Button("Bắt đầu theo dõi") { model.start() }.buttonStyle(.borderedProminent) }
                Button("Mở dashboard để thêm thủ công") { WindowManager.shared.showDashboard() }
            }
            Spacer(minLength: 0)
        }.padding(24).frame(width: 440, height: 570).modifier(FeedbackModifier(model: model))
            .onChange(of: model.currentInterval?.id) { _ in note = "" }
            .onDisappear { note = "" }
    }
    private func record(_ span: Span, id: UUID) {
        if model.previewInterval != nil { note = ""; WindowManager.shared.quick?.close(); return }
        model.answer(span, activityID: id, note: note)
        if model.error == nil { note = ""; WindowManager.shared.quick?.close() }
    }
}

private struct ActivityTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct EntryDraft: Identifiable {
    var id = UUID()
    var originalID: UUID?
    var start: Date
    var end: Date
    var activityID: UUID?
    var note = ""
    init(date: Date, calendar: Calendar, activityID: UUID?) {
        let now = Date()
        let base = calendar.isDate(date, inSameDayAs: now) ? now : calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        end = min(base, now); start = end.addingTimeInterval(-300); self.activityID = activityID
    }
    init(entry: Entry) { originalID = entry.id; start = entry.start; end = entry.end; activityID = entry.activityID; note = entry.note }
}

struct EntryEditor: View {
    @ObservedObject var model: AppModel
    @State var draft: EntryDraft
    @State private var replace = false
    @State private var split = false
    @State private var splitDate = Date()
    @State private var secondActivity: UUID?
    @State private var localError: String?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(draft.originalID == nil ? "Thêm hoạt động" : "Chỉnh sửa hoạt động").font(.title2.bold())
            Form {
                Picker("Hoạt động", selection: $draft.activityID) {
                    Text("Chọn hoạt động").tag(nil as UUID?)
                    ForEach(model.journal.activities.filter { !$0.archived || $0.id == draft.activityID }) { Text($0.name).tag(Optional($0.id)) }
                }
                DatePicker("Bắt đầu", selection: $draft.start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Kết thúc", selection: $draft.end, displayedComponents: [.date, .hourAndMinute])
                TextField("Ghi chú", text: $draft.note, axis: .vertical).lineLimit(2...4)
                Toggle("Thay thế phần chồng lấn", isOn: $replace)
                Text("Khi bật, phần dữ liệu nằm trong khoảng bạn chọn sẽ được thay thế. Các phần nằm ngoài khoảng này được giữ lại.").font(.caption).foregroundStyle(.secondary)
                if draft.originalID != nil {
                    Toggle("Tách thành hai hoạt động", isOn: $split)
                    if split {
                        DatePicker("Mốc tách", selection: $splitDate, displayedComponents: [.date, .hourAndMinute])
                        Picker("Hoạt động phần sau", selection: $secondActivity) {
                            Text("Chọn hoạt động").tag(nil as UUID?)
                            ForEach(model.activeActivities) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                }
            }.formStyle(.grouped)
            if let localError { Text(localError).foregroundStyle(.red).font(.callout) }
            HStack {
                if draft.originalID != nil { Button("Xóa", role: .destructive) { confirmDelete = true } }
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lưu") { save() }.buttonStyle(.borderedProminent).tint(.indigo).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 570)
            .environment(\.timeZone, model.journal.preferences.calendar.timeZone)
            .onAppear { splitDate = draft.start.addingTimeInterval(draft.end.timeIntervalSince(draft.start) / 2); secondActivity = draft.activityID }
            .alert("Xóa bản ghi này?", isPresented: $confirmDelete) {
                Button("Xóa", role: .destructive) { model.perform { $0.entries.removeAll { $0.id == draft.originalID } }; dismiss() }
                Button("Hủy", role: .cancel) {}
            } message: { Text("Bản ghi này sẽ được gỡ khỏi lịch sử hoạt động.") }
    }
    private func save() {
        guard let id = draft.activityID else { localError = "Hãy chọn hoạt động."; return }
        if split && (splitDate <= draft.start || splitDate >= draft.end || secondActivity == nil) { localError = "Mốc tách phải nằm giữa khoảng, và cần chọn hoạt động phần sau."; return }
        var candidate = model.journal
        do {
            if let original = draft.originalID { candidate.entries.removeAll { $0.id == original } }
            let first = Entry(id: draft.originalID ?? UUID(), start: draft.start, end: split ? splitDate : draft.end, activityID: id, note: draft.note, source: draft.originalID == nil ? "manual" : "edit")
            try Engine.record(&candidate, entry: first, replacing: replace)
            if split, let secondActivity { try Engine.record(&candidate, entry: Entry(start: splitDate, end: draft.end, activityID: secondActivity, note: draft.note, source: "edit"), replacing: replace) }
            try Engine.validate(candidate)
            model.perform { $0 = candidate }
            if model.error == nil { dismiss() }
        } catch { localError = error.localizedDescription }
    }
}

