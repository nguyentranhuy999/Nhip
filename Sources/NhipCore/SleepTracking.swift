import Foundation

public enum SleepKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case nap, night
    public var id: String { rawValue }
    public var title: String { self == .nap ? "Ngủ trưa" : "Ngủ đêm" }
    public var bedtime: SleepReminder { self == .nap ? .napSleep : .nightSleep }
    public var wake: SleepReminder { self == .nap ? .napWake : .morningWake }
}

public struct SleepSession: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var kind: SleepKind
    public var start: Date
    public var end: Date?
    public var goalDay: String
    public var timezone: String
    public var restEntryID: UUID?
    public var schedule: SleepSchedule? // Snapshot; legacy sessions keep the original default deadlines.
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        return calendar
    }
    public var wakeGoalDay: String {
        guard kind == .night, let day = SleepTracking.date(goalDay, calendar: calendar),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else { return goalDay }
        return SleepPlan.dayKey(tomorrow, calendar: calendar)
    }
    public func deadline(for reminder: SleepReminder) -> Date? {
        let schedule = schedule ?? SleepSchedule()
        let key = reminder.isBedtime ? goalDay : wakeGoalDay
        guard var day = SleepTracking.date(key, calendar: calendar) else { return nil }
        if reminder == .nightSleep && schedule.nightBedtimeIsNextDay {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = tomorrow
        }
        let minute = schedule[reminder]
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }
    public func isOnTime(_ reminder: SleepReminder) -> Bool {
        guard reminder == kind.bedtime || reminder == kind.wake,
              let actual = reminder.isBedtime ? start : end, let deadline = deadline(for: reminder),
              let minute = calendar.dateInterval(of: .minute, for: actual) else { return false }
        return minute.start <= deadline
    }
}

public struct SleepHistory: Codable, Equatable {
    public var sessions: [SleepSession] = []
    public var restActivityID: UUID?
    public init() {}
    public var active: SleepSession? { sessions.first { $0.end == nil } }
}

