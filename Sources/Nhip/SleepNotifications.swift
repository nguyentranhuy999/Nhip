import Foundation
import UserNotifications
import NhipCore

@MainActor final class SleepNotifications {
    private let prefix: String
    private let demo: Bool
    private let diagnosticsURL: URL?
    private var configuration: String?
    private var enabled = false
    private var authorized = false
    private var calendar = Calendar(identifier: .gregorian)
    private var schedule = SleepSchedule()
    private var timer: Timer?
    private var previewTimer: Timer?
    private var onReminder: ((SleepReminder, Date, Bool) -> Void)?
    private var task: Task<Void, Never>?
    private var stopping = false
    private var clockGeneration = 0
    private var previewGeneration = 0
    init(demo: Bool, diagnosticsURL: URL? = nil) {
        prefix = demo ? "nhip.sleep.demo." : "nhip.sleep."
        self.demo = demo; self.diagnosticsURL = diagnosticsURL
    }
    private var identifiers: [String] { SleepReminder.allCases.map { prefix + $0.rawValue } }

    static var categories: Set<UNNotificationCategory> {
        Set([true, false].map { bedtime in
            UNNotificationCategory(identifier: bedtime ? "SLEEP_BEDTIME" : "SLEEP_WAKE", actions: [], intentIdentifiers: [])
        })
    }
    private static func content(_ reminder: SleepReminder, schedule: SleepSchedule) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Nhịp · \(reminder.title)"
        content.body = "\(schedule.timeLabel(for: reminder)) · Đến giờ \(reminder.title.lowercased())."
        content.categoryIdentifier = reminder.isBedtime ? "SLEEP_BEDTIME" : "SLEEP_WAKE"
        content.sound = .default
        content.userInfo = ["sleepReminder": reminder.rawValue, "sleepPreview": false]
        return content
    }
    func reconcile(enabled: Bool, calendar: Calendar, authorized: Bool, schedule: SleepSchedule = SleepSchedule(),
                   onReminder: @escaping (SleepReminder, Date, Bool) -> Void) {
        guard !stopping else { return }
        self.onReminder = onReminder
        let times = SleepReminder.allCases.map { String(schedule[$0]) }.joined(separator: ",")
        let signature = "\(enabled)|\(calendar.timeZone.identifier)|\(authorized)|\(times)"
        guard signature != configuration else { return }
        configuration = signature
        self.enabled = enabled; self.calendar = calendar; self.authorized = authorized; self.schedule = schedule
        // While Nhịp runs, its panel controls the exact lifetime and sound cadence.
        // Native repeating alerts are restored when the app quits gracefully.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers + [prefix + "preview"])
        center.removeDeliveredNotifications(withIdentifiers: identifiers + [prefix + "preview"])
        if !enabled { previewGeneration += 1; previewTimer?.invalidate(); previewTimer = nil }
        rearm()
        let previous = task
        task?.cancel()
        task = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await writeDiagnostics(mode: "running")
        }
    }
    func rearm() {
        clockGeneration += 1
        timer?.invalidate(); timer = nil
        guard enabled, !stopping, let next = SleepPlan.nextReminder(after: Date(), calendar: calendar, schedule: schedule) else { return }
        let generation = clockGeneration
        let timer = Timer(timeInterval: max(0.01, next.date.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.enabled, !self.stopping, self.clockGeneration == generation else { return }
                let lateness = Date().timeIntervalSince(next.date)
                // Never replay old reminders after wake or a long blocked run loop.
                if lateness >= 0 && lateness < ReminderLifetime.duration {
                    self.onReminder?(next.reminder, next.date, false)
                }
                self.rearm()
            }
        }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func preview() {
        previewGeneration += 1
        previewTimer?.invalidate()
        let generation = previewGeneration
        let timer = Timer(timeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.enabled, !self.stopping, self.previewGeneration == generation else { return }
                self.onReminder?(.napSleep, Date(), true)
                self.previewTimer = nil
            }
        }
        previewTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func prepareToTerminate() async {
        clockGeneration += 1; previewGeneration += 1
        stopping = true; timer?.invalidate(); timer = nil
        previewTimer?.invalidate(); previewTimer = nil
        task?.cancel(); await task?.value
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers + [prefix + "preview"])
        center.removeDeliveredNotifications(withIdentifiers: identifiers + [prefix + "preview"])
        do {
            // Isolated smoke checks inspect the native fallback without leaving it behind.
            if enabled && authorized && (!demo || diagnosticsURL != nil) {
                for reminder in SleepReminder.allCases {
                    try await center.add(UNNotificationRequest(identifier: prefix + reminder.rawValue,
                        content: Self.content(reminder, schedule: schedule),
                        trigger: UNCalendarNotificationTrigger(dateMatching: reminder.dateComponents(calendar: calendar, schedule: schedule), repeats: true)))
                }
            }
            await writeDiagnostics(mode: "nativeFallback")
        } catch { NSLog("Nhịp: không đặt được lịch ngủ khi thoát: %@", error.localizedDescription) }
        if demo { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    }
    private func writeDiagnostics(mode: String) async {
        guard let diagnosticsURL else { return }
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests().filter { identifiers.contains($0.identifier) }
        let rows: [[String: Any]] = pending.map { request in
            let trigger = request.trigger as? UNCalendarNotificationTrigger
            return ["id": request.identifier, "hour": trigger?.dateComponents.hour ?? -1,
                    "minute": trigger?.dateComponents.minute ?? -1, "repeats": trigger?.repeats ?? false,
                    "timezone": trigger?.dateComponents.timeZone?.identifier ?? "",
                    "next": trigger?.nextTriggerDate()?.timeIntervalSince1970 ?? 0]
        }
        let next = enabled ? SleepPlan.nextReminder(after: Date(), calendar: calendar, schedule: schedule) : nil
        let info: [String: Any] = ["mode": mode, "enabled": enabled, "authorized": authorized, "pending": rows,
                                  "nextReminder": next?.reminder.rawValue ?? "", "nextDate": next?.date.timeIntervalSince1970 ?? 0]
        do { try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: diagnosticsURL, options: .atomic) }
        catch { NSLog("Nhịp: %@", error.localizedDescription) }
    }
}
