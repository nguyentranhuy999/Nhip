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
            }
        }.padding(24).frame(width: 420, height: 130)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.08)))
    }
}
