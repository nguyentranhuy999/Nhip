import Foundation

public enum SleepReminder: String, Codable, CaseIterable, Identifiable, Sendable {
    case nightSleep, morningWake, napSleep, napWake
    public var id: String { rawValue }
    public var hour: Int {
        switch self { case .nightSleep: return 0; case .morningWake: return 7; case .napSleep: return 12; case .napWake: return 13 }
    }
    public var minute: Int { self == .napSleep || self == .napWake ? 30 : 0 }
    public var timeLabel: String { String(format: "%02d:%02d", hour, minute) }
    public var title: String {
        switch self { case .nightSleep: return "Ngủ đêm"; case .morningWake: return "Thức dậy buổi sáng"; case .napSleep: return "Ngủ trưa"; case .napWake: return "Thức dậy sau ngủ trưa" }
    }
    public var isBedtime: Bool { self == .nightSleep || self == .napSleep }
    public var confirmationTitle: String { isBedtime ? "Đã đi ngủ" : "Đã thức dậy" }
    public var symbol: String { isBedtime ? "moon.zzz.fill" : "sun.max.fill" }
    public func dateComponents(calendar: Calendar) -> DateComponents {
        var components = DateComponents()
        components.calendar = calendar; components.timeZone = calendar.timeZone
        components.hour = hour; components.minute = minute; components.second = 0
        return components
    }
}

public struct SleepCompletion: Codable, Equatable {
    public var reminder: SleepReminder
    public var day: String
    public init(reminder: SleepReminder, day: String) { self.reminder = reminder; self.day = day }
}

public struct SleepReminderState: Codable, Equatable {
    public var enabled = true
    public var completions: [SleepCompletion] = []
    public var statisticsStartDay: String?
    public init() {}
}

public enum SleepPlan {
    /// Persist the first known day so unrecorded days are still counted tomorrow.
    public static func prepareStatistics(journal: inout Journal, on now: Date = Date()) {
        guard isEnabled(journal) else { return }
        // An established baseline (especially after reset) is authoritative.
        // A night begun after midnight may belong to yesterday's sleep goal,
        // but must never move the statistics baseline back to yesterday.
        guard journal.sleepReminders?.statisticsStartDay == nil else { return }
        let calendar = journal.preferences.calendar
        let keys = (journal.sleepHistory?.sessions.map(\.goalDay) ?? []) + (journal.sleepReminders?.completions.map(\.day) ?? [])
        let first = keys.compactMap { SleepTracking.date($0, calendar: calendar) }.min() ?? now
        if journal.sleepReminders == nil { journal.sleepReminders = SleepReminderState() }
        journal.sleepReminders?.statisticsStartDay = dayKey(min(first, now), calendar: calendar)
    }
    public static func nextReminder(after date: Date, calendar: Calendar) -> (reminder: SleepReminder, date: Date)? {
        SleepReminder.allCases.compactMap { reminder in
            calendar.nextDate(after: date, matching: reminder.dateComponents(calendar: calendar), matchingPolicy: .nextTime)
                .map { (reminder: reminder, date: $0) }
        }.min { $0.date < $1.date }
    }
    public static func isEnabled(_ journal: Journal) -> Bool { journal.sleepReminders?.enabled ?? true }
    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let d = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", d.year!, d.month!, d.day!)
    }
    public static func isComplete(_ reminder: SleepReminder, journal: Journal, on date: Date) -> Bool {
        let sessions = SleepTracking.sessions(for: reminder, journal: journal, on: date)
        if !sessions.isEmpty { return sessions.contains { $0.isOnTime(reminder) } }
        return journal.sleepReminders?.completions.contains(SleepCompletion(reminder: reminder, day: dayKey(date, calendar: journal.preferences.calendar))) ?? false
    }
    public static func setEnabled(_ enabled: Bool, journal: inout Journal) {
        if journal.sleepReminders == nil { journal.sleepReminders = SleepReminderState() }
        journal.sleepReminders?.enabled = enabled
    }
    public static func setComplete(_ complete: Bool, reminder: SleepReminder, journal: inout Journal, on date: Date) {
        guard isEnabled(journal) else { return }
        var state = journal.sleepReminders ?? SleepReminderState()
        let completion = SleepCompletion(reminder: reminder, day: dayKey(date, calendar: journal.preferences.calendar))
        state.completions.removeAll { $0 == completion }
        if complete { state.completions.append(completion) }
        journal.sleepReminders = state
    }
    public static func validate(_ state: SleepReminderState?) throws {
        guard let state else { return }
        var keys = Set<String>()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        if let day = state.statisticsStartDay {
            guard let date = formatter.date(from: day), formatter.string(from: date) == day else {
                throw JournalError.invalid("Ngày bắt đầu thống kê nhiệm vụ ngủ không hợp lệ.")
            }
        }
        for completion in state.completions {
            guard let date = formatter.date(from: completion.day), formatter.string(from: date) == completion.day,
                  keys.insert(completion.day + "/" + completion.reminder.rawValue).inserted else {
                throw JournalError.invalid("Dữ liệu mục tiêu ngủ không hợp lệ hoặc bị trùng.")
            }
        }
    }
}
