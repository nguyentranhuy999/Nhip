import SwiftUI
import NhipCore

struct QuickCheckInView: View {
    @ObservedObject var model: AppModel
    @State private var note = ""
    @State private var showNote = false
    @FocusState private var noteFocused: Bool
    private let width: CGFloat = 400
    private var gridHeight: CGFloat {
        let rows = min(4, max(1, (model.quickActivities.count + 1) / 2))
        return CGFloat(rows * 52 + (rows - 1) * 8)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "waveform.path").foregroundStyle(.indigo)
                    .frame(width: 28, height: 28).background(.indigo.opacity(0.10), in: Circle())
                Text("Ghi nhận nhanh").font(.headline)
                Spacer()
                if model.previewInterval != nil {
                    Text("Xem thử").font(.caption2.weight(.medium)).foregroundStyle(.indigo)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(.indigo.opacity(0.08), in: Capsule())
                        .accessibilityLabel("Xem thử · không lưu vào nhật ký")
                }
                Button { WindowManager.shared.quick?.close() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Đóng lời nhắc").help("Đóng lời nhắc")
            }
            if let span = model.currentInterval {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Bạn vừa làm gì?").font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("\(model.time(span.start))–\(model.time(span.end)) · \(durationText(span.seconds))")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                if model.previewInterval == nil && Engine.isAnswered(model.journal, interval: span) {
                    Label("Khoảng này đã được ghi nhận.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button("Xem hoặc chỉnh sửa trong dashboard") { WindowManager.shared.showDashboard(); WindowManager.shared.quick?.close() }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                            ForEach(model.quickActivities) { activity in
                                Button { record(span, id: activity.id) } label: {
                                    Label(activity.name, systemImage: activity.symbol)
                                        .font(.callout.weight(.medium)).lineLimit(2)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .leading)
                                        .foregroundStyle(Color(hex: activity.color))
                                        .background(Color(hex: activity.color).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(ActivityTileButtonStyle())
                                .accessibilityLabel(activity.name)
                                .help("Bấm vào ô để ghi nhận \(activity.name)")
                            }
                        }
                    }.frame(height: gridHeight)
                    if showNote {
                        TextField("Ghi chú (tùy chọn)", text: $note).textFieldStyle(.roundedBorder)
                            .focused($noteFocused).accessibilityLabel("Ghi chú trước khi chọn hoạt động")
                    }
                    HStack(spacing: 12) {
                        if let id = model.journal.runtime.lastActivityID, let activity = model.quickActivities.first(where: { $0.id == id }) {
                            Button("Lặp lại: \(activity.name)") { record(span, id: id) }
                                .font(.caption).lineLimit(1).help("Giống lần trước: \(activity.name)")
                        }
                        Spacer()
                        Button {
                            showNote.toggle()
                            if showNote { WindowManager.shared.quick?.makeKeyAndOrderFront(nil); noteFocused = true }
                        } label: { Label("Ghi chú", systemImage: "square.and.pencil") }
                            .buttonStyle(.borderless).font(.caption).tint(showNote ? .indigo : .secondary)
                        Button("Bỏ qua") {
                            if model.previewInterval != nil { WindowManager.shared.quick?.close() }
                            else { model.skip(span) }
                        }.buttonStyle(.borderless).font(.caption)
                    }
                }
            } else {
                Text("Chưa có lượt ghi nhận mới.").foregroundStyle(.secondary)
                if !model.journal.runtime.enabled { Button("Bắt đầu theo dõi") { model.start() }.buttonStyle(.borderedProminent) }
                Button("Mở dashboard để thêm thủ công") { WindowManager.shared.showDashboard() }
            }
        }.padding(20).frame(width: width).fixedSize(horizontal: false, vertical: true)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.08)))
            .background(GeometryReader { geometry in Color.clear.preference(key: QuickReminderHeight.self, value: geometry.size.height) })
            .onPreferenceChange(QuickReminderHeight.self) { height in
                Task { @MainActor in WindowManager.shared.resizeQuick(height: height) }
            }
            .modifier(FeedbackModifier(model: model))
            .onChange(of: model.currentInterval?.id) { _ in note = ""; showNote = false }
            .onDisappear { note = ""; showNote = false }
    }
    private func record(_ span: Span, id: UUID) {
        if model.previewInterval != nil { note = ""; WindowManager.shared.quick?.close(); return }
        model.answer(span, activityID: id, note: note)
        if model.error == nil { note = ""; WindowManager.shared.quick?.close() }
    }
}

private struct QuickReminderHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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

