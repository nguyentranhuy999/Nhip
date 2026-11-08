import SwiftUI

struct SleepReminderView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let alert = model.activeSleepAlert {
                HStack(spacing: 14) {
                    Image(systemName: alert.reminder.symbol).font(.system(size: 30)).foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(alert.preview ? "Thử lời nhắc ngủ" : alert.reminder.title).font(.title2.bold())
                        Text(alert.reminder.timeLabel).font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button { model.dismissSleepAlert() } label: {
                        Label("Tắt lời nhắc", systemImage: "bell.slash.fill")
                    }.buttonStyle(.bordered).tint(.indigo)
                        .accessibilityLabel("Tắt lời nhắc ngủ")
                        .keyboardShortcut(.cancelAction)
                }
            }
        }.padding(24).frame(width: 420, height: 164)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.08)))
    }
}