public enum SleepTracking {
    static func date(_ key: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let date = formatter.date(from: key), formatter.string(from: date) == key else { return nil }
        return date
    }
    public static func sessions(for reminder: SleepReminder, journal: Journal, on day: Date) -> [SleepSession] {
        let key = SleepPlan.dayKey(day, calendar: journal.preferences.calendar)
        return (journal.sleepHistory?.sessions ?? []).filter {
            if reminder.isBedtime { return $0.kind.bedtime == reminder && $0.goalDay == key }
            return $0.kind.wake == reminder && $0.wakeGoalDay == key && $0.end != nil
        }
    }
    private static func preferredSession(for reminder: SleepReminder, journal: Journal, on day: Date) -> SleepSession? {
        let matching = sessions(for: reminder, journal: journal, on: day)
        let preferred = matching.filter { $0.isOnTime(reminder) }
        return (preferred.isEmpty ? matching : preferred).min {
            (reminder.isBedtime ? $0.start : $0.end ?? .distantFuture) < (reminder.isBedtime ? $1.start : $1.end ?? .distantFuture)
        }
    }
    public static func eventTime(for reminder: SleepReminder, journal: Journal, on day: Date) -> Date? {
        guard let session = preferredSession(for: reminder, journal: journal, on: day) else { return nil }
        return reminder.isBedtime ? session.start : session.end
    }
    public static func deadlineTimeLabel(for reminder: SleepReminder, journal: Journal, on day: Date) -> String {
        let recorded = preferredSession(for: reminder, journal: journal, on: day)
        let active = journal.sleepHistory?.active
        let key = SleepPlan.dayKey(day, calendar: journal.preferences.calendar)
        let pending = active.flatMap { session -> SleepSession? in
            reminder == session.kind.wake && session.wakeGoalDay == key ? session : nil
        }
        let schedule = (recorded ?? pending).map { $0.schedule ?? SleepSchedule() } ?? SleepPlan.schedule(journal)
        return schedule.timeLabel(for: reminder)
    }
    public static func start(_ journal: inout Journal, kind: SleepKind, at now: Date) throws {
        guard now.timeIntervalSince1970.isFinite, now <= Date().addingTimeInterval(1) else { throw JournalError.invalid("Giờ đi ngủ không hợp lệ.") }
        guard !journal.isRecordingPersonalActivity else { throw JournalError.invalid("Hãy kết thúc hoạt động đang ghi nhận trước khi đi ngủ.") }
        var draft = journal
        _ = Engine.tick(&draft, at: now); Engine.close(&draft, at: now)
        var history = draft.sleepHistory ?? SleepHistory()
        let calendar = draft.preferences.calendar
        // A bedtime after midnight belongs to the previous evening, until noon.
        let day = kind == .night && calendar.component(.hour, from: now) < 12
            ? calendar.date(byAdding: .day, value: -1, to: now)! : now
        var session = SleepSession(kind: kind, start: now, goalDay: SleepPlan.dayKey(day, calendar: calendar), timezone: calendar.timeZone.identifier)
        session.schedule = SleepPlan.schedule(draft)
        history.sessions.append(session); draft.sleepHistory = history
        try Engine.validate(draft); journal = draft
    }
    public static func wake(_ journal: inout Journal, at now: Date) throws {
        guard let active = journal.sleepHistory?.active else { throw JournalError.invalid("Hãy đánh dấu đi ngủ trước khi thức dậy.") }
        guard now.timeIntervalSince1970.isFinite, now > active.start else { throw JournalError.invalid("Giờ thức dậy phải sau giờ đi ngủ.") }
        guard !journal.entries.contains(where: { overlap($0.start, $0.end, active.start, now) > 0 }) else {
            throw JournalError.invalid("Khoảng ngủ chồng lên hoạt động đã có. Hãy chỉnh sửa hoạt động đó trong nhật ký hoặc hủy lần ghi nhận ngủ.")
        }
        var draft = journal
        var history = draft.sleepHistory!
        let restID: UUID
        if let id = history.restActivityID, draft.activity(id) != nil { restID = id }
        else if let activity = draft.activities.first(where: { PersonalTracking.kind(of: $0) == .rest }) { restID = activity.id }
        else {
            let activity = Activity(name: ActivityCatalog.availableName("Nghỉ ngơi", in: draft), color: "84A65B", symbol: "cup.and.saucer.fill", personalKind: .rest)
            draft.activities.append(activity); restID = activity.id
        }
        let entry = Entry(start: active.start, end: now, activityID: restID, note: active.kind.title, source: "sleep")
        // Preserve existing activity if a user has manually recorded overlapping time.
        try Engine.record(&draft, entry: entry)
        let index = history.sessions.firstIndex { $0.id == active.id }!
        history.sessions[index].end = now; history.sessions[index].restEntryID = entry.id
        history.restActivityID = restID; draft.sleepHistory = history
        _ = Engine.tick(&draft, at: now)
        try Engine.validate(draft); journal = draft
    }
    public static func delete(_ journal: inout Journal, sessionID: UUID, at now: Date) throws {
        guard let session = journal.sleepHistory?.sessions.first(where: { $0.id == sessionID }) else { return }
        var draft = journal
        // An entry later edited by hand belongs to the user's manual journal.
        draft.entries.removeAll { $0.id == session.restEntryID && $0.source == "sleep" }
        draft.sleepHistory?.sessions.removeAll { $0.id == sessionID }
        if session.end == nil { _ = Engine.tick(&draft, at: now) }
        try Engine.validate(draft); journal = draft
    }
    public static func validate(_ history: SleepHistory?, journal: Journal) throws {
        guard let history else { return }
        guard Set(history.sessions.map(\.id)).count == history.sessions.count,
              history.sessions.filter({ $0.end == nil }).count <= 1,
              history.restActivityID.map({ journal.activity($0) != nil }) ?? true else {
            throw JournalError.invalid("Dữ liệu giấc ngủ bị trùng hoặc không hợp lệ.")
        }
        let sorted = history.sessions.sorted { $0.start < $1.start }
        for (index, session) in sorted.enumerated() {
            try session.schedule?.validate()
            guard session.start.timeIntervalSince1970.isFinite, TimeZone(identifier: session.timezone) != nil,
                  date(session.goalDay, calendar: session.calendar) != nil,
                  session.end.map({ $0.timeIntervalSince1970.isFinite && $0 > session.start }) ?? true,
                  index == 0 || (sorted[index - 1].end.map { $0 <= session.start } ?? false) else {
                throw JournalError.invalid("Giờ ngủ/thức dậy không hợp lệ hoặc chồng lấn.")
            }
        }
    }
}
