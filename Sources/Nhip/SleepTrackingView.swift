import SwiftUI
import NhipCore

struct SleepTrackingView: View {
    @ObservedObject var model: AppModel
    private var active: SleepSession? { model.journal.sleepHistory?.active }
    private var recent: [SleepSession] {
        Array((model.journal.sleepHistory?.sessions ?? []).filter { $0.end != nil }.sorted { $0.start > $1.start }.prefix(5))
    }
    var body: some View {
        Card(title: "Ghi nhận giấc ngủ") {
            ForEach(SleepKind.allCases) { kind in sleepRow(kind) }
            ForEach(recent) { session in
                HStack(spacing: 16) {
                    Label(session.kind.title, systemImage: "moon.zzz.fill").font(.headline)
                    Text("\(model.dateLabel(session.start, format: "dd/MM")) \(model.time(session.start)) – \(model.dateLabel(session.end!, format: "dd/MM")) \(model.time(session.end!))")
                        .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Text("\(durationText(session.end!.timeIntervalSince(session.start))) Nghỉ ngơi").font(.callout)
                    Button(role: .destructive) { model.deleteSleepSession(session) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).accessibilityLabel("Xóa lần ghi nhận \(session.kind.title)")
                }.padding(.top, 6)
            }
        }
    }
    private func sleepRow(_ kind: SleepKind) -> some View {
        let session = active.flatMap { $0.kind == kind ? $0 : nil }
        let accent: Color = kind == .nap ? .orange : .indigo
        return HStack(spacing: 16) {
            Image(systemName: kind == .nap ? "sun.haze.fill" : "moon.stars.fill")
                .font(.system(size: 23)).foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(kind.title).font(.headline)
                if let session {
                    Text("Đang ngủ · \(model.time(session.start)) · \(model.dateLabel(session.start))")
                        .font(.caption).monospacedDigit().foregroundStyle(accent)
                }
            }
            Spacer(minLength: 8)
            Button { model.setSleeping(true, kind: kind) } label: {
                Label("Ngủ", systemImage: "bed.double.fill").frame(width: 90)
            }.buttonStyle(.borderedProminent).tint(accent).controlSize(.large)
                .disabled(model.journal.isRecordingPersonalActivity).accessibilityLabel("Bắt đầu \(kind.title.lowercased())")
            Button {
                guard active?.kind == kind else { return }
                model.setSleeping(false, kind: kind)
            } label: {
                Label("Thức dậy", systemImage: "sunrise.fill").frame(width: 100)
            }.buttonStyle(.bordered).tint(accent).controlSize(.large)
                .disabled(session == nil).accessibilityLabel(kind == .nap ? "Thức dậy sau ngủ trưa" : "Thức dậy buổi sáng")
            Group {
                if let session {
                    Button { model.deleteSleepSession(session) } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .accessibilityLabel("Hủy lần ghi nhận \(kind.title.lowercased())")
                        .help("Hủy lần ghi nhận \(kind.title.lowercased())")
                } else { Color.clear }
            }.frame(width: 24)
        }.padding(14).background(accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }
}
